# Bench prototype direction

The simulator is now far enough along that adding more fake product features has
shrinking value. The next engineering work should validate the physical measurement
boundary on a current-limited bench setup, not on a truck or trailer.

## What the first bench prototype must prove

For one low-current 12 V test load, Trailer Fingerprint needs to demonstrate that software can:

1. request a protected output ON
2. observe bus voltage
3. observe load current repeatedly over time
4. request the output OFF
5. preserve the trace for the existing analyzer
6. respond to an independently protected overcurrent condition

That is enough to replace `Simulator` with a first `BenchBackend` later.

## Candidate measurement component

A useful component family to evaluate is TI's INA238 / INA238-Q1. It measures shunt
current and bus voltage digitally over I2C with an 85 V common-mode range. The Q1
variant is automotive qualified. This is a candidate, not a final design choice.

Sources:
- https://www.ti.com/product/INA238
- https://www.ti.com/product/INA238-Q1

## Candidate protected output stage

Infineon's PROFET +2 12 V family is worth evaluating because it is explicitly designed
for protected automotive high-side switching and provides load-current diagnostic
capability. Infineon sells evaluation boards/shields so we can learn the behavior on a
bench before designing a custom PCB.

Examples:
- https://www.infineon.com/evaluation-board/SHIELD-BTS7006-1EPP
- https://www.infineon.com/evaluation-board/PROFET-ONE4ALL-MB-V1

The final Trailer Fingerprint design must not depend on software alone for short-circuit or
overcurrent protection.

## MCU / Zig decision

Do not buy a microcontroller solely because it is fashionable or because it says Zig.
MicroZig currently documents Raspberry Pi Pico / Pico 2 as its best-supported hardware,
but its current getting-started flow tracks Zig master rather than the project's existing
Zig 0.16 host toolchain.

Source:
- https://microzig.tech/docs/getting-started/

That means the sensible prototype split is still open:

- keep the Trailer Fingerprint host/core logic on Zig 0.16
- evaluate a small hardware controller separately
- require the hardware side to satisfy the backend contract in `runner.zig`

We do not need to commit to the final MCU before proving the measurement path.

## Safety boundary

First hardware work should use a current-limited bench supply and a controlled dummy
load. Do not connect an improvised prototype to a truck or trailer. Automotive wiring
can expose electronics to reverse polarity, transients, shorts, inductive events, and
currents well beyond what a development board can tolerate.
