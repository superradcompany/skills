---
name: microsandbox
description: >
  Create and manage isolated microVM sandboxes for safe code execution,
  testing, and development. Use when the user needs to run untrusted code,
  create isolated environments, execute commands in a sandbox, manage
  sandbox filesystems, or work with OCI container images in microVMs.
  Handles sandbox lifecycle, command execution, logs, networking, volumes,
  snapshots, secrets, and file operations via the msb CLI and SDKs.
compatibility: >
  CLI requires msb and libkrunfw. SDKs bundle or install the runtime as
  documented per language. macOS requires Apple Silicon. Linux requires
  x86_64/ARM64 with KVM support.
license: Apache-2.0
metadata:
  author: superradcompany
---

# microsandbox

microsandbox creates hardware-isolated microVMs. Each sandbox is a real VM with
its own Linux kernel, not a container.

## Setup

Check if microsandbox is installed:

```bash
msb --version
```

If not installed, run the setup script:

```bash
bash scripts/setup.sh
```

This installs `msb` to `~/.microsandbox/bin/` and `libkrunfw` to
`~/.microsandbox/lib/`.

SDK installs:

```bash
cargo add microsandbox
npm install microsandbox
pip install microsandbox
go get github.com/superradcompany/microsandbox/sdk/go
```

## Quick reference

### Run a one-off command in a sandbox

```bash
msb run [options] <image-or-rootfs> [-- <command>...]
```

Examples:

```bash
msb run python -- python -c "print('hello from sandbox')"
msb run -m 1G node -- node -e "console.log(process.version)"
msb run alpine -- sh -c "uname -a && cat /etc/os-release"
msb run alpine -- sh              # Interactive; TTY is auto-detected.
```

### Create a persistent sandbox

```bash
msb run --name <name> [options] <image> [-- <command>...]
msb create [options] <image> --name <name>
msb exec <name> -- <command>
msb stop <name>
msb start <name>
msb rm <name>
```

Example workflow:

```bash
# Create a Python development sandbox.
msb create python --name dev -m 1G -c 2

# Install packages.
msb exec dev -- pip install requests numpy

# Run code.
msb exec dev -- python -c "import requests; print(requests.get('https://httpbin.org/ip').json())"

# Stop and resume later.
msb stop dev
msb start dev

# Clean up.
msb stop dev
msb rm dev
```

### Common sandbox options

| Flag | Description | Example |
|------|-------------|---------|
| `-n`, `--name` | Name the sandbox | `--name my-sandbox` |
| `-m`, `--memory` | Memory allocation | `-m 512M`, `-m 1G` |
| `-c`, `--cpus` | Number of vCPUs | `-c 2` |
| `-v`, `--volume` | Mount volume | `-v /host/path:/guest/path` |
| `-p`, `--port` | Publish port | `-p 8080:80`, `-p 5353:5353/udp` |
| `-e`, `--env` | Set env variable | `-e API_KEY=xxx` |
| `-w`, `--workdir` | Working directory | `-w /app` |
| `-t`, `--tty` | Force pseudo-terminal allocation | `-t` |
| `-d`, `--detach` | Run in background, for `msb run` | `-d` |
| `-u`, `--user` | Run as user | `-u nobody` |
| `-H`, `--hostname` | Set guest hostname | `-H myhost` |
| `--shell` | Default shell program | `--shell /bin/bash` |
| `--replace` | Replace existing sandbox | `--replace` |
| `--replace-with-grace` | Grace before SIGKILL during replace | `--replace-with-grace 30s` |
| `--entrypoint` | Override image entrypoint | `--entrypoint /bin/sh` |
| `--init`, `--init-arg`, `--init-env` | Hand off PID 1 to guest init | `--init /sbin/init` |
| `--pull` | Pull policy | `--pull always` |
| `--max-duration` | Auto-stop timeout | `--max-duration 5m` |
| `--idle-timeout` | Idle auto-stop | `--idle-timeout 30s` |
| `--tmpfs` | Mount tmpfs | `--tmpfs /tmp:100M` |
| `--script` | Register a shell snippet (wraps with shebang from `--shell`, decodes `\n`/`\t`/`\r`/`\\`/`\"`/`\'`) | `--script setup='apt-get update\napt-get install -y python3'` |
| `--script-raw` | Register exact inline bytes; no shebang or decoding | `--script-raw setup=$'#!/bin/sh\necho hi\n'` |
| `--script-path` | Register a script from a host file (contents read verbatim) | `--script-path setup:./setup.sh` |
| `--snapshot` | Boot from a stopped-sandbox snapshot | `--snapshot baseline` |

### Manage sandboxes

```bash
msb ls                    # List all sandboxes.
msb ls --running          # Running only.
msb ps                    # Running sandboxes with status.
msb ps -a                 # Include stopped sandboxes.
msb inspect <name>        # Detailed sandbox info.
msb metrics <name>        # Live CPU/memory/IO stats.
msb logs <name>           # Captured stdout/stderr, works after stop.
msb logs <name> -f        # Follow logs.
msb stop <name>           # Graceful shutdown.
msb stop --force <name>   # Force kill.
msb stop -t 10 <name>     # Wait 10s, then force kill.
msb rm <name>             # Remove stopped sandbox.
msb rm --force <name>     # Stop and remove in one step.
```

### Manage images

```bash
msb pull <image>          # Pre-cache an OCI image.
msb images                # List cached images, alias for msb image ls.
msb image inspect <img>   # Image metadata.
msb rmi <image>           # Remove cached image, alias for msb image rm.
```

### Manage volumes

```bash
msb volume create <name>             # Create named volume.
msb volume create <name> --size 5G   # With quota.
msb volume ls                        # List volumes.
msb volume inspect <name>            # Volume details.
msb volume rm <name>                 # Remove volume.
```

### Volume mounts

```bash
# Bind mount host directory.
msb run -v ./project:/app python -- python /app/script.py

# Named volume, persistent across sandboxes.
msb volume create mydata
msb run -v mydata:/data alpine -- sh -c "echo 'test' > /data/file.txt"
msb run -v mydata:/data alpine -- cat /data/file.txt
```

### Manage snapshots

Snapshots capture a stopped sandbox's writable layer. They are disk-only and
stopped-only.

```bash
msb stop baseline
msb snapshot create after-setup --from baseline
msb run --name worker --snapshot after-setup -- python -V
msb snapshot ls
msb snapshot inspect after-setup
msb snapshot verify after-setup
msb snapshot export after-setup /tmp/after-setup.tar.zst --with-image
msb snapshot import /tmp/after-setup.tar.zst
msb snapshot rm after-setup
```

### Networking and security

```bash
# No network access.
msb run --network-policy none python -- python script.py

# Public-only is the default. nonlocal allows LAN but blocks loopback,
# link-local, and metadata.
msb run --network-policy public-only python -- python script.py
msb run --network-policy nonlocal python -- python script.py

# Deny specific domains.
msb run --deny-domain "ads.example.com" python
msb run --deny-domain-suffix ".tracking.com" python

# Inject secrets. Placeholder substitution means the real value stays on host.
msb run --secret "OPENAI_API_KEY=$OPENAI_API_KEY@api.openai.com" python

# TLS interception for secret injection.
msb run --tls-intercept --secret "API_KEY=xxx@api.example.com" python

# Trust host CAs inside the guest for corporate TLS proxies.
msb run --trust-host-cas python

# Limit connections.
msb run --max-connections 10 python
```

### Registry authentication

```bash
msb registry login ghcr.io --username octocat
printf '%s\n' "$GHCR_TOKEN" | msb registry login ghcr.io --username octocat --password-stdin
msb registry logout ghcr.io
msb registry ls
```

### Install sandbox as command

```bash
msb install python          # Install as 'python' command.
msb install --name py python  # Custom name.
msb install --tmp alpine    # Fresh sandbox on every invocation.
msb install --list          # Show installed commands.
msb uninstall py            # Remove.
msb self update             # Update msb and libkrunfw.
msb self uninstall          # Remove msb and shell configuration.
```

## Key behaviors

- Sandboxes are **real microVMs** with hardware-level isolation.
- Default network policy is **public-only**.
- Sandboxes from `msb run` without `--name` are **ephemeral**.
- Sandboxes from `msb create` or `msb run --name` are **persistent**.
- `msb create` boots without running a command; use `msb run -d` for detached command runs.
- Secrets use **placeholder substitution**; real credentials never enter the VM.
- Snapshots require a stopped sandbox and capture disk state, not memory or running processes.
- Use `--replace` to recreate an existing sandbox with new settings.

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

For the current docs index optimized for agents, see
https://docs.microsandbox.dev/llms.txt.

For full CLI reference, see [references/cli-reference.md](references/cli-reference.md).
For SDK usage, see [references/sdk-rust.md](references/sdk-rust.md),
[references/sdk-typescript.md](references/sdk-typescript.md),
[references/sdk-python.md](references/sdk-python.md), and
[references/sdk-go.md](references/sdk-go.md).
