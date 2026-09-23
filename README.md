# Trailer Fingerprint

Trailer Fingerprint is an experimental open system for persistent identity and
shared histories of heavy-duty towed equipment: heavy-duty commercial semitrailers,
converter dollies, doubles, and related towed equipment. The goal is evidence-based equipment
history, not fleet-specific tracking.

The intended network model allows participating devices to contribute observations
to shared equipment history, so later encounters can benefit from evidence collected
by other participants. Equipment identity and component identity are separate: controllers can be
replaced or migrate between units, while continuity of the physical equipment must
be supported by the available evidence. VIN is useful but optional.

Shared history does not require publicly exposing raw serial numbers, VINs, precise
locations, or driver or tractor information. Privacy boundaries are part of the
design, including possible opaque public equipment and component IDs.

This remains a research-stage project. The existing v0.11 code is a local
protocol/fingerprint research baseline on Zig 0.16.0, not a completed network
implementation. It starts after J2497/PLC waveform demodulation; sufficient
real-world identity-bearing captures remain the main research bottleneck. Synthetic
fixtures exercise engineering behavior, not field-validated identification.

See [the shared network model](docs/NETWORK_MODEL.md) for the design principles,
evidence limits, and privacy boundaries. The version notes below preserve the
technical development history.

---

# Trailer Fingerprint v0.11

## v0.11: public protocol sample + telemetry/identity separation

This version adds one deliberately small piece of public, non-synthetic protocol data: the `pretty_j1587` README example for MID 137 / PID 245 (Total Vehicle Distance). The external-log loader can now ingest `pretty_j1587` output lines shaped like:

```text
MSG: [0x89,0xf5,0x4,0xe1,0x0,0x0,0x0]
```

PID 245 is decoded and retained as **telemetry history**, but it is explicitly **not** an equipment identity anchor. That distinction matters because mileage changes over time and may move/reset with controller replacement. A capture containing only telemetry now reports `INSUFFICIENT IDENTITY EVIDENCE` instead of pretending it discovered a new physical trailer.

The default corpus now includes `captures/public_pretty_j1587_sample.log`, sourced from the public MIT-licensed `ainfosec/pretty_j1587` README example.

Run:

```sh
zig build test
zig build run
```

---

# Trailer Fingerprint v0.10.3

## v0.10.3 fix

Two new multiline-string test fixtures in `external_log_loader.zig` were emitted with a single leading backslash instead of Zig's required `\\` multiline string marker. The parser logic was not at fault. The fixtures now compile, and the 20-byte / 21-byte boundary tests remain intact.

## v0.10.2 fix

The external-log VIN replay fixture still contained 21 checksum-stripped bytes even though the native `.tfc` fixture had already been corrected to the 20-byte J1708 boundary. The Truck Duck-style fixture and both in-memory external-log tests now use the same 17-character VIN payload as the validated `.tfc` capture. Regression coverage also checks compact 20-byte acceptance and 21-byte rejection in the external-log parser.

## v0.10.1 fix

Zig 0.16 removed `std.mem.trimLeft`. The external-log adapter now uses a tiny local left-trim helper instead, avoiding dependence on that removed stdlib API. No parsing behavior was intentionally changed.


## v0.10: common external log ingestion

The fingerprint pipeline can now ingest either Trailer Fingerprint `.tfc` interchange files or text logs shaped like common J1708 tooling output. Supported examples include comma-delimited logger lines and Truck Duck-style lines such as:

```text
(123123123.123123) j1708 89EA0653572D322E31 ; optional comment
```

This is intentionally an adapter at the **J1708/J1587 message boundary**. It does not claim to demodulate J2497 waveforms. External logs do not automatically identify trailer class or physical consist position; those remain `unknown` unless another source provides them.

The included `captures/current_trailer_truckduck.log` is still synthetic. Its purpose is to prove that an external-tool text log can reach the same fingerprint engine without being manually rewritten into Trailer Fingerprint's native capture format.

**Trailer Fingerprint remains a codename.**

## v0.9.1 fix

Two in-memory VIN fixtures accidentally contained 21 checksum-stripped bytes even though the capture boundary correctly allows at most 20. The parser was right to reject them. The fixtures and README example now use a 17-byte VIN payload, and regression tests cover both the 20-byte legal maximum and a 21-byte rejection.

v0.9.1 keeps the v0.9 capture-file architecture and fixes the checksum-stripped frame-length fixtures.

v0.9 was the first version whose default fingerprint path reads protocol frames
from files rather than compiling the replay corpus directly into Zig source.

That sounds small, but it creates the seam we need for real-world research:

```text
future PLC receiver / diagnostic adapter / capture converter
                       |
                       v
                 .tfc capture file
                       |
                       v
            J1708/J1587 validation
                       |
                       v
             PID 192 reassembly
                       |
                       v
          PID 243 / 234 / 237 ingest
                       |
                       v
                 fingerprinting
```

The `.tfc` format is deliberately tiny and human-readable. It is **not** being
claimed as a standard or a vendor capture format. It is simply Trailer Fingerprint's
current replay interchange format.

## Run

```sh
zig build test
zig build run
```

With no arguments, `zig build run` processes all three included captures.

To run one or more files explicitly:

```sh
zig build run -- captures/current_trailer.tfc
zig build run -- captures/current_trailer_no_vin.tfc captures/fleet_twin.tfc
```

Earlier work remains available:

```sh
zig build synthetic
zig build diagnostics
```

## Capture file format

Example:

```text
# Trailer Fingerprint capture v1
@name current trailer
@class semitrailer
@position single

89 EA 06 53 57 2D 32 2E 31
89 ED 11 31 44 45 4D 4F 30 30 30 30 30 30 30 30 30 30 30 31
```

Each non-directive line is one checksum-stripped J1708/J1587 frame expressed
as hexadecimal bytes. The current boundary still begins **after J2497/PLC
waveform demodulation and J1708 checksum handling**.

Supported metadata:

- `@name`
- `@class semitrailer | converter_dolly | unknown`
- `@position lead | dolly | rear | single | unknown`

The loader rejects malformed hex, frames over the 20-byte checksum-stripped
J1708 boundary, and invalid metadata before the fingerprint engine sees them.

## Why this version matters

Up through v0.8.1, a new replay required editing Zig source and recompiling.
v0.9 lets us preserve protocol observations as data.

When real trailer traffic becomes available, our first task will be to write a
small converter from whatever the capture tool produces into `.tfc`. The
fingerprint pipeline can then consume the observation unchanged.

This is still not a J2497 demodulator and it does not yet issue live PID
requests. Those remain separate future layers.
