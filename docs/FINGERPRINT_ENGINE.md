# Equipment fingerprint engine v0.1

Experimental design, exercised by `zig build synthetic` with fictional profiles.
The normal capture CLI does not assign these matches. A single matching module
serial can currently produce `recognized`; that heuristic does not establish
physical-equipment continuity when controllers can move or be replaced.


This version tests the identity idea without pretending we can already decode a real trailer network.

## Original design goal (not yet established by the matcher)

A physical trailer is **not** identified by one ECU serial number.

The engine compares a constellation of surviving identity anchors:

- ABS ECU identity
- TPMS controller identity
- gateway / trailer information module identity
- tire-inflation controller identity
- reefer controller identity
- other electronically observable modules
- VIN, when it happens to be available electronically

VIN is optional. The normal workflow must not depend on driver entry.

## Maintenance continuity

A module replacement is treated as an event, not automatically as a new trailer.

Example:

- ABS serial changed
- TPMS serial survived
- gateway serial survived

The engine can recognize the historical equipment profile because independent anchors survived the repair.

If **all** serial anchors disappear and the new modules merely have the same make/model as the historical unit, the engine does not declare a match. Fleet-spec trailers can be nearly identical. The result becomes ambiguous.

## Doubles / multi-unit loads

Identity belongs to individual units, not to the whole electrical load.

A doubles consist can contain:

1. lead semitrailer
2. converter dolly
3. rear semitrailer

The current version matches each normalized equipment unit independently and then summarizes the current consist.

This intentionally does **not** claim that J2497 can always tell us physical order. `Position` can be `unknown`. Discovering which modules can be grouped and positioned from a front J560 connection remains an empirical research question.

## Electrical fingerprints stay separate

Electrical current/voltage behavior belongs to the **current connected topology**. A lead trailer by itself and the same lead trailer towing a dolly + rear trailer can produce different aggregate electrical loads.

Therefore v0.1 does not use circuit current as a primary unit identity anchor. The v0.4 diagnostic engine remains available separately with:

```bash
zig build diagnostics
```

Later, electrical behavior can corroborate a known consist rather than incorrectly becoming the identity of one trailer.

## Protocol boundary

The fingerprint engine consumes normalized `ModuleIdentity` records. It does not care whether those records eventually come from:

- J2497 / PLC + J1708/J1587 decoding
- trailer-side J1939/CAN
- a commercial diagnostic adapter
- replayed capture files
- a future hardware backend

That separation is deliberate. First prove the identity logic; then connect it to real protocol data.

## Kill criteria still apply

The project still has to prove on real equipment that enough stable identity anchors are actually observable through the practical connection point. This engine demonstrates what we can do **if** those anchors are available; it does not claim that every trailer exposes them.
