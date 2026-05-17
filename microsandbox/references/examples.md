# Common Usage Patterns

## AI agent code execution

Run untrusted code in a microVM. Secrets stay on the host and are substituted
only for allowed destinations.

### CLI

```bash
msb create python --name agent \
  -m 1G -c 2 \
  --secret "OPENAI_API_KEY=$OPENAI_API_KEY@api.openai.com" \
  --tls-intercept

msb exec agent -- python -c "$USER_CODE"
msb logs agent --tail 100
msb stop agent && msb rm agent
```

### TypeScript

```typescript
import { Sandbox } from "microsandbox";

await using sb = await Sandbox.builder("agent")
  .image("python")
  .memory(1024)
  .cpus(2)
  .secretEnv("OPENAI_API_KEY", process.env.OPENAI_API_KEY!, "api.openai.com")
  .replace()
  .create();

const output = await sb.exec("python", ["-c", userCode]);
console.log(output.stdout());
console.error(output.stderr());
```

### Python

```python
from microsandbox import Sandbox, Secret

async with await Sandbox.create(
    "agent",
    image="python",
    memory=1024,
    cpus=2,
    secrets=[
        Secret.env(
            "OPENAI_API_KEY",
            value=api_key,
            allow_hosts=["api.openai.com"],
        )
    ],
    replace=True,
) as sb:
    output = await sb.exec("python", ["-c", user_code])
    print(output.stdout_text)
```

### Rust

```rust
let sb = Sandbox::builder("agent")
    .image("python")
    .memory(1024)
    .cpus(2)
    .secret_env("OPENAI_API_KEY", api_key, "api.openai.com")
    .replace()
    .create()
    .await?;

let output = sb.exec("python", ["-c", &user_code]).await?;
println!("{}", output.stdout()?);
```

### Go

```go
sb, err := m.CreateSandbox(ctx, "agent",
    m.WithImage("python"),
    m.WithMemory(1024),
    m.WithCPUs(2),
    m.WithSecrets(m.Secret.Env(
        "OPENAI_API_KEY",
        apiKey,
        m.SecretEnvOptions{AllowHosts: []string{"api.openai.com"}},
    )),
    m.WithReplace(),
)
if err != nil {
    return err
}
defer sb.Close()

out, err := sb.Exec(ctx, "python", []string{"-c", userCode})
```

## Testing in isolation

Mount source code read-only and run tests in a fresh rootfs.

```bash
msb run -v ./project:/app -w /app python -- sh -c "
  pip install -r requirements.txt
  pytest tests/ -v
"

msb run -v ./project:/app -w /app node -- sh -c "
  npm ci
  npm test
"
```

```typescript
await using sb = await Sandbox.builder("test-runner")
  .image("python")
  .workdir("/app")
  .volume("/app", (v) => v.bind("./project").readonly())
  .replace()
  .create();

await sb.shell("pip install -r requirements.txt");
const result = await sb.shell("pytest tests/ -v");
process.exit(result.success ? 0 : 1);
```

```python
from microsandbox import Sandbox, Volume

sb = await Sandbox.create(
    "test-runner",
    image="python",
    workdir="/app",
    volumes={"/app": Volume.bind("./project", readonly=True)},
    replace=True,
)
result = await sb.shell("pytest tests/ -v")
```

## Persistent development environment

```bash
msb create node --name dev \
  -m 2G -c 4 \
  -v ./src:/app/src \
  -v node_modules:/app/node_modules \
  -p 3000:3000 \
  -w /app

msb exec dev -- npm install
msb exec dev -- sh -c "npm run dev > /tmp/dev.log 2>&1 &"
msb logs dev -f
msb stop dev
msb start dev
```

## Filesystem operations

```typescript
const fs = sb.fs();

await fs.write("/app/config.json", JSON.stringify(config));
await fs.copyFromHost("./data/input.csv", "/app/input.csv");
await sb.exec("python", ["process.py"]);
await fs.copyToHost("/app/output.csv", "./results/output.csv");

for (const entry of await fs.list("/app")) {
  console.log(`${entry.kind} ${entry.path} (${entry.size} bytes)`);
}
```

```python
fs = sb.fs

await fs.write_text("/app/config.json", json.dumps(config))
await fs.copy_from_host("./data/input.csv", "/app/input.csv")
await sb.exec("python", ["process.py"])
await fs.copy_to_host("/app/output.csv", "./results/output.csv")
```

## Network policy patterns

### Air-gapped

```bash
msb pull python
msb run --network-policy none python -- python -c "
import urllib.request
try:
    urllib.request.urlopen('https://example.com')
except Exception as e:
    print('Network blocked:', e)
"
```

```typescript
await using sb = await Sandbox.builder("isolated")
  .image("python")
  .network((n) => n.policy(NetworkPolicy.none()))
  .create();
```

```python
sb = await Sandbox.create("isolated", image="python", network=Network.none())
```

### Allow public internet but deny trackers

```bash
msb run --deny-domain-suffix ".tracking.com" python -- python script.py
```

```typescript
await using sb = await Sandbox.builder("scraper")
  .image("python")
  .network((n) =>
    n.policy(NetworkPolicy.publicOnly()).denyDomainSuffix(".tracking.com"),
  )
  .create();
```

```python
from microsandbox import Network

sb = await Sandbox.create(
    "scraper",
    image="python",
    network=Network(deny_domain_suffixes=(".tracking.com",)),
)
```

## Rootfs patching

Customize the filesystem before the VM boots.

```typescript
await using sb = await Sandbox.builder("patched")
  .image("alpine")
  .patch((p) =>
    p.text("/etc/app/config.yaml", "debug: true\n", { replace: true })
      .mkdir("/var/log/app")
      .copyFile("./cert.pem", "/etc/ssl/cert.pem", { replace: true }),
  )
  .create();
```

```python
from microsandbox import Patch, Sandbox

sb = await Sandbox.create(
    "patched",
    image="alpine",
    patches=[
        Patch.text("/etc/app/config.yaml", "debug: true\n", replace=True),
        Patch.mkdir("/var/log/app"),
        Patch.copy_file("./cert.pem", "/etc/ssl/cert.pem", replace=True),
    ],
)
```

## Snapshots for reusable build state

Install dependencies once, stop the sandbox, snapshot it, then boot fresh
sandboxes from that snapshot.

```bash
msb run --name baseline --detach python -- sleep 3600
msb exec baseline -- pip install requests
msb stop baseline
msb snapshot create after-pip-install --from baseline
msb run --name worker --snapshot after-pip-install \
  -- python -c "import requests; print(requests.__version__)"
```

```typescript
const baseline = await Sandbox.get("baseline");
const snap = await baseline.snapshot("after-pip-install");

await using worker = await Sandbox.builder("worker")
  .fromSnapshot("after-pip-install")
  .create();
```

```python
h = await Sandbox.get("baseline")
snap = await h.snapshot("after-pip-install")
worker = await Sandbox.create("worker", snapshot="after-pip-install")
```

## Interactive shell attach

```bash
msb run --name dev alpine -- sh
msb exec dev -- bash
```

```typescript
const code = await sb.attachShell();
```

```python
code = await sb.attach_shell()
```

```rust
let code = sb.attach_shell().await?;
```

```go
code, err := sb.AttachShell(ctx)
```
