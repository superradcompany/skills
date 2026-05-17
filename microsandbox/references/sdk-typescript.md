# TypeScript SDK Reference

```bash
npm install microsandbox
```

The current TypeScript SDK is builder-only for new sandboxes. Start with
`Sandbox.builder(name)`, chain configuration, then call `.create()` or
`.createDetached()`.

## Sandbox

```typescript
import { NetworkPolicy, Sandbox } from "microsandbox";

await using sb = await Sandbox.builder("worker")
  .image("python")
  .memory(512)
  .cpus(2)
  .env("PYTHONDONTWRITEBYTECODE", "1")
  .volume("/app/src", (m) => m.bind("./src").readonly())
  .network((n) => n.policy(NetworkPolicy.publicOnly()))
  .replace()
  .create();

const output = await sb.exec("python", ["-c", "print('hello')"]);
console.log(output.stdout());
```

Static methods:

```typescript
const builder = Sandbox.builder("worker");
const sb = await Sandbox.start("worker");
const sbDetached = await Sandbox.startDetached("worker");
const handle = await Sandbox.get("worker");
const all = await Sandbox.list();
await Sandbox.remove("worker");
```

Builder methods:

```typescript
await using sb = await Sandbox.builder("worker")
  .image("python")                 // OCI image, local rootfs, or disk path
  // .fromSnapshot("after-setup")  // Use instead of image()
  .memory(1024)
  .cpus(2)
  .workdir("/app")
  .shell("/bin/bash")
  .hostname("worker")
  .user("nobody")
  .env("DEBUG", "true")
  .envs({ API_PORT: "8000" })
  .script("setup", "#!/bin/sh\necho setup")
  .replace()
  .replaceWithGrace(10_000)
  .maxDuration(3600)
  .idleTimeout(300)
  .pullPolicy("if-missing")
  .port(8000, 8000)
  .portUdp(5353, 5353)
  .create();
```

Use `createDetached()` when the sandbox should survive the Node.js process.
Use `createWithPullProgress()` or `createDetachedWithPullProgress()` when you
need image pull progress events.

## Execution

```typescript
const output = await sb.exec("python", ["-c", "print('hello')"]);
console.log(output.stdout());
console.log(output.stderr());
console.log(output.code);
console.log(output.success);

const output2 = await sb.execWith("python", (e) =>
  e.args(["compute.py"])
    .cwd("/app")
    .env("PYTHONPATH", "/app/lib")
    .timeout(30_000)
    .user("nobody"),
);

const shellOut = await sb.shell("ls -la /app && echo done");
const exitCode = await sb.attach("bash", ["-l"]);
const shellExitCode = await sb.attachShell();
```

### Streaming and stdin

```typescript
const handle = await sb.execStream("tail", ["-f", "/var/log/app.log"]);

for await (const event of handle) {
  if (event.kind === "stdout") process.stdout.write(event.data);
  if (event.kind === "stderr") process.stderr.write(event.data);
  if (event.kind === "exited") break;
}

const py = await sb.execStreamWith("python", (e) => e.stdinPipe().tty(true));
const stdin = await py.takeStdin();
await stdin?.write(Buffer.from("print('hello')\n"));
await stdin?.close();
await py.wait();
```

## Filesystem

```typescript
const fs = sb.fs();

await fs.write("/app/data.json", '{"key":"value"}');
await fs.write("/app/message.txt", "hello");
const text = await fs.readToString("/app/message.txt");
const bytes = await fs.read("/app/data.json");
const entries = await fs.list("/app");
const meta = await fs.stat("/app/data.json");
const exists = await fs.exists("/app/data.json");
await fs.mkdir("/app/output");
await fs.copy("/app/a.txt", "/app/b.txt");
await fs.rename("/app/old.txt", "/app/new.txt");
await fs.remove("/app/temp.txt");
await fs.removeDir("/app/cache");
await fs.copyFromHost("./local.txt", "/app/local.txt");
await fs.copyToHost("/app/result.txt", "./result.txt");

for await (const chunk of await fs.readStream("/var/log/syslog")) {
  process.stdout.write(chunk);
}
```

## Lifecycle, logs, and metrics

```typescript
await sb.stop();
await sb.kill();
await sb.drain();
await sb.detach();
const status = await sb.wait();
const stopped = await sb.stopAndWait();
await sb.removePersisted();

const metrics = await sb.metrics();
for await (const sample of await sb.metricsStream(1000)) {
  console.log(sample.cpuPercent, sample.memoryBytes);
}

const logs = await sb.logs({ tail: 100, sources: ["stdout", "stderr"] });
for (const entry of logs) console.log(entry.text());
```

## Volumes and mounts

```typescript
import { Volume } from "microsandbox";

const vol = await Volume.builder("my-data")
  .quota(5120)
  .label("env", "dev")
  .create();

const handle = await Volume.get("my-data");
const allVolumes = await Volume.list();
await Volume.remove("my-data");
```

Mounts are configured on the sandbox builder:

```typescript
await using sb = await Sandbox.builder("worker")
  .image("alpine")
  .volume("/host", (m) => m.bind("./src").readonly())
  .volume("/data", (m) => m.named("my-data"))
  .volume("/scratch", (m) => m.tmpfs().size(128))
  .volume("/disk", (m) => m.disk("./data.qcow2").fstype("ext4").readonly())
  .create();
```

## Networking and secrets

```typescript
import { Destination, NetworkPolicy, Rule, Sandbox } from "microsandbox";

NetworkPolicy.none();
NetworkPolicy.publicOnly();
NetworkPolicy.nonLocal();
NetworkPolicy.allowAll();

const policy = {
  defaultEgress: "deny",
  defaultIngress: "allow",
  rules: [
    Rule.allowEgress(Destination.domain("api.openai.com")),
    Rule.denyEgress(Destination.group("metadata")),
  ],
};

await using sb = await Sandbox.builder("agent")
  .image("python")
  .network((n) =>
    n.policy(policy)
      .denyDomain("ads.example.com")
      .denyDomainSuffix(".tracking.com")
      .maxConnections(50)
      .trustHostCas(true),
  )
  .secretEnv("OPENAI_API_KEY", process.env.OPENAI_API_KEY!, "api.openai.com")
  .secret((s) =>
    s.env("STRIPE_KEY")
      .value(process.env.STRIPE_KEY!)
      .allowHost("api.stripe.com")
      .allowHostPattern("*.stripe.com")
      .injectHeaders(true)
      .injectQuery(false),
  )
  .create();
```

## Patches

Rootfs patches are applied before boot:

```typescript
await using sb = await Sandbox.builder("patched")
  .image("alpine")
  .patch((p) =>
    p.text("/etc/app/config.json", '{"debug":true}', { mode: 0o644, replace: true })
      .mkdir("/var/log/app", { mode: 0o755 })
      .append("/etc/profile", "\nexport APP_ENV=dev\n")
      .copyFile("./cert.pem", "/etc/ssl/cert.pem", { replace: true })
      .copyDir("./assets", "/opt/assets", { replace: true })
      .symlink("/opt/assets", "/assets", { replace: true })
      .remove("/tmp/old"),
  )
  .create();
```

## Snapshots

```typescript
import { Sandbox, Snapshot } from "microsandbox";

const handle = await Sandbox.get("baseline");
const snap = await handle.snapshot("after-setup");
const snap2 = await handle.snapshotTo("/tmp/snaps/after-setup");

await using worker = await Sandbox.builder("worker")
  .fromSnapshot("after-setup")
  .create();

const allSnaps = await Snapshot.list();
const snapHandle = await Snapshot.get("after-setup");
await Snapshot.remove("after-setup");
await Snapshot.reindex("~/.microsandbox/snapshots");
```
