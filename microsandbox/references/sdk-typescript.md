# TypeScript SDK Reference

```bash
npm install microsandbox
```

## Sandbox

```typescript
import { Sandbox } from 'microsandbox'

// Create (attached — stops when process exits)
const sb = await Sandbox.create({ name: "worker", image: "python:3.12" })

// Create (detached — survives process exit)
const sb = await Sandbox.createDetached({ name: "worker", image: "python:3.12" })

// Start a stopped sandbox
const sb = await Sandbox.start("worker")

// Get a handle (lightweight, no live connection)
const handle = await Sandbox.get("worker")

// List all sandboxes
const list = await Sandbox.list()

// Remove
await Sandbox.remove("worker")
```

### Full config

```typescript
import { Mount, NetworkPolicy, Patch, Secret, Sandbox } from 'microsandbox'

const sb = await Sandbox.create({
    name: "worker",
    image: "python:3.12",
    memoryMib: 1024,
    cpus: 2,
    workdir: "/app",
    shell: "/bin/bash",
    env: { DEBUG: "true", API_PORT: "8000" },
    volumes: {
        "/app/src": Mount.bind("./src", { readonly: true }),
        "/data": Mount.named("my-data"),
        "/tmp/scratch": Mount.tmpfs({ sizeMib: 100 }),
    },
    patches: [
        Patch.text("/app/config.json", '{"debug": true}'),
        Patch.mkdir("/app/logs"),
        Patch.copyFile("./cert.pem", "/etc/ssl/cert.pem"),
    ],
    scripts: {
        setup: "#!/bin/bash\napt-get update && apt-get install -y curl",
        start: "#!/bin/bash\nexec python /app/main.py",
    },
    ports: { "8080": 80 },
    network: NetworkPolicy.publicOnly(),
    secrets: [
        Secret.env("OPENAI_API_KEY", {
            value: process.env.OPENAI_API_KEY!,
            allowHosts: ["api.openai.com"],
        }),
    ],
    replace: true,
    pullPolicy: "if-missing",
    logLevel: "warn",
    maxDurationSecs: 3600,
    labels: { team: "ai" },
})
```

## Execution

```typescript
// Run command, collect output
const output = await sb.exec("python", ["-c", "print('hello')"])
console.log(output.stdout())   // "hello\n"
console.log(output.code)       // 0
console.log(output.success)    // true

// Run with config
const output = await sb.execWithConfig({
    cmd: "python",
    args: ["compute.py"],
    cwd: "/app",
    env: { PYTHONPATH: "/app/lib" },
    timeoutMs: 30_000,
    user: "nobody",
    tty: false,
})

// Shell command (interprets pipes, redirects, etc.)
const output = await sb.shell("ls -la /app && echo done")

// Run a named script
const output = await sb.run("setup")
```

### Streaming

```typescript
const handle = await sb.execStream("tail", ["-f", "/var/log/app.log"])

let event
while ((event = await handle.recv()) !== null) {
    switch (event.eventType) {
        case 'stdout': process.stdout.write(event.data); break
        case 'stderr': process.stderr.write(event.data); break
        case 'exited': console.log(`Exit: ${event.code}`); break
    }
}
```

### Interactive stdin

```typescript
const handle = await sb.execStream("python")
const stdin = await handle.takeStdin()
await stdin.write(Buffer.from("print('hello')\n"))
await stdin.write(Buffer.from("exit()\n"))
await handle.wait()
```

## Filesystem

```typescript
const fs = sb.fs()

await fs.write("/app/data.json", Buffer.from('{"key": "value"}'))
const content = await fs.readString("/app/data.json")
const bytes = await fs.read("/app/data.bin")
const entries = await fs.list("/app")         // FsEntry[]
const meta = await fs.stat("/app/data.json")  // FsMetadata
const exists = await fs.exists("/app/data.json")
await fs.mkdir("/app/output")
await fs.copy("/app/a.txt", "/app/b.txt")
await fs.rename("/app/old.txt", "/app/new.txt")
await fs.remove("/app/temp.txt")
await fs.removeDir("/app/cache")
await fs.copyFromHost("./local.txt", "/app/local.txt")
await fs.copyToHost("/app/result.txt", "./result.txt")
```

## Lifecycle

```typescript
await sb.stop()            // Graceful shutdown (SIGTERM)
await sb.kill()            // Force kill (SIGKILL)
await sb.drain()           // Graceful drain (SIGUSR1)
await sb.detach()          // Detach — sandbox keeps running
const status = await sb.wait()            // Wait for exit
const status = await sb.stopAndWait()     // Stop and wait
await sb.removePersisted()                // Remove DB record
```

## Volumes

```typescript
import { Volume } from 'microsandbox'

const vol = await Volume.create({ name: "my-data", quotaMib: 5120 })
const handle = await Volume.get("my-data")
const list = await Volume.list()
await Volume.remove("my-data")
```

## Metrics

```typescript
import { allSandboxMetrics } from 'microsandbox'

const m = await sb.metrics()
// m.cpuPercent, m.memoryBytes, m.memoryLimitBytes,
// m.diskReadBytes, m.diskWriteBytes, m.netRxBytes, m.netTxBytes,
// m.uptimeMs, m.timestampMs

const all = await allSandboxMetrics()  // Record<string, SandboxMetrics>
```

## Network policies

```typescript
import { NetworkPolicy } from 'microsandbox'

NetworkPolicy.none()        // No network
NetworkPolicy.publicOnly()  // Public internet only (default)
NetworkPolicy.allowAll()    // Unrestricted

// Custom rules
{
    rules: [
        { action: "allow", direction: "outbound", protocol: "tcp", port: "443" },
        { action: "deny", direction: "outbound", destination: "private" },
    ],
    defaultAction: "deny",
    blockDomains: ["ads.example.com"],
    blockDomainSuffixes: [".tracking.com"],
    maxConnections: 50,
}
```

## Secrets

```typescript
import { Secret } from 'microsandbox'

Secret.env("API_KEY", {
    value: "sk-xxx",
    allowHosts: ["api.example.com"],
    allowHostPatterns: ["*.example.com"],
    placeholder: "$MSB_API_KEY",        // auto-generated if omitted
    requireTls: true,                    // default
    onViolation: "block-and-log",       // default
})
```

## Patches

```typescript
import { Patch } from 'microsandbox'

Patch.text("/path", "content", { mode: 0o644, replace: true })
Patch.mkdir("/path", { mode: 0o755 })
Patch.append("/path", "appended content")
Patch.copyFile("./host/file", "/guest/file", { replace: true })
Patch.copyDir("./host/dir", "/guest/dir", { replace: true })
Patch.symlink("/target", "/link", { replace: true })
Patch.remove("/path")
```

## Mounts

```typescript
import { Mount } from 'microsandbox'

Mount.bind("./host/path", { readonly: true })
Mount.named("volume-name", { readonly: false })
Mount.tmpfs({ sizeMib: 100 })
```
