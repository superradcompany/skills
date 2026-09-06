# Optional host-shell hooks

Skills tell the agent to use `msb`. They cannot stop a host `Bash` tool from
running `apt` / `brew` / `npm -g` on the workstation.

This directory is an **optional** second layer for coding agents that still
expose a host shell. It is **not** installed by `npx skills add`. Copy the
script yourself and point the agent's hook config at it.

MCP-only clients do not need this. Use [microsandbox-mcp](https://github.com/superradcompany/microsandbox-mcp) instead.

## What the script does

`force-host-installs-into-msb.sh` reads PreToolUse / `tool.execute.before` JSON
on stdin.

- **Deny** host package-manager installs (`apt`, `brew`, `npm -g`, `pipx`, …).
- **Allow** the same commands after `msb run` / `msb exec`.
- **Allow** the documented runtime installers (`brew`/`npm`/`uv`/`cargo`
  installing `microsandbox`) and `npx -y microsandbox-mcp`.
- **Ignore** non-shell tools (including MCP `sandbox_*`), so in-box installs
  via MCP are not blocked.
- **Fail open** if `python3` is missing or the payload has no shell command.

String matching is not isolation. The microVM is the containment boundary.

## Claude Code

Copy the script somewhere durable, `chmod +x` it, then merge this into
user or project `settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|bash|Shell|shell",
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/.agents/hooks/force-host-installs-into-msb.sh\""
          }
        ]
      }
    ]
  }
}
```

Adjust the path to wherever you copied the script. See
https://code.claude.com/docs/en/hooks

## Codex

Merge the equivalent into `~/.codex/hooks.json` (or the project hooks file),
matching on the host shell tool and pointing `command` at the same script.

## Test

```bash
sh microsandbox/hooks/force-host-installs-into-msb.sh --self-test
```

## Related

- Parent request: https://github.com/superradcompany/skills/issues/29
- Agents guide (Skills + MCP): https://docs.microsandbox.dev/getting-started/agents.md
