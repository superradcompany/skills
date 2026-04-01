# skills

Agent skills for [microsandbox](https://github.com/superradcompany/microsandbox) and others.

Supports **Claude Code**, **Cursor**, **Codex**, **Gemini CLI**, **GitHub Copilot**, and [40+ more agents](https://github.com/nicepkg/skills?tab=readme-ov-file#supported-agents).

## Install

```bash
npx skills add superradcompany/skills
```

### Options

```bash
# Install to specific agents
npx skills add superradcompany/skills -a claude-code -a cursor

# Install globally (available across all projects)
npx skills add superradcompany/skills -g

# Install a specific skill
npx skills add superradcompany/skills --skill microsandbox

# Non-interactive (CI/CD friendly)
npx skills add superradcompany/skills --skill microsandbox -g -a claude-code -y
```

## Available Skills

### microsandbox

Create and manage hardware-isolated microVM sandboxes for safe code execution, testing, and development.

```bash
npx skills add superradcompany/skills --skill microsandbox
```

**What it teaches your agent:**

- Create ephemeral and persistent sandboxes from OCI images
- Execute commands, open shells, manage sandbox lifecycle
- Mount volumes, publish ports, set environment variables
- Inject secrets with placeholder substitution (credentials never enter the VM)
- Enforce network policies, block domains, intercept TLS
- Patch the rootfs before boot, inject scripts
- Manage images, volumes, and registry authentication

**Included references:**

| File | Description |
|------|-------------|
| `SKILL.md` | Core instructions for using the `msb` CLI |
| `scripts/setup.sh` | Installs `msb` + `libkrunfw` via official installer |
| `references/cli-reference.md` | Complete `msb` command reference with all flags |
| `references/sdk-typescript.md` | TypeScript SDK quick reference |
| `references/sdk-rust.md` | Rust SDK quick reference |
| `references/examples.md` | Common patterns: AI agent execution, web scraping, testing, secrets |

**Requirements:** macOS (Apple Silicon) or Linux (x86_64/ARM64) with KVM support.

## Creating Skills

Skills are directories containing a `SKILL.md` file with YAML frontmatter:

```markdown
---
name: my-skill
description: What this skill does and when to use it
---

Instructions for the agent to follow when this skill is activated.
```

See the [Agent Skills specification](https://agentskills.io) for details.

## Related Links

- [microsandbox](https://github.com/superradcompany/microsandbox) — The microVM sandbox runtime
- [Agent Skills specification](https://agentskills.io)
- [Skills directory](https://skills.sh)
- [Skills CLI](https://github.com/nicepkg/skills)

## License

Apache-2.0
