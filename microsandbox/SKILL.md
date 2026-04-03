---
name: microsandbox
description: >
  Create and manage isolated microVM sandboxes for safe code execution,
  testing, and development. Use when the user needs to run untrusted code,
  create isolated environments, execute commands in a sandbox, manage
  sandbox filesystems, or work with OCI container images in microVMs.
  Handles sandbox lifecycle, networking, volumes, secrets, and file
  operations via the msb CLI.
compatibility: >
  Requires msb CLI and libkrunfw library.
  macOS (Apple Silicon) or Linux (x86_64/ARM64) with KVM support.
  Run scripts/setup.sh to install if not present.
license: Apache-2.0
metadata:
  author: superradcompany
---

# microsandbox

microsandbox creates hardware-isolated microVMs that boot in under 100ms.
Each sandbox is a real VM with its own Linux kernel — not a container.

## Setup

Check if microsandbox is installed:

```bash
msb --version
```

If not installed, run the setup script:

```bash
bash scripts/setup.sh
```

This installs `msb` to `~/.microsandbox/bin/` and `libkrunfw` to `~/.microsandbox/lib/`.

## Quick reference

### Run a one-off command in a sandbox

```bash
msb run <image> [options] -- <command>
```

Examples:
```bash
msb run python:3.12 -- python -c "print('hello from sandbox')"
msb run -m 1G node:22 -- node -e "console.log(process.version)"
msb run alpine:latest -- sh -c "uname -a && cat /etc/os-release"
```

### Create a persistent sandbox

```bash
msb create --name <name> [options] <image>
msb exec <name> -- <command>
msb shell <name>
msb stop <name>
msb start <name>                  # Resume a stopped sandbox
msb rm <name>
```

Example workflow:
```bash
# Create a Python development sandbox
msb create --name dev -m 1G -c 2 python:3.12

# Install packages
msb exec dev -- pip install requests numpy

# Run code
msb exec dev -- python -c "import requests; print(requests.get('https://httpbin.org/ip').json())"

# Interactive shell
msb shell dev

# Stop and resume later
msb stop dev
msb start dev

# Clean up
msb stop dev
msb rm dev
```

### Common options

| Flag | Description | Example |
|------|-------------|---------|
| `-n, --name` | Name the sandbox | `--name my-sandbox` |
| `-m, --memory` | Memory allocation | `-m 512M`, `-m 1G` |
| `-c, --cpus` | Number of vCPUs | `-c 2` |
| `-v, --volume` | Mount volume | `-v /host/path:/guest/path` |
| `-p, --port` | Publish port | `-p 8080:80`, `-p 5353:5353/udp` |
| `-e, --env` | Set env variable | `-e API_KEY=xxx` |
| `-w, --workdir` | Working directory | `-w /app` |
| `-d, --detach` | Run in background (run only) | `-d` |
| `-u, --user` | Run as user | `-u nobody` |
| `-H, --hostname` | Set guest hostname | `-H myhost` |
| `--shell` | Default shell program | `--shell /bin/bash` |
| `--replace` | Replace existing sandbox | `--replace` |
| `--entrypoint` | Override entrypoint | `--entrypoint /bin/sh` |
| `--pull` | Pull policy | `--pull always` |
| `--max-duration` | Auto-stop timeout | `--max-duration 5m` |
| `--idle-timeout` | Idle auto-stop | `--idle-timeout 30s` |
| `--tmpfs` | Mount tmpfs | `--tmpfs /tmp:100M` |
| `--script` | Inject script | `--script setup:./setup.sh` |

### Manage sandboxes

```bash
msb ls                    # List all sandboxes
msb ls --running          # Running only
msb ps                    # Show running sandboxes with status
msb ps -a                 # All sandboxes including stopped
msb inspect <name>        # Detailed sandbox info
msb metrics <name>        # Live CPU/memory/IO stats
msb stop <name>           # Graceful shutdown
msb stop --force <name>   # Force kill
msb stop -t 10 <name>    # Wait 10s then force kill
msb rm <name>             # Remove stopped sandbox
msb rm --force <name>     # Stop and remove in one step
```

### Manage images

```bash
msb pull <image>          # Pre-cache an OCI image
msb images                # List cached images (alias: msb image ls)
msb image inspect <img>   # Image metadata
msb rmi <image>           # Remove cached image (alias: msb image rm)
```

### Manage volumes

```bash
msb volume create <name>          # Create named volume
msb volume create <name> --size 5G  # With quota
msb volume ls                     # List volumes
msb volume inspect <name>         # Volume details
msb volume rm <name>              # Remove volume
```

### Volume mounts

```bash
# Bind mount host directory
msb run -v ./project:/app python:3.12 -- python /app/script.py

# Named volume (persistent across sandboxes)
msb volume create mydata
msb run -v mydata:/data alpine -- sh -c "echo 'test' > /data/file.txt"
msb run -v mydata:/data alpine -- cat /data/file.txt
```

### Networking and security

```bash
# No network access
msb run --no-network python:3.12 -- python script.py

# Block specific domains
msb run --dns-block-domain "ads.example.com" python:3.12

# Inject secrets (placeholder substitution — real value never enters VM)
msb run --secret "OPENAI_API_KEY=sk-xxx@api.openai.com" python:3.12

# TLS interception for secret injection
msb run --tls-intercept --secret "API_KEY=xxx@api.example.com" python:3.12

# Limit connections
msb run --max-connections 10 python:3.12
```

### Registry authentication

```bash
msb registry login ghcr.io --username octocat
msb registry logout ghcr.io
msb registry ls
```

### Install sandbox as command

```bash
msb install python:3.12          # Install as 'python' command
msb install --name py python:3.12  # Custom name
msb install --list               # Show installed commands
msb uninstall py                 # Remove
```

## Key behaviors

- Sandboxes are **real microVMs** with hardware-level isolation (hypervisor boundary)
- Boot time is **under 100ms**
- Default network policy is **public-only** (blocks private ranges, metadata endpoints)
- Sandboxes from `msb run` without `--name` are **ephemeral** (destroyed after exit)
- Sandboxes from `msb create` or `msb run --name` are **persistent** (survive until `msb rm`)
- `msb create` always runs in background; use `msb run -d` for detached one-off runs
- Secrets use **placeholder substitution** — real credentials never enter the VM
- Use `--replace` to recreate an existing sandbox with new settings

## Troubleshooting

If `msb` is not found after installation:
```bash
source ~/.bashrc   # or ~/.zshrc
```

Check installation:
```bash
ls ~/.microsandbox/bin/msb
ls ~/.microsandbox/lib/libkrunfw*
```

For full CLI reference, see [references/cli-reference.md](references/cli-reference.md).
For SDK usage, see [references/sdk-typescript.md](references/sdk-typescript.md) and [references/sdk-rust.md](references/sdk-rust.md).
