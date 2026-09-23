# Shared equipment-history network model

This document describes a design/research model for Trailer Fingerprint, an
experimental open system for persistent identity and shared histories of heavy-duty
commercial semitrailers, converter dollies, doubles, and related towed equipment.
It is not a server design, implementation specification, or claim that a network
already exists. The goal is evidence-based equipment history rather than
fleet-specific tracking.

## Current baseline and research limits

The v0.11 Zig 0.16.0 code is a local protocol/fingerprint research baseline. It
loads `.tfc` captures and external logs, including common J1708 logger, Truck Duck,
and `pretty_j1587` styles, after J2497/PLC waveform demodulation and J1708 checksum
handling. It supports PID 192 multisection reassembly, PID 243 component identity,
PID 234 software metadata, and optional PID 237 VIN. PID 245 distance is telemetry
history, explicitly not an identity anchor.

Current comparisons use fixture profiles; the code does not implement the shared
graph or component-migration history described here. Synthetic captures and
scenarios are engineering fixtures and must remain clearly labeled as synthetic.
The included public `pretty_j1587` sample is real public protocol data, but contains
telemetry rather than usable identity anchors.

Real-world J2497/J1708 identity-bearing data remains the main research bottleneck.
The project has not validated identity behavior against a sufficient real-world
trailer corpus, does not demodulate J2497 waveforms, and does not claim universal
identification or conclusions beyond the available evidence.

## Equipment identity and component identity

Equipment identity belongs to a physical trailer or dolly. Component identity
belongs to an ABS ECU, TPMS controller, gateway, or other module. A controller
serial number identifies a component; it is not a permanent identity for the
equipment carrying it.

The model treats equipment, components, and observations separately. An observation
can support a relationship between a component and equipment at that encounter.
Those relationships can change through replacement, repair, reuse, or migration.
Past associations remain historical evidence rather than permanent ownership of
the component by one equipment profile.

A physical unit should retain continuity across normal maintenance when surviving
module anchors and other available evidence support that inference. If an ABS
identity changes while independent TPMS and gateway anchors survive, continuity
may be supported without treating the unit as new equipment. A missing response
alone does not prove removal or replacement.

## Shared observations and historical comparison

The intended history extends beyond what one driver or device has encountered.
Participating devices may eventually contribute observations so that a later
encounter can be compared with evidence contributed by other participating devices.
Contribution to a shared history does not automatically authorize public release
of every observation field.

The conceptual flow is:

```text
physical equipment
    -> participating device
    -> protocol/electrical observations
    -> identity/fingerprint engine
    -> shared equipment graph
    -> historical comparison
    -> new evidence appended
```

The shared equipment graph is a conceptual set of equipment, components,
observations, and changing relationships, not a chosen database or service
architecture. Historical comparison should preserve the evidence behind inferred
continuity, unresolved alternatives, and conflicts. New evidence may revise an
interpretation without erasing the observations on which earlier interpretations
were based. Sharing an observation does not itself make the observation reliable.

## Component migration and reuse

A component seen on equipment A and later associated with independently supported
equipment B should be modeled as possible component migration or reuse, not proof
that A and B are the same physical unit. Where evidence supports migration, the
component history can connect those encounters while the equipment identities stay
separate. Where attribution is uncertain, the relationship remains unresolved.

A matching serial alone cannot settle equipment continuity in a shared history
where components may move. This is a research requirement beyond the current local
fixture matcher, not a claim that v0.11 already resolves migration.

## Optional VIN, conflicts, and ambiguity

VIN is useful evidence when available, but neither electronic VIN availability nor
manual VIN entry is required by the model. Surviving component anchors may support
continuity without it; insufficient evidence must remain insufficient.

A VIN conflict must produce an identity conflict rather than silent merging.
Matching component evidence does not cancel that conflict. Conflicting evidence
should remain attributable to its observations until further evidence supports a
resolution.

Fleet-spec twins can have identical makes and models. Without surviving anchors or
other distinguishing evidence, they remain ambiguous rather than being forced into
one equipment profile. Telemetry-only encounters do not establish equipment
identity. Unknown identity, component association, or physical position is an
acceptable result.

## Multi-unit consists and electrical behavior

The lead trailer, converter dolly, and rear trailer remain separate physical
identities even when observed together in one doubles consist. Their participation
and position describe the current connected arrangement, not a permanent combined
equipment identity. Grouping or physical order must remain unknown when the
observations cannot establish it; bus addresses alone do not prove position.

Aggregate electrical behavior belongs to the current topology or consist. Adding
a dolly and rear trailer can change the measured load without changing the lead
trailer’s identity. Electrical observations may contribute diagnostic history or
corroboration, but must not be assigned as a persistent identity of one unit merely
because they were measured during that encounter.

## Evidence discipline and maintenance history

The history must distinguish four kinds of information:

- **Machine-observed changes:** differences between actual observations, bounded
  by what was measured and when.
- **Inferred continuity:** a reasoned association of encounters with the same
  physical equipment, supported by stated evidence rather than presented as fact
  supplied by a maintenance record.
- **Explicitly reported maintenance:** a report from an identified trusted source,
  kept distinguishable from what the device directly observed.
- **Conflicts or ambiguity:** incompatible evidence or multiple plausible
  interpretations that have not been resolved.

For example, if comparable observations show different ABS component identities
and the other evidence supports equipment continuity, the system may say:

> ABS component changed between the June 4 and July 11 observations.

It may not turn that observation into:

> ABS ECU was replaced July 7 because of a fault.

The latter requires another trusted source that actually supplies the replacement,
date, and reason, such as an explicit maintenance report. Even then, those details
must be attributed to that report rather than represented as machine-observed.
The two encounters establish an observation interval, not the exact event date,
cause, or circumstances of a repair.

## Privacy and public-data boundaries

Shared or public equipment history must not become a public surveillance system by
default. Equipment continuity does not require driver identity, tractor identity,
or precise location. These are not prerequisites for matching and should not become
default public encounter fields or enable public equipment movement histories.

Raw manufacturer serial numbers and VINs do not necessarily need to be public.
The network may eventually use raw identifiers internally for matching while
exposing safer representations, such as opaque equipment and component IDs.
Internal matching evidence and public history are separate disclosure decisions.
Opaque IDs alone do not prevent tracking if public encounter details still reveal
movements; publication must also consider which timing and contextual details are
necessary for the equipment history.

Access, contribution trust, retention, and the exact public representation remain
open research/design questions. This model sets boundaries without choosing a
server architecture, identifier scheme, or claiming implemented privacy controls.

## Driver experience goals

The intended device should discover whatever it reasonably can while keeping its
conclusions conservative. Core operation should require no routine manual VIN
entry, trailer profile selection, or phone, and no cut, splice, or permanent
modification to customer or host equipment. These are product goals, not claims
about an available hardware implementation. Missing evidence should yield an
honest unresolved result rather than requiring the driver to invent certainty.
