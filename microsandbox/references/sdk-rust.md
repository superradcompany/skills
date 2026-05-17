# Rust SDK Reference

```toml
[dependencies]
microsandbox = "0.4.2"
tokio = { version = "1", features = ["full"] }
```

## Sandbox

```rust
use microsandbox::{NetworkPolicy, Sandbox};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let sb = Sandbox::builder("worker")
        .image("python")
        .memory(512)
        .cpus(2)
        .env("PYTHONDONTWRITEBYTECODE", "1")
        .volume("/app/src", |v| v.bind("./src").readonly())
        .network(|n| n.policy(NetworkPolicy::public_only()))
        .replace()
        .create()
        .await?;

    let output = sb.exec("python", ["-c", "print('hello')"]).await?;
    println!("{}", output.stdout()?);

    sb.stop().await?;
    Ok(())
}
```

Static methods:

```rust
let builder = Sandbox::builder("worker");
let sb = Sandbox::start("worker").await?;
let sb = Sandbox::start_detached("worker").await?;
let handle = Sandbox::get("worker").await?;
let all = Sandbox::list().await?;
Sandbox::remove("worker").await?;
```

Common builder methods:

```rust
use microsandbox::{LogLevel, PullPolicy, RlimitResource, Sandbox};
use std::time::Duration;

let sb = Sandbox::builder("worker")
    .image("python")
    // Or .from_snapshot("after-setup") instead of .image(...).
    .memory(1024)
    .cpus(2)
    .workdir("/app")
    .shell("/bin/bash")
    .hostname("worker")
    .user("nobody")
    .env("DEBUG", "true")
    .envs([("API_PORT", "8000")])
    .script("setup", "#!/bin/sh\necho setup")
    .replace()
    .replace_with_grace(Duration::from_secs(10))
    .pull_policy(PullPolicy::IfMissing)
    .log_level(LogLevel::Warn)
    .max_duration(3600)
    .idle_timeout(300)
    .rlimit(RlimitResource::Nofile, 1024)
    .port(8000, 8000)
    .port_udp(5353, 5353)
    .create()
    .await?;
```

Use `create_detached()` when the sandbox should survive the Rust process.

## Execution

```rust
use std::time::Duration;

let output = sb.exec("python", ["-c", "print('hello')"]).await?;
println!("{}", output.stdout()?);
println!("{}", output.stderr()?);
println!("{}", output.status().code);

let output = sb.exec_with("python", |e| e
    .args(["compute.py"])
    .cwd("/app")
    .env("PYTHONPATH", "/app/lib")
    .timeout(Duration::from_secs(30))
    .user("nobody")
).await?;

let shell_out = sb.shell("ls -la /app && echo done").await?;
let code = sb.attach("bash", ["-l"]).await?;
let code = sb.attach_shell().await?;
```

### Streaming and stdin

```rust
use microsandbox::exec::ExecEvent;
use tokio::io::AsyncWriteExt;

let mut handle = sb.exec_stream("tail", ["-f", "/var/log/app.log"]).await?;
while let Some(event) = handle.recv().await {
    match event {
        ExecEvent::Stdout(data) => print!("{}", String::from_utf8_lossy(&data)),
        ExecEvent::Stderr(data) => eprint!("{}", String::from_utf8_lossy(&data)),
        ExecEvent::Exited { code } => {
            println!("exit {code}");
            break;
        }
        _ => {}
    }
}

let mut py = sb.exec_stream_with("python", |e| e.stdin_pipe().tty(true)).await?;
if let Some(mut stdin) = py.take_stdin() {
    stdin.write_all(b"print('hello')\n").await?;
    stdin.close().await?;
}
py.wait().await?;
```

## Filesystem

```rust
let fs = sb.fs();

fs.write("/app/data.json", b"{\"key\":\"value\"}").await?;
fs.write("/app/message.txt", "hello").await?;
let text = fs.read_to_string("/app/message.txt").await?;
let bytes = fs.read("/app/data.json").await?;
let entries = fs.list("/app").await?;
let meta = fs.stat("/app/data.json").await?;
let exists = fs.exists("/app/data.json").await?;
fs.mkdir("/app/output").await?;
fs.copy("/app/a.txt", "/app/b.txt").await?;
fs.rename("/app/old.txt", "/app/new.txt").await?;
fs.remove("/app/temp.txt").await?;
fs.remove_dir("/app/cache").await?;
fs.copy_from_host("./local.txt", "/app/local.txt").await?;
fs.copy_to_host("/app/result.txt", "./result.txt").await?;
```

## Lifecycle, logs, and metrics

```rust
use microsandbox::sandbox::{LogOptions, LogSource};
use std::time::Duration;

sb.stop().await?;
sb.kill().await?;
sb.drain().await?;
sb.detach().await;
let status = sb.wait().await?;
let status = sb.stop_and_wait().await?;
sb.remove_persisted().await?;

let metrics = sb.metrics().await?;
let mut stream = sb.metrics_stream(Duration::from_secs(1));

let entries = sb.logs(&LogOptions {
    tail: Some(100),
    sources: vec![LogSource::Stdout, LogSource::Stderr],
    ..Default::default()
})?;
```

## Volumes and mounts

```rust
use microsandbox::Volume;

let vol = Volume::builder("my-data")
    .quota(5120)
    .label("env", "dev")
    .create()
    .await?;

let handle = Volume::get("my-data").await?;
let all = Volume::list().await?;
Volume::remove("my-data").await?;
```

Mounts are configured on the sandbox builder:

```rust
let sb = Sandbox::builder("worker")
    .image("alpine")
    .volume("/host", |v| v.bind("./src").readonly())
    .volume("/data", |v| v.named("my-data"))
    .volume("/scratch", |v| v.tmpfs().size(128))
    .volume("/disk", |v| v.disk("./data.qcow2").fstype("ext4").readonly())
    .create()
    .await?;
```

## Networking and secrets

```rust
use microsandbox::{NetworkPolicy, Sandbox};

NetworkPolicy::none();
NetworkPolicy::public_only();
NetworkPolicy::non_local();
NetworkPolicy::allow_all();

let sb = Sandbox::builder("agent")
    .image("python")
    .network(|n| n
        .policy(NetworkPolicy::public_only())
        .deny_domain("ads.example.com")
        .deny_domain_suffix(".tracking.com")
        .max_connections(50)
        .trust_host_cas(true)
    )
    .secret_env("OPENAI_API_KEY", api_key, "api.openai.com")
    .secret(|s| s
        .env("STRIPE_KEY")
        .value(stripe_key)
        .allow_host("api.stripe.com")
        .allow_host_pattern("*.stripe.com")
        .inject_headers(true)
        .inject_query(false)
    )
    .create()
    .await?;
```

## Patches

```rust
let sb = Sandbox::builder("patched")
    .image("alpine")
    .patch(|p| p
        .text("/etc/app/config.json", r#"{"debug":true}"#, Some(0o644), true)
        .mkdir("/var/log/app", Some(0o755))
        .append("/etc/profile", "\nexport APP_ENV=dev\n")
        .copy_file("./cert.pem", "/etc/ssl/cert.pem", None, true)
        .copy_dir("./assets", "/opt/assets", true)
        .symlink("/opt/assets", "/assets", true)
        .remove("/tmp/old")
    )
    .create()
    .await?;
```

## Snapshots

```rust
use microsandbox::{Sandbox, Snapshot};

let handle = Sandbox::get("baseline").await?;
let snap = handle.snapshot("after-setup").await?;
let snap2 = handle.snapshot_to("/tmp/snaps/after-setup").await?;

let worker = Sandbox::builder("worker")
    .from_snapshot("after-setup")
    .create()
    .await?;

let all = Snapshot::list().await?;
let snap_handle = Snapshot::get("after-setup").await?;
Snapshot::remove("after-setup", false).await?;
Snapshot::reindex("~/.microsandbox/snapshots").await?;
```
