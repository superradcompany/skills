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

Agent notes:

- Use canonical command names in generated commands: `list`, `status`, `remove`, `copy`, `image list`, `image remove`, `volume list`, `volume remove`, `snapshot list`, and `snapshot remove`.
- Avoid command aliases in new instructions. Alias handling exists for humans at the CLI, but canonical names are clearer and more stable for agent-authored scripts.
- Do not run host installation-management commands such as command installation, runtime self-update, or runtime self-uninstall unless the user explicitly asks for host setup changes.

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
| `--mount-dir`, `--mount-file`, `--mount-disk`, `--mount-named` | Explicit mount kind (`SOURCE:DEST[:OPTIONS]` or `NAME:DEST[:OPTIONS]`) |
| `-p`, `--port` | Forward port (`HOST:GUEST` or `HOST:GUEST/udp`) |
| `-e`, `--env` | Environment variable (`KEY=VALUE`) |
| `--label` | Sandbox label (`KEY=VALUE`, or bare `KEY`), repeatable |
| `-w`, `--workdir` | Working directory inside sandbox |
| `--shell` | Default shell for `msb run` / attach sessions |
| `-t`, `--tty` | Allocate a pseudo-terminal |
| `-d`, `--detach` | Run in background and print sandbox name |
| `--timeout` | Kill the command after duration; sandbox remains alive |
| `--rlimit` | POSIX resource limit (`nofile=1024`, `nproc=64`, `as=1073741824`) |
| `--detach-keys` | Key sequence to detach from interactive session |
| `--replace` | Replace existing sandbox with same name |
| `--replace-with-timeout` | Grace between SIGTERM and SIGKILL during replace |
| `-q`, `--quiet` | Suppress progress output |
| `--entrypoint` | Override image entrypoint |
| `--init` | Hand off PID 1 to this guest init binary after setup |
| `--init-arg` | Argument for the handoff init; repeatable |
| `--init-env` | Env var for the handoff init only; repeatable |
| `-H`, `--hostname` | Guest hostname |
| `-u`, `--user` | Guest user (`nobody`, `1000`, `1000:1000`) |
| `--pull` | Pull policy: `always`, `if-missing`, `never` |
| `--oci-upper-size` | Writable overlay upper size for OCI images |
| `--log-level` | Runtime log level: `error`, `warn`, `info`, `debug`, `trace` |
| `--tmpfs` | Mount tmpfs (`PATH` or `PATH:SIZE`) |
| `--security` | In-guest security profile: `default` or `restricted` |
| `--script` | Register a shell snippet (`NAME=BODY`). Wrapped with a shebang from `--shell` (default `/bin/sh`). Decodes `\n`, `\t`, `\r`, `\\`, `\"`, `\'`; unknown escapes pass through |
| `--script-raw` | Register exact inline script contents (`NAME=BODY`). No escape decoding or shebang is added |
| `--script-path` | Register a script from a host file (`NAME:PATH`). Contents read verbatim |
| `--copy`, `--copy-file`, `--copy-dir`, `--mkdir`, `--rm` | Patch the rootfs before boot |
| `--snapshot` | Boot from a snapshot artifact instead of an image |
| `--max-duration` | Kill entire sandbox after duration |
| `--idle-timeout` | Stop sandbox after inactivity duration |

Networking flags:

| Flag | Description |
|------|-------------|
| `--no-net` | Disable all network access by default; combine with `--net-rule allow@...` for allowlists |
| `--net-rule` | Add allow/deny rule tokens such as `allow@api.example.com:tcp:443` or `deny@*.ads.example.com` |
| `--net-default` | Default action for unmatched traffic in both directions: `allow` or `deny` |
| `--net-default-egress` | Default unmatched egress action |
| `--net-default-ingress` | Default unmatched ingress action |
| `--no-dns-rebind-protection` | Allow DNS responses to private/internal IPs |
| `--dns-nameserver` | Upstream DNS server (`IP` or `IP:PORT`); repeatable |
| `--dns-query-timeout-ms` | Per-DNS-query timeout |
| `--net-ipv4-pool`, `--net-ipv6-pool` | Address pools for per-sandbox subnets |
| `--max-connections` | Limit concurrent network connections |
| `--trust-host-cas` | Ship host trusted root CAs into the guest |
| `--secret` | Inject secret (`ENV=VALUE@HOST`) |
| `--on-secret-violation` | `block`, `block-and-log`, `block-and-terminate`, or `passthrough` |
| `--tls-intercept` | Enable HTTPS inspection |
| `--tls-intercept-port` | TCP port to inspect; default `443` |
| `--tls-bypass` | Skip TLS interception for domain pattern |
| `--no-block-quic` | Allow QUIC/HTTP3 when TLS interception is on |
| `--tls-intercept-ca-cert` | Custom interception CA certificate |
| `--tls-intercept-ca-key` | Custom interception CA private key |
| `--tls-upstream-ca-cert` | Additional upstream trust root; repeatable |

Network rule tokens use `<action>[:<direction>]@<target>[:<proto>[:<ports>]]`. Targets can be IP/CIDR values, exact domains, suffixes such as `*.example.com`, or groups such as `public`, `private`, `multicast`, `loopback`, `link_local`, `metadata`, and `any`.

When no `--` command is given, microsandbox uses the image entrypoint and cmd.
If neither exists, an interactive shell starts. When `--` is present, the
command replaces image cmd but preserves entrypoint.

### msb create

Create and boot a sandbox without running a command. Takes the same flags as
`msb run` except `--detach`.

```bash
msb create python --name worker -c 2 -m 1G
msb create --replace python --name worker
msb create --replace-with-timeout 30s python --name worker
```

### msb start

```bash
msb start [OPTIONS] <NAME>
msb start --label app=engine
```

| Flag | Description |
|------|-------------|
| `--label` | Start every sandbox carrying this label; repeatable, AND-matched |
| `-q`, `--quiet` | Suppress progress output |

### msb stop

```bash
msb stop devbox
msb stop --force devbox
msb stop -t 10 devbox
msb stop --label app=engine
```

| Flag | Description |
|------|-------------|
| `--label` | Stop every sandbox carrying this label; repeatable, AND-matched |
| `-f`, `--force` | Force kill immediately |
| `-t`, `--timeout` | Seconds to wait before force-kill |
| `-q`, `--quiet` | Suppress progress output |

### msb remove

```bash
msb remove devbox
msb remove --force devbox
msb remove worker-1 worker-2
msb remove --force --label app=engine
```

| Flag | Description |
|------|-------------|
| `--label` | Remove every sandbox carrying this label; repeatable, AND-matched |
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

### msb copy

Copy files between the host and one or more sandboxes. Use `SANDBOX:/absolute/path` for sandbox endpoints. At least one endpoint must be a sandbox path.

```bash
msb copy ./local.txt devbox:/tmp/local.txt
msb copy devbox:/tmp/out.txt ./out.txt
msb copy devbox:/tmp/a devbox:/tmp/b
msb copy devbox:/tmp/a otherbox:/tmp/a
```

| Flag | Description |
|------|-------------|
| `-q`, `--quiet` | Suppress progress output |

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

### msb list

```bash
msb list
msb list --running
msb list --stopped
msb list --label app=engine
msb list --format json
msb list -q
```

### msb status

```bash
msb status
msb status my-app
msb status -a
msb status --label app=engine
msb status --format json
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

### msb image pull

```bash
msb image pull python
msb image pull ghcr.io/my-org/my-image:v1
```

| Flag | Description |
|------|-------------|
| `-f`, `--force` | Re-download even if cached |
| `-q`, `--quiet` | Suppress progress output |
| `--insecure` | Use HTTP instead of HTTPS |
| `--ca-certs` | PEM file with additional CA roots |

### msb image

```bash
msb image pull python
msb image load --input image.tar
docker save my-image:latest | msb image load --tag my-image:latest
msb image save --output image.tar my-image:latest
msb image save --format oci --output image.oci.tar my-image:latest
msb image list
msb image list --format json
msb image inspect python
msb image remove python
msb image prune --yes
msb image prune --format json
```

Common flags: `--format json`, `-q`, and `--force` for removal. `image prune` removes cached images not used by sandboxes and requires confirmation unless `--yes` is supplied.

### msb registry

```bash
msb registry login ghcr.io --username octocat
printf '%s\n' "$GHCR_TOKEN" | msb registry login ghcr.io --username octocat --password-stdin
msb registry logout ghcr.io
msb registry list
```

Auth resolution order: explicit SDK auth, OS credential store, microsandbox
config, Docker credential config, then anonymous.

## Volumes

```bash
msb volume create my-data
msb volume create my-data --size 10G
msb volume create docker-data --kind disk --size 10G
msb volume list
msb volume list --format json
msb volume inspect my-data
msb volume remove my-data
```

Mount named volumes with `-v name:/guest/path` or `--mount-named name:/guest/path[:OPTIONS]`. Host bind mounts usually start with `/`, `./`, or `../`, matching Docker's convention. `--mount-named` can create missing named volumes idempotently and accepts `kind=dir|disk`, `size=...` for disk-backed volumes, and `quota=...` for directory-backed volumes.

## Snapshots

Snapshots capture a stopped sandbox's writable layer. They are disk-only and
stopped-only.

```bash
msb snapshot create after-setup --from baseline
msb snapshot create ./snaps/v1 --from baseline
msb snapshot create after-setup --from baseline --label stage=ready --integrity
msb run --name worker --snapshot after-setup -- python -V
msb snapshot list
msb snapshot inspect after-setup
msb snapshot inspect after-setup --verify
msb snapshot verify after-setup
msb snapshot remove after-setup
msb snapshot remove after-setup --force
msb snapshot reindex
msb snapshot export after-setup /tmp/snap.tar.zst
msb snapshot export after-setup /tmp/snap.tar.zst --with-image
msb snapshot import /tmp/snap.tar.zst
```

## SSH and SFTP

### msb ssh

Start a native SSH client session into a sandbox. With no remote command, this opens an interactive shell. With `--`, the remaining tokens are joined into the remote shell command.

```bash
msb ssh devbox
msb ssh devbox -- uname -a
msb ssh --name serve -- uptime
```

### msb ssh authorize

Add a public key to microsandbox's SSH authorization file.

```bash
msb ssh authorize --file ~/.ssh/id_ed25519.pub
msb ssh authorize --key "ssh-ed25519 AAAA... user@host"
cat ~/.ssh/id_ed25519.pub | msb ssh authorize --stdin
```

### msb ssh serve

Serve a sandbox over SSH for OpenSSH, SFTP, local TCP forwarding, dynamic TCP forwarding, or `ProxyCommand` clients.

```bash
msb ssh serve devbox
msb ssh serve devbox --host 127.0.0.1 --port 2222
msb ssh serve devbox --stdio
sftp -P 2222 root@127.0.0.1
ssh -p 2222 -L 8080:127.0.0.1:80 root@127.0.0.1
```

| Flag | Description |
|------|-------------|
| `--host` | Listener host, default `127.0.0.1` |
| `--port` | Listener port, default `2222` |
| `--stdio` | Serve one SSH transport over stdin/stdout for OpenSSH `ProxyCommand` |

Reverse forwarding (`-R`) and stream-local forwarding are not supported.

## Host installation management

This reference intentionally focuses on sandbox operations. Use host installation-management commands only when the user explicitly asks to install commands, uninstall commands, update the local runtime, or remove the local runtime. For current details, use `msb --tree`, `msb install --help`, `msb uninstall --help`, or `msb self --help` on the user's machine.
