# Protocol realism added in v0.8

Historical version notes. For the current implementation, evidence and limitations,
see [PROJECT_STATUS.md](PROJECT_STATUS.md) and [RESEARCH_CORPUS.md](RESEARCH_CORPUS.md).


v0.7 used the correct PID 243 field shape but encoded long component identities
as one oversized replay message. That was useful for the fingerprint boundary,
but it was not a valid representation of a J1708 packet when the payload grew
past the link's message limit.

v0.8 fixes that.

## PID 192 multisection

Long identity parameters are now split into J1587 PID 192 sections. The
reassembler:

- tracks source MID and target PID,
- checks section order,
- checks the advertised original byte count,
- supports interleaved transfers from different source MIDs,
- emits the original parameter only after every section arrives.

The replay intentionally interleaves an ABS PID 243 transfer and a TPMS PID 243
transfer to exercise that behavior.

## Endpoint enrichment

The ingest layer now understands three identity observations:

- PID 243 Component Identification -> module make/model/serial anchor
- PID 234 Software Identification -> metadata attached to that module endpoint
- PID 237 VIN -> optional unit-level identity evidence

The fingerprint engine still does not require a VIN. The default demo runs the
same physical-trailer observation both with and without VIN data.

## Still outside the boundary

This project still does **not**:

- demodulate a J2497 waveform,
- validate a J1708 checksum,
- send diagnostic parameter requests,
- claim every trailer exposes these PIDs,
- determine physical position in a doubles consist from PLC traffic.

Those remain research/validation boundaries rather than invented features.
