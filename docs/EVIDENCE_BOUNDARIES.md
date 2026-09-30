# What does TFS do when it doesn't know?

A useful identity system has to be able to say **no** and **not yet**.

TFS uses evidence boundaries to keep uncertainty visible.

## Supported

When the framing and parameter layout are established and TFS has a supported decoder, the observation can enter the normal ingest path.

Examples include supported PID 234, 237, 243, and 245 records.

## Preserved but opaque

Some bytes are worth keeping even when TFS does not know their meaning.

PID 254 vendor-specific traffic is the clearest example.

TFS retains bounded copies of those raw frames and counts overflow explicitly, but does not assign vendor semantics without evidence.

## Quarantined

Malformed, ambiguous, or unsupported records do not silently become identities.

The capture audit can quarantine records rather than force them through a decoder.

## Explicitly unsupported

TFS currently rejects SocketCAN input at this boundary.

Native J1939/CAN ingestion is not implemented.

J2497 waveform demodulation is also outside the current TFS input boundary.

## A request is not a response

TFS records request destinations separately from observed sources.

A request addressed to MID 137 does not mean MID 137 answered.

This distinction already mattered in authentic research data: TFS observed many requests addressed to MID 137 without observing any source-MID-137 record in that capture.

## Synthetic is not authentic

TFS uses synthetic fixtures to test behavior.

Those fixtures prove that the software behaves as intended.

They do **not** prove that a real trailer exposes the same information in the same way.

That proof requires authentic data.

> **Evidence rule:** Preserve what was observed. Label what was simulated. Do not promote either beyond what it supports.

**Next:** [Where does the research stand today?](WHERE_TFS_STANDS.md)
