# Why isn't one controller the trailer?

Suppose TFS observes an ABS controller with a stable serial number.

It is tempting to say:

> "That serial is the trailer."

TFS deliberately refuses to make that shortcut.

## Controllers are replaceable

Real equipment is maintained.

An ABS ECU can fail and be replaced.

If TFS equated:

```text
ABS serial = trailer identity
```

then replacing the ABS controller would appear to create a brand-new trailer.

That is not maintenance continuity.

## Controllers can also move

A controller can potentially migrate between physical units.

So even an exact module serial is an observation about the module, not unquestionable proof about the trailer that currently owns it.

## TFS's longer-term idea

The experimental identity design compares a **constellation of independent anchors**, potentially including:

- ABS ECU identity
- TPMS controller identity
- gateway or trailer-information-module identity
- tire-inflation controller identity
- reefer controller identity
- other electronically observable modules
- VIN, when electronically available

The important word is **independent**.

## Maintenance continuity

Imagine this conceptual case:

```text
Yesterday:
ABS serial       A-100
TPMS serial      T-200
gateway serial   G-300

After repair:
ABS serial       A-900   ← replaced
TPMS serial      T-200   ← survived
gateway serial   G-300   ← survived
```

Two independent anchors survived while one changed.

That is much stronger continuity evidence than treating the ABS serial alone as the trailer.

This is currently a **design model exercised with synthetic profiles**, not a claim that real trailers always expose all of these anchors.

## When evidence disappears

If all serial anchors disappear and the new modules only have the same make/model as a historical unit, TFS should not pretend that proves a match.

Fleet-spec trailers can be nearly identical.

The honest answer may be:

> **Identity not established.**

That result is part of the design, not a failure of it.

**Next:** [What does TFS do when it doesn't know?](EVIDENCE_BOUNDARIES.md)
