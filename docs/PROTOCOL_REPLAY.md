# Protocol Replay Boundary (v0.7)

v0.7 is the first Trailer Fingerprint prototype that accepts **protocol-shaped identity bytes** instead of pre-normalized module records.

It intentionally starts *after* the J2497 physical layer. Open-source J2497 tooling documents that a decoded PLC message body typically contains a J1708 message. Trailer Fingerprint therefore treats the future transport path as:

```
J560 power line
    -> J2497/PLC demodulator
    -> J1708/J1587 bytes
    -> Trailer Fingerprint J1587 ingest
    -> discovery model
    -> normalizer
    -> fingerprint engine
```

## What v0.7 decodes

Only **J1587 PID 243, Component Identification**.

The decoder extracts:

- source MID
- component MID
- component make
- component model
- component serial number

The replay identities are deliberately fictional (`DEMO`, `ABS-4S2M`, etc.), but the byte layout follows the PID 243 identity structure rather than an invented Trailer Fingerprint-only format.

A small MID mapping is used only to classify identity anchors:

- 137-139: trailer brake modules -> ABS
- 147-149: trailer cargo refrigeration/heating -> reefer controller
- 167-169: trailer tire systems -> TPMS/tire controller
- everything else: `other`

## What v0.7 does NOT prove

- It does not demodulate J2497 waveforms.
- It does not generate active PID requests.
- It does not validate a J1708 checksum.
- It does not prove every real trailer responds to PID 243.
- It does not infer trailer/dolly/rear physical topology from MIDs.
- It does not yet merge PID 234 software ID or PID 237 VIN into an anchor.
- Its sample bytes are synthetic protocol fixtures, not captures from real equipment.

## Why this is useful

The fingerprint engine is no longer coupled to hand-authored `ModuleIdentity` structures. A future PLC adapter only has to deliver J1708/J1587 payloads to this boundary; the rest of the identity pipeline can remain unchanged.
