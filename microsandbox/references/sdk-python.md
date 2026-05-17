# Python SDK Reference

```bash
pip install microsandbox
```

The Python SDK is async-first. Use `await Sandbox.create(...)` or
`async with await Sandbox.create(...)` for automatic cleanup.

## Sandbox

```python
import asyncio
from microsandbox import Network, Sandbox, Volume

async def main():
    async with await Sandbox.create(
        "worker",
        image="python",
        memory=512,
        cpus=2,
        env={"PYTHONDONTWRITEBYTECODE": "1"},
        volumes={
            "/app/src": Volume.bind("./src", readonly=True),
        },
        network=Network.public_only(),
        replace=True,
    ) as sb:
        output = await sb.exec("python", ["-c", "print('hello')"])
        print(output.stdout_text)

asyncio.run(main())
```

Static methods:

```python
sb = await Sandbox.create("worker", image="alpine")
session = Sandbox.create_with_progress("worker", image="alpine")
sb = await Sandbox.start("worker", detached=False)
handle = await Sandbox.get("worker")
all_sandboxes = await Sandbox.list()
await Sandbox.remove("worker")
```

Pass `detached=True` to `Sandbox.create(...)` when the sandbox should survive
the Python process.

Common config keywords:

```python
sb = await Sandbox.create(
    "worker",
    image="python",
    # Or snapshot="after-setup" instead of image.
    memory=1024,
    cpus=2,
    workdir="/app",
    shell="/bin/bash",
    hostname="worker",
    user="nobody",
    env={"DEBUG": "true"},
    replace=True,
    replace_with_grace=10,
    max_duration=3600,
    idle_timeout=300,
    pull_policy="if-missing",
    volumes={
        "/app": Volume.bind("./src", readonly=True),
        "/data": Volume.named("my-data"),
        "/tmp": Volume.tmpfs(size_mib=128),
        "/disk": Volume.disk("./data.qcow2", fstype="ext4", readonly=True),
    },
    ports={8000: 8000},
    network=Network.public_only(),
)
```

## Execution

```python
output = await sb.exec("python", ["-c", "print('hello')"])
print(output.exit_code)
print(output.success)
print(output.stdout_text)
print(output.stderr_text)
print(output.stdout_bytes)

output = await sb.exec_with(
    "python",
    args=["compute.py"],
    cwd="/app",
    env={"PYTHONPATH": "/app/lib"},
    timeout=30,
    user="nobody",
)

output = await sb.shell("ls -la /app && echo done")
code = await sb.attach("bash", ["-l"])
code = await sb.attach_shell()
```

### Streaming and stdin

```python
from microsandbox import ExecOptions, Stdin

handle = await sb.exec_stream("tail", ["-f", "/var/log/app.log"])
async for event in handle:
    if event.event_type == "stdout":
        print(event.data.decode(), end="")
    if event.event_type == "exited":
        break

handle = await sb.exec_stream_with(
    "python",
    ExecOptions(stdin=Stdin.pipe(), tty=True),
)
stdin = handle.take_stdin()
await stdin.write(b"print('hello')\n")
await stdin.close()
await handle.wait()
```

## Filesystem

```python
fs = sb.fs

await fs.write("/app/data.json", b'{"key":"value"}')
await fs.write_text("/app/message.txt", "hello")
content = await fs.read_text("/app/message.txt")
bytes_ = await fs.read("/app/data.json")
entries = await fs.list("/app")
meta = await fs.stat("/app/data.json")
exists = await fs.exists("/app/data.json")
await fs.mkdir("/app/output")
await fs.copy("/app/a.txt", "/app/b.txt")
await fs.rename("/app/old.txt", "/app/new.txt")
await fs.remove("/app/temp.txt")
await fs.remove_dir("/app/cache")
await fs.copy_from_host("./local.txt", "/app/local.txt")
await fs.copy_to_host("/app/result.txt", "./result.txt")

async for chunk in await fs.read_stream("/var/log/syslog"):
    print(chunk)
```

## Lifecycle, logs, and metrics

```python
await sb.stop()
await sb.kill()
await sb.drain()
await sb.detach()
status = await sb.wait()
status = await sb.stop_and_wait()
await sb.remove_persisted()

metrics = await sb.metrics()
stream = sb.metrics_stream(1.0)
async for sample in stream:
    print(sample.cpu_percent, sample.memory_bytes)

entries = await sb.logs()
```

## Volumes

```python
from microsandbox import Volume

vol = await Volume.create("my-data", quota_mib=5120)
handle = await Volume.get("my-data")
all_volumes = await Volume.list()
await Volume.remove("my-data")
```

Use volume factory helpers in sandbox config:

```python
Volume.bind("./host", readonly=True)
Volume.named("my-data")
Volume.tmpfs(size_mib=128)
Volume.disk("./data.qcow2", fstype="ext4", readonly=True)
```

## Networking and secrets

```python
from microsandbox import Network, Secret

Network.none()
Network.public_only()
Network.allow_all()

network = Network(
    policy="public_only",
    deny_domains=["ads.example.com"],
    deny_domain_suffixes=[".tracking.com"],
    max_connections=50,
    trust_host_cas=True,
)

sb = await Sandbox.create(
    "agent",
    image="python",
    network=network,
    secrets=[
        Secret.env(
            "OPENAI_API_KEY",
            value=api_key,
            allow_hosts=["api.openai.com"],
        )
    ],
)
```

## Snapshots

```python
from microsandbox import Sandbox, Snapshot

handle = await Sandbox.get("baseline")
snap = await handle.snapshot("after-setup")
snap2 = await handle.snapshot_to("/tmp/snaps/after-setup")

worker = await Sandbox.create("worker", snapshot="after-setup")

all_snaps = await Snapshot.list()
snap_handle = await Snapshot.get("after-setup")
await Snapshot.remove("after-setup")
await Snapshot.reindex("~/.microsandbox/snapshots")
```
