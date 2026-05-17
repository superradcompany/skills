# msb CLI Reference

## Install and help

```bash
curl -fsSL https://install.microsandbox.dev | sh
msb --version
msb --tree
msb run --tree
```

Global logging flags:

| Flag | Description |
|------|-------------|
| `--error` | Show only errors |
| `--warn` | Show warnings and errors |
| `--info` | Show info, warnings, and errors |
| `--debug` | Show debug output |
| `--trace` | Show all output including trace |
| `--tree` | Display command tree with descriptions |

## Sandbox lifecycle

### msb run

Create a sandbox and optionally run a command. Without `--name`, the sandbox is
ephemeral and removed when the command finishes. With `--name`, it persists.

```bash
msb run [OPTIONS] <IMAGE-OR-ROOTFS> [-- <COMMAND>...]

msb run python -- python -c "print('hello')"
msb run --name devbox ubuntu -- bash
msb run -d --name worker python -- python worker.py
```

| Flag | Description |
|------|-------------|
| `-n`, `--name` | Sandbox name; omitted means ephemeral |
| `-c`, `--cpus` | Number of virtual CPUs |
| `-m`, `--memory` | Memory allocation, such as `512M`, `1G` |
| `-v`, `--volume` | Mount host path, named volume, tmpfs, or disk image (`SOURCE:DEST`) |
| `-p`, `--port` | Forward port (`HOST:GUEST` or `HOST:GUEST/udp`) |
| `-e`, `--env` | Environment variable (`KEY=VALUE`) |
| `-w`, `--workdir` | Working directory inside sandbox |
| `--shell` | Default shell for `msb run` / attach sessions |
| `-t`, `--tty` | Allocate a pseudo-terminal |
| `-d`, `--detach` | Run in background and print sandbox name |
| `--timeout` | Kill the command after duration; sandbox remains alive |
| `--rlimit` | POSIX resource limit (`nofile=1024`, `nproc=64`, `as=1073741824`) |
| `--detach-keys` | Key sequence to detach from interactive session |
| `--replace` | Replace existing sandbox with same name |
| `--replace-with-grace` | Grace between SIGTERM and SIGKILL during replace |
| `-q`, `--quiet` | Suppress progress output |
| `--entrypoint` | Override image entrypoint |
| `--init` | Hand off PID 1 to this guest init binary after setup |
| `--init-arg` | Argument for the handoff init; repeatable |
| `--init-env` | Env var for the handoff init only; repeatable |
| `-H`, `--hostname` | Guest hostname |
| `-u`, `--user` | Guest user (`nobody`, `1000`, `1000:1000`) |
| `--pull` | Pull policy: `always`, `if-missing`, `never` |
| `--log-level` | Runtime log level: `error`, `warn`, `info`, `debug`, `trace` |
| `--tmpfs` | Mount tmpfs (`PATH` or `PATH:SIZE`) |
| `--script` | Register a shell snippet (`NAME=BODY`). Wrapped with a shebang from `--shell` (default `/bin/sh`). Decodes `\n`, `\t`, `\r`, `\\`, `\"`, `\'`; unknown escapes pass through |
| `--script-raw` | Register exact inline script contents (`NAME=BODY`). No escape decoding or shebang is added |
| `--script-path` | Register a script from a host file (`NAME:PATH`). Contents read verbatim |
| `--snapshot` | Boot from a snapshot artifact instead of an image |
| `--max-duration` | Kill entire sandbox after duration |
| `--idle-timeout` | Stop sandbox after inactivity duration |

Networking flags:

| Flag | Description |
|------|-------------|
| `--no-network` | Disable all network access |
| `--network-policy` | `none`, `public-only`, `nonlocal`, or `allow-all` |
| `--deny-domain` | Deny egress to exact domain; repeatable |
| `--deny-domain-suffix` | Deny egress to suffix such as `.ads.com`; repeatable |
| `--no-dns-rebind-protection` | Allow DNS responses to private/internal IPs |
| `--dns-nameserver` | Upstream DNS server (`IP` or `IP:PORT`); repeatable |
| `--dns-query-timeout-ms` | Per-DNS-query timeout |
| `--max-connections` | Limit concurrent network connections |
| `--trust-host-cas` | Ship host trusted root CAs into the guest |
| `--secret` | Inject secret (`ENV=VALUE@HOST`) |
| `--on-secret-violation` | `block`, `block-and-log`, or `block-and-terminate` |
| `--tls-intercept` | Enable HTTPS inspection |
| `--tls-intercept-port` | TCP port to inspect; default `443` |
| `--tls-bypass` | Skip TLS interception for domain pattern |
| `--no-block-quic` | Allow QUIC/HTTP3 when TLS interception is on |
| `--tls-intercept-ca-cert` | Custom interception CA certificate |
| `--tls-intercept-ca-key` | Custom interception CA private key |
| `--tls-upstream-ca-cert` | Additional upstream trust root; repeatable |

When no `--` command is given, microsandbox uses the image entrypoint and cmd.
If neither exists, an interactive shell starts. When `--` is present, the
command replaces image cmd but preserves entrypoint.

### msb create

Create and boot a sandbox without running a command. Takes the same flags as
`msb run` except `--detach`.

```bash
msb create python --name worker -c 2 -m 1G
msb create --replace python --name worker
msb create --replace-with-grace 30s python --name worker
```

### msb start

```bash
msb start [OPTIONS] <NAME>
```

| Flag | Description |
|------|-------------|
| `-q`, `--quiet` | Suppress progress output |

### msb stop

```bash
msb stop devbox
msb stop --force devbox
msb stop -t 10 devbox
```

| Flag | Description |
|------|-------------|
| `-f`, `--force` | Force kill immediately |
| `-t`, `--timeout` | Seconds to wait before force-kill |
| `-q`, `--quiet` | Suppress progress output |

### msb rm

```bash
msb rm devbox
msb rm --force devbox
msb rm worker-1 worker-2
```

| Flag | Description |
|------|-------------|
| `-f`, `--force` | Stop if running, then remove |
| `-q`, `--quiet` | Suppress progress output |

## Execution

### msb exec

Execute a command inside a running sandbox.

```bash
msb exec [OPTIONS] <NAME> -- <COMMAND>...
```

| Flag | Description |
|------|-------------|
| `-t`, `--tty` | Allocate pseudo-terminal |
| `-e`, `--env` | Environment variable (`KEY=VALUE`) |
| `-w`, `--workdir` | Working directory |
| `-u`, `--user` | Run as guest user |
| `--timeout` | Kill after duration |
| `--rlimit` | POSIX resource limit |
| `-q`, `--quiet` | Suppress progress output |

The CLI auto-detects interactivity. Interactive terminal input uses attach/TTY
mode; piped input captures stdout and stderr separately.

## Logs and inspection

### msb logs

Read captured output from a running or stopped sandbox. User output is stored
as JSON Lines under the sandbox log directory, alongside runtime/kernel
diagnostics.

```bash
msb logs devbox
msb logs devbox --tail 100
msb logs devbox -f --grep ERROR
msb logs devbox --since 5m
msb logs devbox --json | jq 'select(.s == "stderr")'
msb logs devbox --show-id
msb logs devbox --color-sessions
msb logs devbox --source system
msb logs devbox --source all
```

| Flag | Description |
|------|-------------|
| `--tail` | Show last N entries |
| `--since` | Start time, RFC 3339 or relative (`5m`, `2h`, `1d`) |
| `--until` | End time, same formats |
| `-f`, `--follow` | Follow in real time |
| `--timestamps` | Prefix lines with timestamps |
| `--source` | `stdout`, `stderr`, `output`, `system`, `all` |
| `--grep` | Regex filter on body |
| `--json` | Emit raw JSON Lines |
| `--raw` | Base64 encode non-UTF-8 bytes |
| `--show-id` | Prefix lines with session id |
| `--color-sessions` | Color by session id |
| `--color`, `--no-color` | ANSI color control |

Source tags:

- `stdout` and `stderr`: captured pipe-mode streams.
- `output`: PTY-mode combined stdout/stderr.
- `system`: lifecycle markers plus runtime/kernel diagnostics.

### msb ls

```bash
msb ls
msb ls --running
msb ls --stopped
msb ls --format json
msb ls -q
```

### msb ps / status

```bash
msb ps
msb ps my-app
msb ps -a
msb ps --format json
```

### msb metrics

```bash
msb metrics
msb metrics my-app
msb metrics --format json
```

### msb inspect

```bash
msb inspect devbox
msb inspect devbox --format json
```

## Images and registries

### msb pull

```bash
msb pull python
msb pull ghcr.io/my-org/my-image:v1
```

| Flag | Description |
|------|-------------|
| `-f`, `--force` | Re-download even if cached |
| `-q`, `--quiet` | Suppress progress output |
| `--insecure` | Use HTTP instead of HTTPS |
| `--ca-certs` | PEM file with additional CA roots |

### msb image

```bash
msb image ls
msb images
msb image inspect python
msb image rm python
msb rmi python
```

Common flags: `--format json`, `-q`, and `--force` for removal.

### msb registry

```bash
msb registry login ghcr.io --username octocat
printf '%s\n' "$GHCR_TOKEN" | msb registry login ghcr.io --username octocat --password-stdin
msb registry logout ghcr.io
msb registry ls
```

Auth resolution order: explicit SDK auth, OS credential store, microsandbox
config, Docker credential config, then anonymous.

## Volumes

```bash
msb volume create my-data
msb volume create my-data --size 10G
msb volume ls
msb volume ls --format json
msb volume inspect my-data
msb volume rm my-data
```

Mount named volumes with `-v name:/guest/path`. Host bind mounts usually start
with `/`, `./`, or `../`, matching Docker's convention.

## Snapshots

Snapshots capture a stopped sandbox's writable layer. They are disk-only and
stopped-only.

```bash
msb snapshot create after-setup --from baseline
msb snapshot create ./snaps/v1 --from baseline
msb snapshot create after-setup --from baseline --label stage=ready --integrity
msb run --name worker --snapshot after-setup -- python -V
msb snapshot ls
msb snapshot inspect after-setup
msb snapshot inspect after-setup --verify
msb snapshot verify after-setup
msb snapshot rm after-setup
msb snapshot rm after-setup --force
msb snapshot reindex
msb snapshot export after-setup /tmp/snap.tar.zst
msb snapshot export after-setup /tmp/snap.tar.zst --with-image
msb snapshot import /tmp/snap.tar.zst
```

## Install and self-management

### msb install

Install a sandbox image as a command in `~/.microsandbox/bin/`.

```bash
msb install ubuntu
msb install --name nodebox node
msb install --tmp alpine
msb install -c 2 -m 1G python
msb install --list
```

| Flag | Description |
|------|-------------|
| `-n`, `--name` | Command alias name |
| `-c`, `--cpus` | Virtual CPUs |
| `-m`, `--memory` | Memory allocation |
| `-v`, `--volume` | Mount volume |
| `-w`, `--workdir` | Working directory |
| `--shell` | Shell for interactive sessions |
| `-e`, `--env` | Environment variable |
| `-f`, `--force` | Overwrite alias |
| `--no-pull` | Do not pull image before installing |
| `--tmp` | Fresh sandbox on every invocation |
| `-l`, `--list` | List installed commands |

### msb uninstall

```bash
msb uninstall nodebox
msb uninstall ubuntu alpine
```

### msb self

```bash
msb self update
msb self update --force
msb self uninstall
msb self uninstall --yes
```

`msb self update` also has alias `upgrade`.
