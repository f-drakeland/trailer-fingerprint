# Research capture record

Inspected: 2026-09-23. Source: captures supplied by Sean via Dr. Jeremy Daily
in support of the trailer-identification paper. Capture setup, trailer count,
replay status and J2497 conversion hardware remain unverified.

## Originals and reproducibility

Full originals are copied byte-for-byte into ignored `captures/private/`. They are
not required for the regular test suite or default demo. No originals were edited.

| File | Bytes | SHA-256 |
|---|---:|---|
| nov4thhardstop.j1708log | 18,466 | `1b3e07fc50d3abcb5f72040e6161215b2dfc0972d80893a07f97e108a78ae45d` |
| candump-2021-03-21_214110.log | 27,537,282 | `d393ff67e4958a74b41c09e892467ae0e5e498aefff171181b4e0c3d3e7d5b02` |

## J1708 result

625 records over 1213.411337 seconds, with 20 distinct payloads. The checksum-
stripped interpretation gives 592 MID 136 requests: 395 for PID 245, 99 for
PID 194 and 98 for PID 409 (via extended PID 384). Targets include MIDs 137,
138, 139, 246 and 247.

MID 137 is addressed 119 times (80 PID 245, 19 PID 194, 20 PID 409), but never
appears as a source. `88 80 F5 89` means MID 136 requests PID 245 from MID 137;
the final 89 is not a responding MID or checksum.

Six apparent MID 139 operational messages carry PID 49 (five) and PID 84 (one).
There are 27 short/non-J1587-source records retained as quarantined input. Their
meaning is unresolved; the audit does not label them proven corruption.

No PID 192, 234, 237, 243 or 254 bytes occur in the original payloads. No serial,
VIN, component ID or software ID was recovered. No frame byte sum is zero modulo
256; regular request lengths suggest logger-stripped checksums, pending format
confirmation. Do not discard the last byte as a checksum.

## CAN result — separate offline analysis

539,992 can1 frames over 539.953890 seconds; 97 J1939 PGNs and 30 source-address
values. All 296 announced transport payloads were reassembled: targets 65251
(129), 65249 (108), 64920 (58) and 65226 (one). Payload completeness does not prove
successful transactions; 58 abort control frames also occur.

No direct or transported software ID PGN 65242, component ID PGN 65259, VIN PGN
65260, or direct address-claim PGN 60928 was found. There are 44,741 proprietary-B
frames, but no verified serial decoding. Proprietary CAN bytes are not J1587 PID
254 traffic. CAN source addresses are not J1587 MIDs. No confirmed J1708/J2497
tunnel was identified.

The paper's contextual serial 3026601464 was not found as ASCII or four-byte
little-/big-endian data within individual CAN payloads. This does not exclude
every proprietary encoding. Neither capture reproduces the paper's identity
exchange; both remain useful background and negative identity examples.

## Tracked excerpts and tests

`src/fixtures/nov4thhardstop-excerpt.j1708log` preserves the first occurrence of
each distinct payload, in original order, from original lines:
1, 2, 3, 4, 5, 6, 7, 8, 10, 14, 16, 20, 21, 23, 27, 29, 558, 560, 604, 618.
Timestamps and payload text are retained. This intentionally loses frequency and
must not be used for timing/frequency claims: 20 records, 15 requests, three
MID 137 targets, two MID 139 operational records, three quarantined records.
It yields no identity/telemetry frames for the fingerprint ingest layer.

`src/fixtures/candump-excerpt.log` contains the original first three CAN records.
It tests explicit transport rejection, not J1939 decoding.

Regression tests cover request/source separation, fixed versus variable parameter
framing, opaque escape payloads, malformed records followed by valid data, more
than 128 background records, and the full negative-identity pipeline.

## References

- [SAE J1587 FEB2002](https://cdn.hackaday.io/files/18651797964384/SAE%20J1587%20%282002%20Standard%29.pdf): A.128, A.192, A.254, A.384.
- [J1939 transport overview](https://www.csselectronics.com/pages/j1939-explained-simple-intro-tutorial).
- [Identity PGNs](https://support.enovationcontrols.com/hc/en-us/articles/360039804114-Example-J1939-ASCII-Engine-Information-PGN-65242-65259).
