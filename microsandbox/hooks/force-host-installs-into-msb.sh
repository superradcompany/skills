#!/bin/sh
# Optional PreToolUse / tool.execute.before guard for coding-agent *host shell* tools.
#
# Denies package-manager installs on the agent host. Allows the same commands
# when they run inside `msb run` / `msb exec`, plus the official runtime and
# MCP installers documented by microsandbox.
#
# This is best-effort string matching, not isolation. The microVM is the
# containment boundary. Fail open when the payload is not a shell command.
#
# stdin: coding-agent JSON (Claude Code PreToolUse, Codex hooks, similar).
# stdout: Claude-style deny JSON (exit 0) or silence (exit 0 = no decision).
# test:  ./force-host-installs-into-msb.sh --self-test
set -u

REASON='Host package-manager install blocked. Put the install inside a microsandbox (`msb run` / `msb exec`) or use the microsandbox MCP tools. This hook is string matching, not isolation.'

deny_json() {
  python3 -c 'import json, os, sys
reason = os.environ["MSB_HOOK_REASON"]
json.dump({
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": reason,
  },
  "decision": "block",
  "reason": reason,
}, sys.stdout)
print()
'
}

# Returns 0 if the command should be denied.
command_is_host_install() {
  MSB_HOOK_CMD=$1 python3 - <<'PY'
import os, re, sys

cmd = os.environ.get("MSB_HOOK_CMD") or ""

# Official MCP launcher (docs: npx -y microsandbox-mcp).
if re.search(r"\b(?:npx|pnpx)\b[^\n;|&]*\bmicrosandbox-mcp\b", cmd, re.I):
    sys.exit(1)
if re.search(r"\bnpm\s+exec\b[^\n;|&]*\bmicrosandbox-mcp\b", cmd, re.I):
    sys.exit(1)

# Official runtime installers from SKILL.md — let the agent follow those docs.
if re.search(r"\bbrew\s+(?:install|upgrade)\b[^\n;|&]*\bmicrosandbox\b", cmd, re.I):
    sys.exit(1)
if re.search(r"\bnpm\s+(?:install|i|add)\s+(?:-g|--global)\s+microsandbox\b", cmd, re.I):
    sys.exit(1)
if re.search(r"\bnpm\s+(?:-g|--global)\s+(?:install|i|add)\s+microsandbox\b", cmd, re.I):
    sys.exit(1)
if re.search(r"\buv\s+tool\s+install\s+microsandbox\b", cmd, re.I):
    sys.exit(1)
if re.search(r"\bcargo\s+install\s+microsandbox\b", cmd, re.I):
    sys.exit(1)

host = re.compile(
    r"""
    (?:^|[\n;&]|&&|\|\|)
    \s*(?:sudo\s+)?
    (?P<token>
        apt(?:-get)?\s+(?:install|upgrade|remove|purge|autoremove)
      | apk\s+add
      | brew\s+(?:install|upgrade|reinstall|uninstall)
      | dnf\s+install
      | yum\s+install
      | pacman\s+-S
      | snap\s+install
      | pipx\s+install
      | pip3?\s+install\s+(?:--user\b)
      | npm\s+(?:install|i|add)\b[^\n;|&]*\s(?:-g|--global)\b
      | npm\s+(?:-g|--global)\b
      | pnpm\s+add\b[^\n;|&]*\s(?:-g|--global)\b
      | yarn\s+global\b
      | cargo\s+install\b
      | gem\s+install\b
      | go\s+install\b
    )
    """,
    re.IGNORECASE | re.VERBOSE,
)
msb_wrap = re.compile(r"\bmsb\s+(?:run|exec)\b", re.IGNORECASE)


def has_unquoted_separator(text):
    """True when a shell command separator appears outside quotes."""
    in_single = False
    in_double = False
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if in_single:
            if ch == "'":
                in_single = False
            i += 1
            continue
        if in_double:
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                in_double = False
            i += 1
            continue
        if ch == "'":
            in_single = True
            i += 1
            continue
        if ch == '"':
            in_double = True
            i += 1
            continue
        if ch in "\n;&":
            return True
        if ch == "|" and i + 1 < n and text[i + 1] == "|":
            return True
        i += 1
    return False


def msb_wraps_token(token_start):
    """True only when an msb run|exec invocation contains this token."""
    prefix = cmd[:token_start]
    wraps = list(msb_wrap.finditer(prefix))
    if not wraps:
        return False
    between = prefix[wraps[-1].end():]
    return not has_unquoted_separator(between)


for match in host.finditer(cmd):
    if not msb_wraps_token(match.start("token")):
        sys.exit(0)

sys.exit(1)
PY
}

run_self_test() {
  fail=0
  expect_deny() {
    label=$1
    cmd=$2
    if command_is_host_install "$cmd"; then
      printf 'ok deny: %s\n' "$label"
    else
      printf 'FAIL expected deny: %s (%s)\n' "$label" "$cmd" >&2
      fail=1
    fi
  }
  expect_allow() {
    label=$1
    cmd=$2
    if command_is_host_install "$cmd"; then
      printf 'FAIL expected allow: %s (%s)\n' "$label" "$cmd" >&2
      fail=1
    else
      printf 'ok allow: %s\n' "$label"
    fi
  }

  expect_allow ls 'ls -la'
  expect_allow npm_local 'npm install cowsay'
  expect_allow pip_venv 'pip install pytest'
  expect_allow msb_apt 'msb run debian -- apt-get install -y ffmpeg'
  expect_allow msb_exec 'msb exec box -- sh -c "apt-get update && apt-get install -y curl"'
  expect_allow npx_mcp 'npx -y microsandbox-mcp'
  expect_allow npm_exec_mcp 'npm exec --yes microsandbox-mcp'
  expect_allow brew_msb 'brew install superradcompany/tap/microsandbox'
  expect_allow npm_g_msb 'npm install -g microsandbox'
  expect_allow uv_msb 'uv tool install microsandbox'
  expect_allow cargo_msb 'cargo install microsandbox'
  expect_deny apt 'apt-get install -y ffmpeg'
  expect_deny apt_sudo 'sudo apt install ffmpeg'
  expect_deny brew 'brew install ffmpeg'
  expect_deny npm_g 'npm install -g cowsay'
  expect_deny pipx 'pipx install poetry'
  expect_deny pip_user 'pip3 install --user black'
  expect_deny cargo 'cargo install ripgrep'
  expect_deny apt_then_msb 'apt-get install -y ffmpeg; msb run debian -- true'
  expect_deny msb_then_apt 'msb run debian -- true; apt-get install -y ffmpeg'

  payload='{"tool_name":"Bash","tool_input":{"command":"brew install ffmpeg"}}'
  out=$(printf '%s\n' "$payload" | "$0") || {
    printf 'FAIL hook stdin invocation\n' >&2
    fail=1
  }
  case "$out" in
    *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*)
      printf 'ok hook json deny\n'
      ;;
    *)
      printf 'FAIL hook json deny, got: %s\n' "$out" >&2
      fail=1
      ;;
  esac

  mcp_payload='{"tool_name":"mcp__microsandbox__sandbox_run","tool_input":{"command":"apt-get install -y ffmpeg"}}'
  mcp_out=$(printf '%s\n' "$mcp_payload" | "$0") || {
    printf 'FAIL mcp payload invocation\n' >&2
    fail=1
  }
  if [ -n "$mcp_out" ]; then
    printf 'FAIL expected silence for MCP payload, got: %s\n' "$mcp_out" >&2
    fail=1
  else
    printf 'ok mcp payload silence\n'
  fi

  expect_hook_silence() {
    label=$1
    json=$2
    out=$(printf '%s\n' "$json" | "$0") || {
      printf 'FAIL %s invocation\n' "$label" >&2
      fail=1
      return
    }
    if [ -n "$out" ]; then
      printf 'FAIL expected silence for %s, got: %s\n' "$label" "$out" >&2
      fail=1
    else
      printf 'ok %s silence\n' "$label"
    fi
  }
  expect_hook_silence missing_tool_name '{"tool_input":{"command":"apt-get install -y ffmpeg"}}'
  expect_hook_silence non_shell_tool '{"tool_name":"Write","tool_input":{"command":"apt-get install -y ffmpeg"}}'

  if [ "$fail" -ne 0 ]; then
    printf 'force-host-installs-into-msb self-test failed\n' >&2
    return 1
  fi
  printf 'force-host-installs-into-msb self-test passed\n'
  return 0
}

if [ "${1:-}" = "--self-test" ]; then
  run_self_test
  exit $?
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'force-host-installs-into-msb: python3 not found; fail-open\n' >&2
  exit 0
fi

input=$(cat)
cmd=$(
  printf '%s' "$input" | python3 -c 'import json,sys
raw=sys.stdin.read()
if not raw.strip():
    raise SystemExit(0)
data=json.loads(raw)
name = (data.get("tool_name") or data.get("tool") or "")
name_l = str(name).lower()
# Only host-shell tools. Missing names, MCP, and other tools fail open.
if not name_l:
    raise SystemExit(0)
if name_l.startswith("mcp"):
    raise SystemExit(0)
if not any(tok in name_l for tok in ("bash", "shell", "terminal", "powershell", "command")):
    raise SystemExit(0)
ti=data.get("tool_input") or data.get("input") or data.get("arguments") or {}
if not isinstance(ti, dict):
    ti = {}
print(ti.get("command") or ti.get("cmd") or "")
' 2>/dev/null
) || exit 0

[ -n "$cmd" ] || exit 0

if command_is_host_install "$cmd"; then
  MSB_HOOK_REASON=$REASON deny_json 2>/dev/null || exit 0
  exit 0
fi

exit 0
