# Go SDK Reference

```bash
go get github.com/superradcompany/microsandbox/sdk/go
```

The Go SDK uses top-level functions plus functional options. Call
`EnsureInstalled(ctx)` during startup to surface runtime install errors early.

## Sandbox

```go
package main

import (
    "context"
    "fmt"
    "log"
    "time"

    m "github.com/superradcompany/microsandbox/sdk/go"
)

func main() {
    ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
    defer cancel()

    if err := m.EnsureInstalled(ctx); err != nil {
        log.Fatal(err)
    }

    sb, err := m.CreateSandbox(ctx, "worker",
        m.WithImage("python"),
        m.WithMemory(512),
        m.WithCPUs(2),
        m.WithEnv(map[string]string{"PYTHONDONTWRITEBYTECODE": "1"}),
        m.WithReplace(),
    )
    if err != nil {
        log.Fatal(err)
    }
    defer func() {
        _, _ = sb.StopAndWait(context.Background())
        _ = sb.Close()
        _ = m.RemoveSandbox(context.Background(), "worker")
    }()

    out, err := sb.Exec(ctx, "python", []string{"-c", "print('hello')"})
    if err != nil {
        log.Fatal(err)
    }
    fmt.Println(out.Stdout())
}
```

Top-level functions:

```go
err := m.EnsureInstalled(ctx)
ok := m.IsInstalled()
sdkVersion := m.SDKVersion()
runtimeVersion, err := m.RuntimeVersion()

sb, err := m.CreateSandbox(ctx, "worker", m.WithImage("alpine"))
sb, err = m.CreateSandboxDetached(ctx, "worker", m.WithImage("alpine"))
sb, err = m.StartSandbox(ctx, "worker")
sb, err = m.StartSandboxDetached(ctx, "worker")
handle, err := m.GetSandbox(ctx, "worker")
all, err := m.ListSandboxes(ctx)
err = m.RemoveSandbox(ctx, "worker")
metrics, err := m.AllSandboxMetrics(ctx)
```

Common options:

```go
sb, err := m.CreateSandbox(ctx, "worker",
    m.WithImage("python"),
    // Or m.WithSnapshot("after-setup") instead of WithImage.
    m.WithMemory(1024),
    m.WithCPUs(2),
    m.WithWorkdir("/app"),
    m.WithShell("/bin/bash"),
    m.WithHostname("worker"),
    m.WithUser("nobody"),
    m.WithEnv(map[string]string{"DEBUG": "true"}),
    m.WithScripts(map[string]string{"setup": "#!/bin/sh\necho setup"}),
    m.WithReplace(),
    m.WithReplaceWithGrace(10*time.Second),
    m.WithPullPolicy(m.PullPolicyIfMissing),
    m.WithPorts(map[uint16]uint16{8000: 8000}),
    m.WithPortsUDP(map[uint16]uint16{5353: 5353}),
)
```

Use `CreateSandboxDetached` or `WithDetached()` when the sandbox should survive
the Go process.

## Execution

Non-zero exit code is not a Go error. Inspect `Success()` or `ExitCode()`.
Errors are for transport, timeout, or spawn failures.

```go
out, err := sb.Exec(ctx, "python", []string{"-c", "print('hello')"})
if err != nil {
    return err
}
fmt.Println(out.Stdout())
fmt.Println(out.Stderr())
fmt.Println(out.ExitCode())
fmt.Println(out.Success())

out, err = sb.Shell(ctx, "ls -la /app && echo done")
code, err := sb.Attach(ctx, "bash", "-l")
code, err = sb.AttachShell(ctx)
```

### Streaming and stdin

```go
h, err := sb.ShellStream(ctx, "tail -f /var/log/app.log")
if err != nil {
    return err
}
defer h.Close()

for {
    ev, err := h.Recv(ctx)
    if err != nil {
        return err
    }
    switch ev.Kind {
    case m.ExecEventStdout:
        fmt.Print(string(ev.Data))
    case m.ExecEventStderr:
        fmt.Print(string(ev.Data))
    case m.ExecEventExited:
        fmt.Printf("exit %d\n", ev.ExitCode)
    case m.ExecEventDone:
        return nil
    }
}
```

## Filesystem

```go
fs := sb.FS()

err = fs.WriteString(ctx, "/app/message.txt", "hello")
bytes, err := fs.Read(ctx, "/app/message.txt")
text, err := fs.ReadString(ctx, "/app/message.txt")
entries, err := fs.List(ctx, "/app")
stat, err := fs.Stat(ctx, "/app/message.txt")
exists, err := fs.Exists(ctx, "/app/message.txt")
err = fs.Mkdir(ctx, "/app/output")
err = fs.Copy(ctx, "/app/a.txt", "/app/b.txt")
err = fs.Rename(ctx, "/app/old.txt", "/app/new.txt")
err = fs.Remove(ctx, "/app/temp.txt")
err = fs.RemoveDir(ctx, "/app/cache")
err = fs.CopyFromHost(ctx, "./local.txt", "/app/local.txt")
err = fs.CopyToHost(ctx, "/app/result.txt", "./result.txt")
```

## Lifecycle, logs, and metrics

```go
err = sb.Stop(ctx)
err = sb.Kill(ctx)
err = sb.Drain(ctx)
status, err := sb.Wait(ctx)
status, err = sb.StopAndWait(ctx)
err = sb.Close()

metrics, err := sb.Metrics(ctx)
entries, err := sb.Logs(ctx, m.LogOptions{Tail: 100})
```

## Volumes and mounts

```go
vol, err := m.CreateVolume(ctx, "my-data",
    m.WithVolumeQuota(5120),
    m.WithVolumeLabels(map[string]string{"env": "dev"}),
)
handle, err := m.GetVolume(ctx, "my-data")
allVolumes, err := m.ListVolumes(ctx)
err = m.RemoveVolume(ctx, "my-data")
```

Mount volumes during sandbox creation:

```go
sb, err := m.CreateSandbox(ctx, "worker",
    m.WithImage("alpine"),
    m.WithMounts(map[string]m.MountConfig{
        "/host":    m.Mount.Bind("./src", m.MountOptions{Readonly: true}),
        "/data":    m.Mount.Named("my-data", m.MountOptions{}),
        "/scratch": m.Mount.Tmpfs(m.TmpfsOptions{SizeMiB: 128}),
        "/disk":    m.Mount.Disk("./data.qcow2", m.DiskOptions{Fstype: "ext4", Readonly: true}),
    }),
)
```

## Networking and secrets

```go
sb, err := m.CreateSandbox(ctx, "agent",
    m.WithImage("python"),
    m.WithNetwork(m.NetworkPolicy.PublicOnly()),
    m.WithSecrets(m.Secret.Env(
        "OPENAI_API_KEY",
        apiKey,
        m.SecretEnvOptions{AllowHosts: []string{"api.openai.com"}},
    )),
)

trustHostCAs := true
maxConnections := uint(50)

custom := &m.NetworkConfig{
    DefaultEgress:  m.PolicyActionDeny,
    DefaultIngress: m.PolicyActionAllow,
    Rules: []m.PolicyRule{
        {
            Action:      m.PolicyActionAllow,
            Direction:   m.PolicyDirectionEgress,
            Destination: "api.openai.com",
            Protocol:    m.PolicyProtocolTCP,
            Port:        "443",
        },
    },
    DenyDomains:        []string{"ads.example.com"},
    DenyDomainSuffixes: []string{".tracking.com"},
    MaxConnections:     &maxConnections,
    TrustHostCAs:       &trustHostCAs,
}
```

## Snapshots

```go
handle, err := m.GetSandbox(ctx, "baseline")
snap, err := handle.Snapshot(ctx, "after-setup")
snap2, err := handle.SnapshotTo(ctx, "/tmp/snaps/after-setup")

worker, err := m.CreateSandbox(ctx, "worker", m.WithSnapshot("after-setup"))

allSnaps, err := m.Snapshot.List(ctx)
snapHandle, err := m.Snapshot.Get(ctx, "after-setup")
err = m.Snapshot.Remove(ctx, "after-setup", false)
_, err = m.Snapshot.Reindex(ctx, "~/.microsandbox/snapshots")
```
