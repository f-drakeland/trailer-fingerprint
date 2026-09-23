# Replay / discovery pipeline

The equipment fingerprint engine should never depend directly on a specific diagnostic adapter or bus protocol.

The preserved v0.6 synthetic pipeline is:

```text
synthetic discovered modules
        ↓
normalizer.zig
        ↓
EquipmentSnapshot
        ↓
fingerprint.zig
```

A future implementation can substitute:

```text
J2497/J1708 decoder
        ↓
DiscoveredUnit / DiscoveredModule
```

or:

```text
recorded capture reader
        ↓
DiscoveredUnit / DiscoveredModule
```

without rewriting the continuity logic.

## Current file path (2026-09-23)

```text
external J1708 log -> record audit -> supported identity/telemetry frames
native .tfc ------> strict frame loader -> protocol ingest
protocol ingest -> PID 192 reassembly / enrichment -> normalizer -> fingerprint
```

The audit counts directed requests separately from observed sources. Unknown,
short and unsupported records do not create identities. Native captures retain
strict validation. SocketCAN input is rejected until a J1939 adapter exists.
See [PROJECT_STATUS.md](PROJECT_STATUS.md) for current limits and
[RESEARCH_CORPUS.md](RESEARCH_CORPUS.md) for authentic negative fixtures.

## Why endpoint is not identity

A module may be observed at a bus address, MID, source address, or adapter-specific endpoint. Those values can be useful evidence while debugging discovery, but they are not assumed to be permanent identifiers of the physical trailer.

The identity engine currently trusts durable module attributes such as manufacturer/model/serial relationships more than transport-layer addressing.
