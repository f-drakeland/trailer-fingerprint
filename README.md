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

See [current project status](docs/PROJECT_STATUS.md) and the
[research capture record](docs/RESEARCH_CORPUS.md) for the latest evidence and
validation. See [the shared network model](docs/NETWORK_MODEL.md) for the design principles,
evidence limits, and privacy boundaries. The version notes below preserve the
technical development history.

## Start here / Help wanted

Trailer Fingerprint explores whether observations of replaceable electronic
components can support persistent trailer identity. The current deliverable is a
local Zig parser and fingerprint prototype; real identity-bearing captures are
the main missing evidence.

Use **Zig 0.16.0**. Run `zig build test`, then `zig build run` from the repository
root. The included fixtures work without hardware or private captures.

The most useful contributions are:

- **Protocol review:** challenge request/source handling, framing assumptions or
  identity decoding with a small reproducer and a protocol reference.
- **Capture knowledge:** help identify logger/checksum conventions or provide
  shareable J1708/J2497 diagnostic exchanges, especially MID 137 / PID 254.
- **Focused Zig fixes:** improve parsing or evidence handling with a regression
  test. Keep unrelated refactors and new dependencies out of the same change.

For a bug or research observation, open an issue with expected versus observed
behavior and the smallest useful example. For a capture, include its origin,
logger/adapter, equipment context, checksum handling and whether diagnostics were
actively requested; mark unknown details explicitly. Share only data you have
permission to share, with sensitive identifiers redacted and redactions documented.
A decoder claim needs observed bytes and independent identity confirmation.

Before a larger feature, describe the gap it addresses in an issue. For a code
change, run the tests and relevant replay, and update affected documentation.
Preserve uncertainty: a request is not a response, and a controller serial alone
is not permanent trailer identity.

**Find the details:** [status and limits](docs/PROJECT_STATUS.md) ·
[capture evidence and provenance](docs/RESEARCH_CORPUS.md) ·
[identity design](docs/NETWORK_MODEL.md).
Parser work starts in [capture_audit.zig](src/capture_audit.zig) and
[j1587.zig](src/j1587.zig); matching lives in [fingerprint.zig](src/fingerprint.zig).

## Researcher-capture inspection

External logs now pass through a conservative record audit before identity ingest.
PID 128 and extended PID 384 requests retain distinct source and destination
counts. Short, malformed, and ambiguous records are counted separately. PID 254
escape payloads remain opaque; their bytes are not interpreted as identities.
The variable-length decoder now explicitly accepts only page-one PIDs 192–253.

The default corpus includes a documented 20-record excerpt from the researcher-
supplied `nov4thhardstop.j1708log`. It reports **MID 137 queried; no response
observed**, then **INSUFFICIENT IDENTITY EVIDENCE**. Requests do not establish that
the addressed controller is present. The excerpt has three MID 137 requests;
the full original has 119. Neither contains confirmed identity responses.

```sh
zig build test
zig build run
# Local originals, when available (not tracked):
zig build run -- captures/private/nov4thhardstop.j1708log
```

SocketCAN/candump input is explicitly rejected as `UnsupportedTransport`; the
current Zig pipeline does not decode J1939. The separate CAN analysis is recorded
in [RESEARCH_CORPUS.md](docs/RESEARCH_CORPUS.md). Checksums are assumed removed,
not validated. Full researcher originals remain in ignored `captures/private/`.
Single-parameter inspection is intentionally bounded: combined parameters and
unsupported page-two records do not become identity evidence. External files are
limited to 32 MiB and at most 128 supported identity/telemetry frames; background
requests do not consume that frame buffer. Native `.tfc` parsing remains strict.

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

The capture-file boundary separates protocol input from fingerprinting:

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

With no arguments, `zig build run` processes six included captures/excerpts.

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

Unsupported capture formats require an adapter to the existing J1708/J1587
input boundary. Supported external logs can be inspected directly.

This is still not a J2497 demodulator and it does not yet issue live PID
requests. Those remain separate future layers.
