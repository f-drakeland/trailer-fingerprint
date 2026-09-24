# Protocol and domain guide

Read this before changing a decoder. This is a map of TFS's supported subset,
not a replacement for SAE standards or a complete identifier dictionary.

## From wire to observation

| Layer / term | Meaning in this project | Boundary |
| --- | --- | --- |
| J2497 / PLC | Communication over the vehicle power line | Demodulation happens outside TFS |
| J1708 | Message transport carrying a source MID and data | Input assumes checksums already removed |
| J1587 | Meanings and layouts of parameters in those messages | TFS decodes a limited subset |
| MID | Message identifier used to distinguish transmitting systems | A role/address is not a unique serial |
| PID | Parameter identifier selecting a data layout | Interpretation depends on framing and context |
| J1939 / CAN | Separate protocol family with different addressing and parameter groups | Native CAN ingestion is not implemented |
| Component identity | Reported make, model and serial of an electronic module | Does not establish which physical trailer owns it |
| Equipment identity | Continuity of a physical trailer or dolly over time | Still an experimental research goal |

The standards define the protocol; project development changes how much TFS
supports. Vendor-specific data needs its own verified interpretation. A serial
number is not automatically an orderable part number or proof of fitment.

## Identifiers used by the code

| Identifier (decimal) | TFS treatment |
| --- | --- |
| MID 137 | Trailer-brake system role; presence requires an observed source, not just a request target |
| PID 128 / 384 | Directed requests: count source, destination and requested parameter separately |
| PID 192 | Reassemble sections before decoding the enclosed parameter |
| PID 234 | Software identification metadata |
| PID 237 | VIN payload, without inferring physical ownership |
| PID 243 | Component MID and make/model/serial fields |
| PID 245 | Total-distance telemetry; not an identity anchor |
| PID 254 | Escape/vendor-specific traffic; counted as opaque, not decoded as a serial |

Hexadecimal `89` equals decimal `137`. In a message's source position it identifies
the transmitter; in a directed request's destination field it identifies who is
being asked. A request addressed to `89` proves only that the request was observed.
The [authentic excerpt](RESEARCH_CORPUS.md) is a regression case for this distinction.

## Contribution boundaries

Follow bytes through `capture_audit.zig` (record classification), `j1587.zig`
(parameter decoding), `j1587_multisection.zig` (reassembly), then
`protocol_ingest.zig` (owned observations). Input framing and logger conventions
must be established before assigning meaning. Combined/unsupported messages do
not silently become identities.

Synthetic fixtures show intended behavior, not hardware support. A real source
MID proves neither capture topology nor physical trailer position. Optional VIN,
software and component observations need corroboration before equipment matching.
For current limits and release criteria, use [project status](PROJECT_STATUS.md).
