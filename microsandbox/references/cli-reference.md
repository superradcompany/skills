# msb CLI Reference

## Sandbox lifecycle

### msb run

Create a sandbox and optionally run a command. Without `--name`, the sandbox is ephemeral and removed when the command finishes.

```
msb run [OPTIONS] <IMAGE> [-- <COMMAND>...]
```

| Flag | Description |
|------|-------------|
| `-n, --name` | Sandbox name (ephemeral if omitted) |
| `-c, --cpus` | Number of virtual CPUs |
| `-m, --memory` | Memory allocation (`512M`, `1G`, `2G`) |
| `-v, --volume` | Mount volume (`SOURCE:DEST`) |
| `-p, --port` | Forward port (`HOST:GUEST` or `HOST:GUEST/udp`) |
| `-e, --env` | Environment variable (`KEY=VALUE`) |
| `-w, --workdir` | Working directory inside sandbox |
| `-d, --detach` | Run in background |
| `-u, --user` | Run as user (`nobody`, `1000`, `1000:1000`) |
| `-H, --hostname` | Guest hostname |
| `-q, --quiet` | Suppress progress output |
| `--shell` | Default shell for interactive sessions |
| `--replace` | Replace existing sandbox with same name |
| `--entrypoint` | Override image entrypoint |
| `--pull` | Pull policy: `always`, `if-missing` (default), `never` |
| `--log-level` | Runtime log level: `error`, `warn`, `info`, `debug`, `trace` |
| `--tmpfs` | Mount tmpfs (`PATH` or `PATH:SIZE`) |
| `--script` | Register inline script (`NAME=BODY`) |
| `--script-path` | Register script from host file (`NAME:PATH`) |
| `--max-duration` | Auto-stop after duration (`30s`, `5m`, `1h`) |
| `--idle-timeout` | Auto-stop on idle (`30s`, `5m`, `1h`) |
| `--no-network` | Disable all network access |
| `--dns-block-domain` | Block DNS for domain (returns NXDOMAIN) |
| `--dns-block-suffix` | Block DNS for all subdomains of suffix |
| `--no-dns-rebind-protection` | Allow DNS responses to private IPs |
| `--max-connections` | Limit concurrent connections |
| `--secret` | Inject secret (`ENV=VALUE@HOST`) |
| `--on-secret-violation` | Violation action: `block`, `block-and-log`, `block-and-terminate` |
| `--tls-intercept` | Enable HTTPS interception |
| `--tls-intercept-port` | Port for TLS interception (default: 443) |
| `--tls-bypass` | Skip TLS interception for domain |
| `--no-block-quic` | Allow QUIC/HTTP3 traffic |
| `--tls-ca-cert` | Custom CA certificate (PEM) |
| `--tls-ca-key` | Custom CA private key (PEM) |

Without `--`, the image's `entrypoint` and `cmd` are used. With `--`, the command replaces the image `cmd` but preserves the `entrypoint`.

### msb create

Create and boot a sandbox in the background. Takes the same flags as `msb run` except `--detach`.

```
msb create [OPTIONS] <IMAGE>
```

### msb start

Resume a stopped sandbox.

```
msb start [OPTIONS] <NAME>
```

| Flag | Description |
|------|-------------|
| `-q, --quiet` | Suppress progress output |

### msb stop

Stop a running sandbox.

```
msb stop [OPTIONS] <NAME>
```

| Flag | Description |
|------|-------------|
| `-f, --force` | Force kill without graceful shutdown |
| `-t, --timeout` | Seconds to wait before force-killing |
| `-q, --quiet` | Suppress progress output |

### msb rm

Remove one or more sandboxes.

```
msb rm [OPTIONS] <NAME>...
```

| Flag | Description |
|------|-------------|
| `-f, --force` | Stop if running, then remove |
| `-q, --quiet` | Suppress output |

## Execution

### msb exec

Execute a command inside a running sandbox.

```
msb exec [OPTIONS] <NAME> -- <COMMAND>...
```

| Flag | Description |
|------|-------------|
| `-t, --tty` | Allocate pseudo-terminal |
| `-e, --env` | Environment variable (`KEY=VALUE`) |
| `-w, --workdir` | Working directory |
| `-u, --user` | Run as guest user |
| `--timeout` | Kill after duration (`30s`, `5m`, `1h`) |
| `--rlimit` | POSIX resource limit (`nofile=1024`, `nproc=64`) |
| `-q, --quiet` | Suppress progress output |

### msb shell

Open an interactive shell or run a shell script.

```
msb shell [OPTIONS] <NAME> [-- <SCRIPT>...]
```

| Flag | Description |
|------|-------------|
| `--shell` | Shell program (default: config or `/bin/sh`) |
| `-u, --user` | Run as guest user |
| `-q, --quiet` | Suppress progress output |

## Inspection

### msb ls

List all sandboxes.

```
msb ls [OPTIONS]
```

| Flag | Description |
|------|-------------|
| `--running` | Show only running |
| `--stopped` | Show only stopped |
| `--format json` | JSON output |
| `-q, --quiet` | Names only |

### msb ps

Show sandbox status with process details.

```
msb ps [OPTIONS] [NAME]
```

| Flag | Description |
|------|-------------|
| `-a, --all` | Include stopped sandboxes |
| `--format json` | JSON output |
| `-q, --quiet` | Names only |

Aliases: `msb status`

### msb metrics

Show live resource metrics.

```
msb metrics [OPTIONS] [NAME]
```

| Flag | Description |
|------|-------------|
| `--format json` | JSON output |

### msb inspect

Show detailed configuration and status.

```
msb inspect [OPTIONS] <NAME>
```

| Flag | Description |
|------|-------------|
| `--format json` | JSON output |

## Images

### msb pull

Pre-cache an OCI image.

```
msb pull [OPTIONS] <IMAGE>
```

| Flag | Description |
|------|-------------|
| `-f, --force` | Re-download even if cached |
| `-q, --quiet` | Suppress progress output |

### msb image ls

List cached images. Alias: `msb images`.

```
msb image ls [OPTIONS]
```

| Flag | Description |
|------|-------------|
| `--format json` | JSON output |
| `-q, --quiet` | References only |

### msb image inspect

Show image metadata.

```
msb image inspect [OPTIONS] <IMAGE>
```

| Flag | Description |
|------|-------------|
| `--format json` | JSON output |

### msb image rm

Remove cached images. Alias: `msb rmi`. Shared layers are kept.

```
msb image rm [OPTIONS] <IMAGE>...
```

| Flag | Description |
|------|-------------|
| `-f, --force` | Remove even if used by sandboxes |
| `-q, --quiet` | Suppress output |

### msb registry

Manage registry authentication. Credentials are stored in the OS credential store.

```
msb registry login <HOST> --username <USER>
msb registry login <HOST> --username <USER> --password-stdin
msb registry logout <HOST>
msb registry ls
```

Auth resolution order: SDK auth > OS credential store > config file > Docker config > anonymous.

## Volumes

### msb volume create

```
msb volume create [OPTIONS] <NAME>
```

| Flag | Description |
|------|-------------|
| `--size` | Storage quota (`100M`, `1G`, `10G`) |
| `-q, --quiet` | Suppress output |

### msb volume ls

```
msb volume ls [OPTIONS]
```

| Flag | Description |
|------|-------------|
| `--format json` | JSON output |
| `-q, --quiet` | Names only |

### msb volume inspect

```
msb volume inspect <NAME>
```

### msb volume rm

```
msb volume rm [OPTIONS] <NAME>...
```

| Flag | Description |
|------|-------------|
| `-q, --quiet` | Suppress output |

Volume mounting: `./src:/app` is a bind mount (starts with `/` or `.`), `myvolume:/data` is a named volume.

## System

### msb install

Install a sandbox as a system command in `~/.microsandbox/bin/`.

```
msb install [OPTIONS] <IMAGE>
```

| Flag | Description |
|------|-------------|
| `-n, --name` | Command name (defaults to image name) |
| `-c, --cpus` | vCPUs |
| `-m, --memory` | Memory |
| `-v, --volume` | Volume mount |
| `-w, --workdir` | Working directory |
| `-e, --env` | Environment variable |
| `--shell` | Shell for interactive sessions |
| `-f, --force` | Overwrite existing alias |
| `--no-pull` | Don't pull image before installing |
| `--tmp` | Fresh sandbox every invocation |
| `-l, --list` | List installed commands |

### msb uninstall

```
msb uninstall <NAME>...
```

### msb self

```
msb self update            # Update msb and libkrunfw
msb self update --force    # Re-download even if current
msb self uninstall         # Remove msb (with confirmation)
msb self uninstall --yes   # Skip confirmation
```
