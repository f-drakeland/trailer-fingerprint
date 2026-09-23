# Trailer Fingerprint engineering notes

## v0.3 architectural change

Earlier versions stored completed fake traces. v0.3 now models the *act of testing*:

1. select a circuit
2. energize it
3. collect a sequence of samples
4. cut power immediately when simulated current crosses the protection limit
5. de-energize the circuit
6. analyze the resulting trace
7. compare relevant observations with historical behavior

This creates a clean seam between the future electronics and Trailer Fingerprint's software.

See `HARDWARE_BOUNDARY.md` for that contract.

## Current boundary

The project is still a pure simulator. Its job is to settle software behavior before
hardware is involved.

## Why traces, not snapshots

A single `(voltage, current)` pair cannot show an intermittent circuit. A sequence can
show a load disappearing and returning, current climbing toward a protection limit,
voltage collapsing under load, and behavior changing from a trailer's prior history.

## Baseline idea

Trailers differ in lamp count, LED/incandescent loads, wiring length, accessories, and
repairs. Universal thresholds alone will not capture every meaningful change.

Trailer Fingerprint therefore keeps the idea of self-comparison: what does this trailer normally
do, and is today's trace materially different?

## Intentionally absent

- no Bluetooth
- no phone app
- no cloud service
- no J2497 decoder
- no validated SAE diagnostic thresholds
- no connection to a real vehicle
- no roadworthiness determination

## v0.4 architectural correction

The v0.3 runner still named `simulator.Simulator` directly. That contradicted the stated
goal of being able to replace simulation with hardware without rewriting the runner.

v0.4 changes the runner to accept any backend satisfying Trailer Fingerprint's tiny backend
contract. A stub backend in the runner tests proves the separation.

The next useful work is physical measurement validation on a protected, current-limited
bench—not additional simulator ornamentation.
