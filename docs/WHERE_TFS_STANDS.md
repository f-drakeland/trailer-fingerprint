# Where does the research stand today?

TFS is currently at the **v0.12 — Authentic Data Ingestion** milestone.

The software can inspect authentic external J1708 logger text through the same record-audit and protocol-ingest boundary used by the project tooling.

But the central research question is not finished.

## What TFS has already demonstrated

TFS can currently:

- load native replay fixtures and supported external J1708 text formats;
- keep request destinations separate from source MIDs;
- reassemble supported PID 192 multisection parameters;
- decode supported PID 234 software metadata;
- decode supported PID 243 component identity;
- retain an optional supported PID 237 VIN;
- keep PID 245 distance as telemetry instead of identity;
- preserve PID 254 frames as opaque vendor evidence;
- reject or quarantine unsupported input instead of manufacturing an identity.

## What authentic research data has shown so far

One private J1708 research capture contains:

- 625 records;
- 592 directed requests;
- 119 requests addressed to MID 137;
- zero MID 137 source records;
- zero supported component-identity observations.

That is useful negative evidence.

It is **not** a positive trailer-identity example.

A separate CAN investigation also did not recover a supported identity result and is not functionality claimed by the current TFS executable.

## The evidence TFS still needs

The first release remains blocked on one specific thing:

> **At least one shareable, authentic identity-bearing capture with a documented logger/checksum convention and an independently confirmed component identifier.**

For vendor-specific decoding, TFS also needs observed bytes tied to an independently confirmed value before assigning semantics.

That is the current priority.

## What would be an especially useful contribution?

A small, sanitized capture can be more valuable than a huge log.

The ideal contribution would include:

1. a short raw J1708/J1587 capture from a real trailer-controller diagnostic session;
2. the logger/interface used;
3. whether exported bytes include or omit the J1708 checksum;
4. one component identifier independently shown by the diagnostic tool or physical controller;
5. permission to publish the relevant sanitized packet excerpt.

Customer names, fleet numbers, VINs, and proprietary software are not required.

## Curious outsiders are welcome

You do not need to be a diesel technician to contribute.

Useful help can also include:

- checking documentation for clarity;
- reviewing parser behavior;
- finding public protocol examples;
- testing TFS with permitted data;
- improving diagrams;
- challenging an assumption that looks too confident.

The project benefits from people who ask:

> **"How do you know that?"**

That question is part of the engineering process.

---

If you arrived here knowing nothing about trailer networking and now understand why one byte string can be interesting — and why it still does not magically identify a trailer — this guide did its job.

For the contributor-facing protocol boundary, continue with [PROTOCOL_REPLAY.md](PROTOCOL_REPLAY.md).

For the current milestone and evidence gaps, see [PROJECT_STATUS.md](PROJECT_STATUS.md).
