# Rust SDK Reference

```toml
[dependencies]
microsandbox = "0.4.2"
tokio = { version = "1", features = ["full"] }
```

## Sandbox

```rust
use microsandbox::Sandbox;

// Create (attached — stops when process exits)
let sb = Sandbox::builder("worker")
    .image("python:3.12")
    .create()
    .await?;

// Create (detached — survives process exit)
let sb = Sandbox::builder("worker")
    .image("python:3.12")
    .create_detached()
    .await?;

// Start a stopped sandbox
let sb = Sandbox::start("worker").await?;

// Get a handle (lightweight, no live connection)
let handle = Sandbox::get("worker").await?;

// List all sandboxes
let list = Sandbox::list().await?;

// Remove
Sandbox::remove("worker").await?;
```

### Full config

```rust
use microsandbox::{Sandbox, NetworkPolicy};

let sb = Sandbox::builder("worker")
    .image("python:3.12")
    .memory(1024)
    .cpus(2)
    .workdir("/app")
    .shell("/bin/bash")
    .env("DEBUG", "true")
    .env("API_PORT", "8000")
    .volume("/app/src", |v| v.bind("./src").readonly())
    .volume("/data", |v| v.named("my-data"))
    .volume("/tmp/scratch", |v| v.tmpfs().size(100))
    .patch(|p| p
        .text("/app/config.json", r#"{"debug": true}"#, Some(0o644), false)
        .mkdir("/app/logs", Some(0o755))
        .copy_file("./cert.pem", "/etc/ssl/cert.pem", None, false)
    )
    .script("setup", "#!/bin/bash\napt-get update && apt-get install -y curl")
    .port(8080, 80)
    .network(|n| n.policy(NetworkPolicy::public_only()))
    .secret_env("OPENAI_API_KEY", api_key, "api.openai.com")
    .replace()
    .create()
    .await?;
```

## Execution

```rust
// Run command, collect output
let output = sb.exec("python", ["-c", "print('hello')"]).await?;
println!("{}", output.stdout()?);    // "hello\n"
println!("{}", output.status().code); // 0

// Run with options
let output = sb.exec_with("python", |e| e
    .args(["compute.py"])
    .cwd("/app")
    .env("PYTHONPATH", "/app/lib")
    .timeout(Duration::from_secs(30))
    .rlimit(RlimitResource::Nofile, 1024)
).await?;

// Shell command (interprets pipes, redirects, etc.)
let output = sb.shell("ls -la /app && echo done").await?;

// Run a named script
let output = sb.shell("setup").await?;
```

### Streaming

```rust
use microsandbox::exec::ExecEvent;

let mut handle = sb.exec_stream("tail", ["-f", "/var/log/app.log"]).await?;

while let Some(event) = handle.recv().await {
    match event {
        ExecEvent::Stdout(data) => print!("{}", String::from_utf8_lossy(&data)),
        ExecEvent::Stderr(data) => eprint!("{}", String::from_utf8_lossy(&data)),
        ExecEvent::Exited { code } => break,
        _ => {}
    }
}
```

### Interactive stdin

```rust
let mut handle = sb.exec_stream_with("python", |e| e.stdin_pipe().tty(true)).await?;
let stdin = handle.take_stdin().unwrap();
stdin.write(b"print('hello')\n").await?;
stdin.write(b"exit()\n").await?;
handle.wait().await?;
```

## Filesystem

```rust
let fs = sb.fs();

fs.write("/app/data.json", b"{\"key\": \"value\"}").await?;
let content = fs.read_string("/app/data.json").await?;
let bytes = fs.read("/app/data.bin").await?;
let entries = fs.list("/app").await?;
let meta = fs.stat("/app/data.json").await?;
fs.mkdir("/app/output").await?;
fs.copy("/app/a.txt", "/app/b.txt").await?;
fs.rename("/app/old.txt", "/app/new.txt").await?;
fs.remove("/app/temp.txt").await?;
fs.remove_dir("/app/cache").await?;
fs.copy_from_host("./local.txt", "/app/local.txt").await?;
fs.copy_to_host("/app/result.txt", "./result.txt").await?;
```

## Lifecycle

```rust
sb.stop().await?;              // Graceful shutdown (SIGTERM)
sb.kill().await?;              // Force kill (SIGKILL)
sb.drain().await?;             // Graceful drain (SIGUSR1)
sb.detach().await?;            // Detach — sandbox keeps running
let status = sb.wait().await?;            // Wait for exit
let status = sb.stop_and_wait().await?;   // Stop and wait
sb.remove_persisted().await?;             // Remove DB record
```

## Volumes

```rust
use microsandbox::Volume;

let vol = Volume::builder("my-data")
    .quota(5120)
    .create()
    .await?;

let handle = Volume::get("my-data").await?;
let list = Volume::list().await?;
Volume::remove("my-data").await?;
```

## Metrics

```rust
let m = sb.metrics().await?;
// m.cpu_percent, m.memory_bytes, m.memory_limit_bytes,
// m.disk_read_bytes, m.disk_write_bytes, m.net_rx_bytes, m.net_tx_bytes,
// m.uptime_ms, m.timestamp_ms

let all = microsandbox::all_sandbox_metrics().await?;
```

## Network policies

```rust
use microsandbox::NetworkPolicy;

// Presets
NetworkPolicy::none()         // No network
NetworkPolicy::public_only()  // Public internet only (default)
NetworkPolicy::allow_all()    // Unrestricted

// Builder
Sandbox::builder("worker")
    .image("python:3.12")
    .disable_network()
    .create().await?;

Sandbox::builder("worker")
    .image("python:3.12")
    .network(|n| n
        .policy(NetworkPolicy::public_only())
        .block_domain("ads.example.com")
        .block_domain_suffix(".tracking.com")
    )
    .create().await?;
```

## Secrets

```rust
// Shorthand (single host)
Sandbox::builder("agent")
    .image("python:3.12")
    .secret_env("OPENAI_API_KEY", api_key, "api.openai.com")
    .create().await?;

// Full builder
Sandbox::builder("agent")
    .image("python:3.12")
    .secret(|s| s
        .env("GITHUB_TOKEN")
        .value(std::env::var("GITHUB_TOKEN")?)
        .allow_host("api.github.com")
        .allow_host_pattern("*.githubusercontent.com")
    )
    .create().await?;
```

## Patches

```rust
Sandbox::builder("worker")
    .image("alpine:latest")
    .patch(|p| p
        .text("/path", "content", Some(0o644), false)       // mode, replace
        .mkdir("/path", Some(0o755))
        .append("/path", "appended content")
        .copy_file("./host", "/guest", None, false)          // mode, replace
        .copy_dir("./host", "/guest", false)                 // replace
        .symlink("/target", "/link", false)                  // replace
        .remove("/path")
    )
    .create().await?;
```
