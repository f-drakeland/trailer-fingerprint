# TFS — current project status

Updated: 2026-10-02.

Working name: Trailer Fingerprint Software (TFS). Original code and documentation
use the [MIT license](../LICENSE); third-party material has separate terms.

## Current milestone

**v0.12 — Authentic Data Ingestion**

TFS can now inspect authentic external J1708 logger data through the same
record-audit and protocol-ingest boundary used by the public tooling. Authentic
research captures remain private and are not distributed with the repository.

## Objective and boundaries

Persistent physical-equipment identity supported by multiple component anchors
and history, including maintenance continuity. A controller can be replaced or
migrate between units. Shared history/component migration is a design model, not
an implemented network service. The local fixture matcher does not settle those
research questions.

The host baseline uses Zig 0.17.0. Input starts after J2497 demodulation.
Native `.tfc` fixtures are checksum-stripped; external logger checksum conventions
must be established per source. No live diagnostic requests, waveform decoding, or
native J1939 ingestion are implemented.

## Current implementation

- Native .tfc replay and external J1708 logger text.
- External record audit separates source MIDs from directed request targets.
  Counts PID 128/384 requests, retains bounded PID 254 frames as opaque evidence
  with explicit overflow accounting, and quarantines unsupported input.
- Single-parameter inspection only; combined/unsupported formats do not enter
  identity ingest. A malformed supported identity payload still fails closed.
- PID 192 multisection reassembly; PID 243 component identity; PID 234 software
  metadata; optional PID 237 VIN; PID 245 as telemetry only.
- The capture CLI reports component observations without assigning equipment
  identity. The separate synthetic demo uses fictional historical profiles.
- Retained identity text is owned by the ingest result; reassembly slot reuse
  and capture-buffer lifetimes cannot overwrite it.
- SocketCAN input is explicitly rejected. The archived CAN investigation was a
  separate analysis, not functionality claimed by this executable.

## Research evidence

Capture provenance, hashes and analysis details are recorded in
[RESEARCH_CORPUS.md](RESEARCH_CORPUS.md).

- J1708: 625 records; 119 requests addressed to MID 137; zero source-MID-137
  records; no PID 254 or standard identity payloads recovered.
- CAN: 539,992 frames; 296 reassembled transport payloads in the separate analysis;
  no standard VIN/component/software identification messages recovered.
- Both are useful provenance-qualified background/negative research inputs. Neither
  is a positive trailer identity example or proof of capture topology.

## Validation

- Zig 0.17.0 `zig build test`: protocol/fingerprint, synthetic and diagnostic suites pass.
- Default replay: synthetic fixtures and permitted public examples only.
- Full private J1708 replay (`nov4thhardstop.j1708log`): 625 records; 592
  directed requests; 119 requests addressed to MID 137; zero MID 137 source
  records; 27 quarantined records; six unsupported operational records; zero
  supported identity or telemetry frames; no component IDs were decoded;
  physical-equipment identity not established.
- Full CAN file: expected `UnsupportedTransport`, not a fingerprint result.

## Evidence gaps

A positive MID 137/PID 254 fixture requires the diagnostic exchange demonstrated
in Figure 8, the logger/checksum convention and hardware context.
Validate a vendor decoder against observed bytes and an independently confirmed
controller serial before declaring a positive identity fixture. Multi-parameter
J1587 parsing, larger identity buffers, J1939 ingest and capture-grounded topology
remain future work, not silently assumed capabilities.

## First release completion criteria

The first release is a local capture inspector for component identity evidence.
It is complete when:

- Supported inputs produce reproducible observations and explicit unsupported or
  malformed-input outcomes, with request destinations kept separate from sources.
- At least one shareable authentic identity-bearing capture has a documented
  logger/checksum convention and an independently confirmed component identifier;
  a regression fixture verifies the decoding. **This evidence is still missing.**
- Tests and default replays pass, retained identity data survives buffer reuse,
  and contributor documentation describes supported layouts and limits.

Positive vendor decoding remains gated on that evidence. Physical-equipment
continuity, live adapters, shared history, parts catalogs and electrical diagnostics
are outside this release. No new protocol family is required to finish it.
