# Multisection reassembly

PID 192 carries sections of a larger parameter. The fixed bank is keyed by source
MID and target PID, supports interleaved transmitters, checks section order and
advertised length, and emits a parameter only when its sections are complete.
Current limits are eight concurrent transfers and 239 bytes per parameter.
Incomplete transfers at end of input do not emit observations; there is no
end-of-capture completeness report yet.

The synthetic identity fixtures exercise interleaving. Regression tests also cover
sequential reuse of a completed slot. The completed payload is borrowed storage;
see [ownership](REPLAY_PIPELINE.md#ownership) before retaining it.

Reassembly support does not establish that any particular trailer exposes an
identity parameter. See the [domain guide](PROTOCOL_REPLAY.md) and
[authentic capture evidence](RESEARCH_CORPUS.md).
