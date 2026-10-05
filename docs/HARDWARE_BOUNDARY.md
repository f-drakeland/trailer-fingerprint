# Hardware boundary

v0.4 makes the software/hardware boundary real in code rather than merely
documenting it.

`runner.runCircuit()` is generic. It does not import or name `Simulator`. A
backend supplies:

1. `trailer_id`
2. `enable(circuit) -> !void`
3. `sample(time_ms) -> !model.Sample`
4. `disable() -> !void`

Timing is a separate dependency. The runner uses a clock that provides:

1. `nowMs()`
2. `waitUntilMs(deadline_ms)`

The runner owns sampling cadence using absolute deadlines. The clock owns elapsed
time; the backend owns hardware access. Simulator runs use a virtual clock so
tests remain deterministic and instantaneous. A physical implementation must use
a real monotonic time source.

Sample timestamps record observed elapsed time rather than assuming that
requested deadlines were met exactly.

## Execution failures

Backend access and control failures are not electrical evidence from the tested
circuit.

`runCircuit()` returns either a completed `model.TestRun` or a `RunFailure`.
A failure records the operation that failed, the backend error, samples captured
before the failure, and any separate shutdown error.

After any attempted enable, the runner makes a best-effort request to disable the
output before returning. If sampling fails, previously captured samples are
preserved but are not passed to the analyzer as a completed test.

If the original operation fails and shutdown also fails, the original failure
remains primary and the shutdown failure is preserved separately.

A backend reporting that `disable()` succeeded is a software/backend result. Real
hardware must not depend on that result alone to guarantee a safe de-energized
state.

## Electrical observations and aborts

Each sample may carry a generic hardware diagnostic state. A backend reports
`fault_reported` when physical output or measurement hardware indicates a fault,
without guessing its cause.

The runner stops a test when either:

1. measured current exceeds `RunConfig.software_abort_current_limit`, or
2. the hardware reports a fault.

The software abort current is execution policy. It is separate from analyzer
thresholds.

The analyzer may classify a completed run as `high_current_observed` when measured
current exceeds its analysis threshold without claiming that the runner aborted
the test.

These observations remain distinct:

- a software overcurrent abort does not prove hardware protection tripped
- a generic hardware fault does not prove overcurrent
- high current observed by the analyzer does not mean the test was aborted
- a backend access failure is not a circuit diagnosis

The simulator satisfies the same backend contract used by a future bench backend,
while hiding GPIO, I2C/SPI, ADCs, current monitors, protected high-side switches,
and MCU-specific details.

## Important limitation

The runner's shutdown behavior is only a software invariant. Real Trailer
Fingerprint hardware must remove or limit unsafe current independently of
software. Firmware, a crashed CPU, a failed communication path, or a stuck GPIO
cannot be the only thing standing between a shorted test circuit and the source
supply.
