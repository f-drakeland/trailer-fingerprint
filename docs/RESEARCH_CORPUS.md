# Research capture record

Inspected: 2026-09-23. Source: researcher-supplied captures associated with the
cited trailer-identification study. Capture setup, trailer count and J2497 conversion hardware remain unverified.

## Permissions

Researcher-supplied captures are retained locally for inspection and are not
covered by the project's MIT grant. Receipt and attribution alone do not establish
redistribution or relicensing permission; no such permission is documented here.
No bytes from those captures are intentionally included in public fixtures or
regression tests. Public tests use independently constructed synthetic input.
The public `pretty_j1587` example retains its upstream MIT terms and source
attribution.

## Originals and reproducibility

Full originals are copied byte-for-byte into ignored `captures/private/`. They are
not required for the regular test suite or default demo. No originals were edited.

| File | Bytes | SHA-256 |
|---|---:|---|
| nov4thhardstop.j1708log | 18,466 | `1b3e07fc50d3abcb5f72040e6161215b2dfc0972d80893a07f97e108a78ae45d` |
| candump-2021-03-21_214110.log | 27,537,282 | `d393ff67e4958a74b41c09e892467ae0e5e498aefff171181b4e0c3d3e7d5b02` |

## J1708 result

625 records over 1213.411337 seconds, with 20 distinct payloads. Protocol
interpretation identifies 592 directed requests from MID 136: 395 for PID 245,
99 for PID 194 and 98 for PID 409 (via extended PID 384). Targets include MIDs
137, 138, 139, 246 and 247.

MID 137 is addressed 119 times (80 PID 245, 19 PID 194, 20 PID 409), but never
appears as a source. The capture contains directed requests from MID 136 to MID 137 for PID 245.
Those destination bytes do not constitute a response from MID 137.

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

## End-to-end TFS validation

On 2026-09-27, the private original `nov4thhardstop.j1708log` was processed
end-to-end through the TFS capture CLI. The run audited 625 records, including
592 directed requests and 119 requests addressed to MID 137, while observing zero
MID 137 source records and zero supported identity/telemetry frames.

No component IDs were decoded, and physical-equipment identity was not established.

## Public tests

Researcher-supplied captures remain local under ignored `captures/private/` and
are not required by the public test suite or default demo.

Public regression tests use independently constructed synthetic inputs to exercise
request/source separation, transport rejection, fixed versus variable parameter
framing, opaque escape payloads, malformed records followed by valid data, more
than 128 background records, and insufficient-identity behavior.

Results reported above were derived from local inspection of the original captures;
they do not imply redistribution permission for the underlying data.

## References

- [SAE J1587 FEB2002](https://cdn.hackaday.io/files/18651797964384/SAE%20J1587%20%282002%20Standard%29.pdf): A.128, A.192, A.254, A.384.
- [J1939 transport overview](https://www.csselectronics.com/pages/j1939-explained-simple-intro-tutorial).
- [Identity PGNs](https://support.enovationcontrols.com/hc/en-us/articles/360039804114-Example-J1939-ASCII-Engine-Information-PGN-65242-65259).
