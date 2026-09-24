# Replay / discovery pipeline

```text
external J1708 log -> record audit -> supported frames
native .tfc ------> strict frame loader
supported frames -> PID 192 reassembly / parameter decoding
                 -> owned component observations -> CLI report
```

The audit separates request destinations from observed sources. Unsupported or
quarantined records do not create identities. Malformed supported identity
payloads fail ingestion. SocketCAN is rejected.

## Ownership

`ingestUnit(allocator, ...)` copies retained identity text and the observation name
into an owned arena. The caller must `deinit()` the result once. Do not copy an
owning result and deinitialize both copies. Discovery and distance views borrow
the result and must not outlive it; normalization also borrows identity strings.

A completed `Bank.push()` parameter borrows reassembly storage only until the
next push or bank destruction. Ingest copies its identity fields before either
can occur. Tests cover sequential slot reuse, capture mutation and error cleanup.

## Separate experiment

`zig build synthetic` passes fictional discovery records through `normalizer.zig`
and `fingerprint.zig`. The capture CLI does not compare input with those profiles.
The matcher is an experiment in continuity rules, not verified equipment identity.
See [scope and limits](PROJECT_STATUS.md) and [domain guide](PROTOCOL_REPLAY.md).
