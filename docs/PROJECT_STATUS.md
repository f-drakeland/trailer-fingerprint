# Trailer Fingerprint — current project status

Updated: 2026-09-23.

## Objective and boundaries

Persistent physical-equipment identity supported by multiple component anchors
and history, including maintenance continuity. A controller can be replaced or
migrate between units. Shared history/component migration is a design model, not
an implemented network service. The local fixture matcher does not settle those
research questions.

The host baseline uses Zig 0.16.0. Input starts after J2497 demodulation and assumes
removed J1708 checksums. No live diagnostic requests, waveform decoding, or native
J1939 ingestion are implemented.

## Current implementation

- Native .tfc replay and external J1708 logger text.
- External record audit separates source MIDs from directed request targets.
  Counts PID 128/384 requests, opaque PID 254 records and quarantined input.
- Single-parameter inspection only; combined/unsupported formats do not enter
  identity ingest. A malformed supported identity payload still fails closed.
- PID 192 multisection reassembly; PID 243 component identity; PID 234 software
  metadata; optional PID 237 VIN; PID 245 as telemetry only.
- Fingerprinting uses synthetic historical profiles. Requests and operational
  telemetry alone yield insufficient identity evidence.
- SocketCAN input is explicitly rejected. The archived CAN investigation was a
  separate analysis, not functionality claimed by this executable.

## Research evidence

Capture provenance, hashes and analysis details are recorded in
[RESEARCH_CORPUS.md](RESEARCH_CORPUS.md).

- J1708: 625 records; 119 requests addressed to MID 137; zero source-MID-137
  records; no PID 254 or standard identity payloads recovered.
- CAN: 539,992 frames; 296 reassembled transport payloads in the separate analysis;
  no standard VIN/component/software identification messages recovered.
- Both are useful provenance-qualified background/negative fixtures. Neither is
  a positive trailer identity fixture or proof of capture topology.

## Validation

- `zig build test`: protocol/fingerprint, synthetic and diagnostic suites pass.
- Default replay: existing synthetic/public examples plus the authentic excerpt.
- Full local J1708 replay: 625 records; 592 requests; 119 MID 137 targets;
  27 quarantined records; six unsupported operational records; no modules/VIN;
  insufficient identity evidence.
- Full CAN file: expected `UnsupportedTransport`, not a fingerprint result.

## Evidence gaps

A positive MID 137/PID 254 fixture requires the diagnostic exchange demonstrated
in Figure 8, the logger/checksum convention and hardware context.
Validate a vendor decoder against observed bytes and an independently confirmed
controller serial before declaring a positive identity fixture. Multi-parameter
J1587 parsing, larger identity buffers, J1939 ingest and capture-grounded topology
remain future work, not silently assumed capabilities.
