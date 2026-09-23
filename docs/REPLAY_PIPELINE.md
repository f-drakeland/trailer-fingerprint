# Replay / discovery pipeline

The equipment fingerprint engine should never depend directly on a specific diagnostic adapter or bus protocol.

The current v0.6 pipeline is:

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

## Why endpoint is not identity

A module may be observed at a bus address, MID, source address, or adapter-specific endpoint. Those values can be useful evidence while debugging discovery, but they are not assumed to be permanent identifiers of the physical trailer.

The identity engine currently trusts durable module attributes such as manufacturer/model/serial relationships more than transport-layer addressing.
