# Common Usage Patterns

## AI agent code execution

Run untrusted code from an AI agent in a sandboxed microVM with secrets that never enter the VM.

### CLI

```bash
# Create an agent sandbox with secret injection
msb create --name agent \
  -m 1G -c 2 \
  --secret "OPENAI_API_KEY=$OPENAI_API_KEY@api.openai.com" \
  --tls-intercept \
  python:3.12

# Run user-provided code safely
msb exec agent -- python -c "$USER_CODE"

# Clean up
msb stop agent && msb rm agent
```

### TypeScript SDK

```typescript
import { Sandbox, Secret } from 'microsandbox'

const sb = await Sandbox.create({
    name: "agent",
    image: "python:3.12",
    memoryMib: 1024,
    cpus: 2,
    secrets: [
        Secret.env("OPENAI_API_KEY", {
            value: process.env.OPENAI_API_KEY!,
            allowHosts: ["api.openai.com"],
        }),
    ],
})

const output = await sb.exec("python", ["-c", userCode])
console.log(output.stdout())
console.log(output.stderr())

await sb.stopAndWait()
await sb.removePersisted()
```

### Rust SDK

```rust
use microsandbox::Sandbox;

let sb = Sandbox::builder("agent")
    .image("python:3.12")
    .memory(1024)
    .cpus(2)
    .secret_env("OPENAI_API_KEY", api_key, "api.openai.com")
    .create()
    .await?;

let output = sb.exec("python", ["-c", &user_code]).await?;
println!("stdout: {}", output.stdout()?);
println!("stderr: {}", output.stderr()?);

sb.stop_and_wait().await?;
sb.remove_persisted().await?;
```

## Web scraping in sandbox

Isolate web scraping with network policy enforcement.

### CLI

```bash
msb run --name scraper \
  -m 512M \
  --dns-block-suffix ".internal.corp" \
  python:3.12 -- python -c "
import urllib.request
data = urllib.request.urlopen('https://example.com').read()
print(len(data), 'bytes')
"
```

### TypeScript SDK

```typescript
import { NetworkPolicy, Sandbox } from 'microsandbox'

const sb = await Sandbox.create({
    name: "scraper",
    image: "python:3.12",
    network: {
        ...NetworkPolicy.publicOnly(),
        blockDomainSuffixes: [".internal.corp"],
    },
})

await sb.shell("pip install beautifulsoup4 requests")
const output = await sb.shell(`python -c "
import requests
from bs4 import BeautifulSoup
html = requests.get('https://example.com').text
print(BeautifulSoup(html, 'html.parser').title.string)
"`)
console.log(output.stdout())
```

## Testing in isolation

Run test suites in a clean, reproducible environment.

### CLI

```bash
# Mount source code and run tests
msb run -v ./project:/app -w /app python:3.12 -- sh -c "
  pip install -r requirements.txt
  pytest tests/ -v
"

# Node.js tests
msb run -v ./project:/app -w /app node:22 -- sh -c "
  npm ci
  npm test
"
```

### TypeScript SDK

```typescript
import { Mount, Sandbox } from 'microsandbox'

const sb = await Sandbox.create({
    name: "test-runner",
    image: "python:3.12",
    workdir: "/app",
    volumes: {
        "/app": Mount.bind("./project", { readonly: true }),
    },
})

await sb.shell("pip install -r requirements.txt")
const result = await sb.shell("pytest tests/ -v")
console.log(result.stdout())
process.exit(result.success ? 0 : 1)
```

## Development environment

Persistent sandbox for iterative development.

### CLI

```bash
# Create a dev sandbox with ports and volumes
msb create --name dev \
  -m 2G -c 4 \
  -v ./src:/app/src \
  -v node_modules:/app/node_modules \
  -p 3000:3000 \
  -p 5432:5432 \
  -w /app \
  node:22

# Install deps
msb exec dev -- npm install

# Start dev server (detached)
msb exec dev -- sh -c "npm run dev &"

# Check logs
msb exec dev -- cat /tmp/dev.log

# Stop at end of day, resume tomorrow
msb stop dev
msb start dev
```

## File operations

Read and write files in the sandbox filesystem.

### TypeScript SDK

```typescript
const fs = sb.fs()

// Write config
await fs.write("/app/config.json", Buffer.from(JSON.stringify(config)))

// Copy host files into sandbox
await fs.copyFromHost("./data/input.csv", "/app/input.csv")

// Run processing
await sb.exec("python", ["process.py"])

// Retrieve results
await fs.copyToHost("/app/output.csv", "./results/output.csv")

// List directory
const entries = await fs.list("/app")
for (const entry of entries) {
    console.log(`${entry.kind} ${entry.path} (${entry.size} bytes)`)
}
```

## Network-isolated sandbox

Fully air-gapped execution.

### CLI

```bash
# Pre-pull the image (network needed for this)
msb pull python:3.12

# Run with no network at all
msb run --no-network python:3.12 -- python -c "
try:
    import urllib.request
    urllib.request.urlopen('https://example.com')
except Exception as e:
    print(f'Network blocked: {e}')
"
```

### TypeScript SDK

```typescript
import { NetworkPolicy, Sandbox } from 'microsandbox'

const sb = await Sandbox.create({
    name: "isolated",
    image: "python:3.12",
    network: NetworkPolicy.none(),
})

const output = await sb.exec("python", ["-c", untrustedCode])
```

## Rootfs patching

Customize the filesystem before the VM boots.

### TypeScript SDK

```typescript
import { Patch, Sandbox } from 'microsandbox'

const sb = await Sandbox.create({
    name: "patched",
    image: "alpine:latest",
    patches: [
        // Write config files
        Patch.text("/etc/app/config.yaml", `
server:
  port: 8080
  debug: true
`),
        // Create directories
        Patch.mkdir("/app/data"),
        Patch.mkdir("/app/logs"),

        // Copy project files from host
        Patch.copyDir("./app", "/app/src"),

        // Modify existing files
        Patch.append("/etc/hosts", "127.0.0.1 myapp.local\n"),

        // Remove unwanted files
        Patch.remove("/etc/motd"),
    ],
})
```

## Named volumes for data persistence

Share data between sandboxes using named volumes.

### CLI

```bash
# Create a shared data volume
msb volume create shared-data --size 5G

# Writer sandbox
msb run --name writer -v shared-data:/data alpine -- sh -c "
  echo 'processed results' > /data/results.txt
  date >> /data/results.txt
"

# Reader sandbox (separate VM, same data)
msb run --name reader -v shared-data:/data alpine -- cat /data/results.txt

# Clean up
msb volume rm shared-data
```

## Multi-secret agent

Use multiple API keys with host-scoped security.

### TypeScript SDK

```typescript
import { Sandbox, Secret } from 'microsandbox'

const sb = await Sandbox.create({
    name: "multi-agent",
    image: "python:3.12",
    secrets: [
        Secret.env("OPENAI_API_KEY", {
            value: process.env.OPENAI_API_KEY!,
            allowHosts: ["api.openai.com"],
        }),
        Secret.env("GITHUB_TOKEN", {
            value: process.env.GITHUB_TOKEN!,
            allowHosts: ["api.github.com"],
            allowHostPatterns: ["*.githubusercontent.com"],
        }),
        Secret.env("SLACK_TOKEN", {
            value: process.env.SLACK_TOKEN!,
            allowHosts: ["slack.com"],
            allowHostPatterns: ["*.slack.com"],
            onViolation: "block-and-terminate",
        }),
    ],
})
```
