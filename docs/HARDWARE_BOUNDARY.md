# Hardware boundary

v0.4 makes the software/hardware boundary real in code rather than merely documenting
it.

`runner.runCircuit()` is generic. It does not import or name `Simulator`. A backend only
needs to supply:

1. `trailer_id`
2. `enable(circuit)`
3. `sample(time_ms)` returning `model.Sample`
4. `disable()`

The simulator satisfies that contract today. A future bench backend can satisfy the same
contract while hiding GPIO, I2C/SPI, ADCs, current monitors, protected high-side
switches, and MCU-specific details.

The runner owns the energize/sample/de-energize sequence. `defer backend.disable()` keeps
the software invariant that a completed run requests power removal even as additional
early-exit paths are added later.

## Important limitation

That is only a software invariant. Real Trailer Fingerprint hardware must remove or limit unsafe
current independently of software. Firmware, a crashed CPU, or a stuck GPIO cannot be
the only thing standing between a shorted trailer circuit and the source supply.
