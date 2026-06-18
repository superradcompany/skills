---
name: microsandbox
description: >
  Create and manage isolated microsandbox microVMs for safe code execution, testing, development, and agent workflows. Use when the user needs to run untrusted code, create ephemeral or persistent sandboxes, execute commands, copy files, inspect logs and metrics, configure networking or secrets, mount volumes, manage images or snapshots, or use the microsandbox CLI and SDKs.
---

# microsandbox

microsandbox creates hardware-isolated microVMs. Each sandbox is a real VM with its own Linux kernel, not a container.

## Agent operating guidance

- Prefer canonical command names in generated instructions and scripts: use `msb list`, `msb status`, `msb remove`, `msb copy`, `msb image list`, `msb image remove`, `msb volume list`, and `msb snapshot list` instead of shorter aliases.
- Do not use host installation management such as `msb install`, `msb uninstall`, `msb self update`, or `msb self uninstall` unless the user explicitly asks to manage their local `msb` installation.
- Treat host paths, secrets, mounted directories, registry credentials, SSH keys, and published ports as security-sensitive. Prefer least privilege: read-only mounts, explicit allow rules, named volumes for durable state, and scoped secret hosts.
- Use the CLI for quick local workflows and the SDK references when writing application code. Load the relevant reference file only when needed.

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
msb remove <name>
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
msb remove dev
```

### Common sandbox options

| Flag | Description | Example |
|------|-------------|---------|
| `-n`, `--name` | Name the sandbox | `--name my-sandbox` |
| `-m`, `--memory` | Memory allocation | `-m 512M`, `-m 1G` |
| `-c`, `--cpus` | Number of vCPUs | `-c 2` |
| `-v`, `--volume` | Mount host path or named volume | `-v ./src:/app:ro`, `-v data:/data` |
| `--mount-dir`, `--mount-file`, `--mount-disk`, `--mount-named` | Explicit mount kind | `--mount-named data:/data:kind=disk,size=10G` |
| `-p`, `--port` | Publish port | `-p 8080:80`, `-p 0.0.0.0:8080:80`, `-p 5353:5353/udp` |
| `-e`, `--env` | Set env variable | `-e API_KEY=xxx` |
| `--label` | Attach label for selection/metrics | `--label app=worker` |
| `-w`, `--workdir` | Working directory | `-w /app` |
| `-t`, `--tty` | Force pseudo-terminal allocation | `-t` |
| `-d`, `--detach` | Run in background, for `msb run` | `-d` |
| `-u`, `--user` | Run as user | `-u nobody` |
| `-H`, `--hostname` | Set guest hostname | `-H myhost` |
| `--shell` | Default shell program | `--shell /bin/bash` |
| `--replace` | Replace existing sandbox | `--replace` |
| `--replace-with-timeout` | Grace before SIGKILL during replace | `--replace-with-timeout 30s` |
| `--entrypoint` | Override image entrypoint | `--entrypoint /bin/sh` |
| `--init`, `--init-arg`, `--init-env` | Hand off PID 1 to guest init | `--init /sbin/init` |
| `--pull` | Pull policy | `--pull always` |
| `--oci-upper-size` | Writable overlay upper size for OCI images | `--oci-upper-size 8G` |
| `--security` | In-guest security profile | `--security restricted` |
| `--max-duration` | Auto-stop timeout | `--max-duration 5m` |
| `--idle-timeout` | Idle auto-stop | `--idle-timeout 30s` |
| `--tmpfs` | Mount tmpfs | `--tmpfs /tmp:100M` |
| `--copy`, `--copy-file`, `--copy-dir`, `--mkdir`, `--rm` | Patch rootfs before boot | `--copy ./config:/etc/app/config` |
| `--script` | Register a shell snippet (wraps with shebang from `--shell`, decodes `\n`/`\t`/`\r`/`\\`/`\"`/`\'`) | `--script setup='apt-get update\napt-get install -y python3'` |
| `--script-raw` | Register exact inline bytes; no shebang or decoding | `--script-raw setup=$'#!/bin/sh\necho hi\n'` |
| `--script-path` | Register a script from a host file (contents read verbatim) | `--script-path setup:./setup.sh` |
| `--snapshot` | Boot from a stopped-sandbox snapshot | `--snapshot baseline` |
| `--no-net`, `--net-default`, `--net-rule` | Network isolation and allow/deny rules | `--no-net --net-rule "allow@api.example.com:tcp:443"` |

### Manage sandboxes

```bash
msb list                         # List all sandboxes.
msb list --running               # Running only.
msb list --label app=worker      # Filter by label.
msb status                       # Running sandboxes with status.
msb status -a                    # Include stopped sandboxes.
msb inspect <name>               # Detailed sandbox info.
msb metrics <name>               # Live CPU/memory/IO stats.
msb logs <name>                  # Captured stdout/stderr, works after stop.
msb logs <name> -f               # Follow logs.
msb stop <name>                  # Graceful shutdown.
msb stop --force <name>          # Force kill.
msb stop -t 10 <name>            # Wait 10s, then force kill.
msb remove <name>                # Remove stopped sandbox.
msb remove --force <name>        # Stop and remove in one step.
msb remove --label app=worker    # Remove every sandbox with label.
```

### Copy files

```bash
msb copy ./local.txt dev:/tmp/local.txt
msb copy dev:/tmp/out.txt ./out.txt
msb copy dev:/tmp/a dev:/tmp/b
msb copy dev:/tmp/a other:/tmp/a
```

Use `SANDBOX:/absolute/path` for sandbox endpoints. At least one endpoint must be a sandbox path.

### Manage images

```bash
msb image pull <image>              # Pre-cache an OCI image.
msb image load --input image.tar    # Load Docker/OCI archive.
msb image save <image> -o image.tar # Save cached image archive.
msb image list                      # List cached images.
msb image inspect <img>             # Image metadata.
msb image remove <image>            # Remove cached image.
msb image prune --yes               # Remove unused cached images.
```

### Manage volumes

```bash
msb volume create <name>                         # Create named volume.
msb volume create <name> --kind disk --size 5G   # Disk-backed volume.
msb volume create <name> --size 5G               # Directory volume with quota.
msb volume list                                  # List volumes.
msb volume inspect <name>                        # Volume details.
msb volume remove <name>                         # Remove volume.
```

### Volume mounts

```bash
# Bind mount host directory.
msb run -v ./project:/app python -- python /app/script.py

# Named volume, persistent across sandboxes.
msb volume create mydata
msb run -v mydata:/data alpine -- sh -c "echo 'test' > /data/file.txt"
msb run -v mydata:/data alpine -- cat /data/file.txt

# Explicit disk-backed named volume mount.
msb run --mount-named docker-data:/var/lib/docker:kind=disk,size=20G docker:dind
```

### Manage snapshots

Snapshots capture a stopped sandbox's writable layer. They are disk-only and
stopped-only.

```bash
msb stop baseline
msb snapshot create after-setup --from baseline
msb snapshot create after-setup --from baseline --label stage=ready --integrity
msb run --name worker --snapshot after-setup -- python -V
msb snapshot list
msb snapshot inspect after-setup
msb snapshot inspect after-setup --verify
msb snapshot verify after-setup
msb snapshot export after-setup /tmp/after-setup.tar.zst --with-image
msb snapshot import /tmp/after-setup.tar.zst
msb snapshot reindex
msb snapshot remove after-setup
```

### Networking and security

```bash
# No network access.
msb run --no-net python -- python script.py

# Public-only egress is the default when no custom rules are set.
msb run python -- python script.py

# Allowlist specific destinations.
msb run --net-default deny --net-rule "allow@api.example.com:tcp:443" python

# Deny specific suffixes while otherwise using the default public egress model.
msb run --net-rule "deny@*.tracking.com" python

# Inject secrets. Placeholder substitution means the real value stays on host.
msb run --secret "OPENAI_API_KEY=$OPENAI_API_KEY@api.openai.com" python

# TLS interception for secret injection.
msb run --tls-intercept --secret "API_KEY=xxx@api.example.com" python

# Trust host CAs inside the guest for corporate TLS proxies.
msb run --trust-host-cas python

# Limit connections.
msb run --max-connections 10 python
```

Network rule tokens use `<action>[:<direction>]@<target>[:<proto>[:<ports>]]`. Targets can be IP/CIDR values, exact domains, suffixes such as `*.example.com`, or groups such as `public`, `private`, `loopback`, `metadata`, and `any`.

### Registry authentication

```bash
msb registry login ghcr.io --username octocat
printf '%s\n' "$GHCR_TOKEN" | msb registry login ghcr.io --username octocat --password-stdin
msb registry logout ghcr.io
msb registry list
```

### SSH and SFTP

```bash
msb ssh devbox
msb ssh devbox -- uname -a
msb ssh authorize --file ~/.ssh/id_ed25519.pub
msb ssh serve devbox --host 127.0.0.1 --port 2222
sftp -P 2222 root@127.0.0.1
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
