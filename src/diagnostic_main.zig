const std = @import("std");
const model = @import("model.zig");
const analyzer = @import("analyzer.zig");
const simulator = @import("simulator.zig");
const runner = @import("runner.zig");
const scenarios = @import("scenarios.zig");
const report = @import("report.zig");

pub fn main() void {
    const thresholds = model.Thresholds{};
    const config = runner.RunConfig{};

    var backend = simulator.Simulator.init(
        scenarios.trailer_id,
        &scenarios.profiles,
    );

    var clock = runner.VirtualClock{};

    var summary = model.InspectionSummary{};
    report.printInspectionHeader(backend.trailer_id);

    for (scenarios.test_circuits) |circuit| {
        // A real device would fill this buffer with ADC/current-sensor readings.
        // For now the simulator backend creates those readings on demand.
        var sample_buffer: [8]model.Sample = undefined;

        const run = switch (runner.runCircuit(
            &backend,
            &clock,
            circuit,
            config,
            &sample_buffer,
        )) {
            .completed => |completed_run| completed_run,

            .failed => |failure| {
                std.debug.print("\nCircuit: {s}\n", .{failure.circuit.label()});
                std.debug.print(
                    "Run execution failed during {s}: {s}\n",
                    .{
                        @tagName(failure.primary_operation),
                        @errorName(failure.primary_error),
                    },
                );

                if (failure.shutdown_error) |shutdown_err| {
                    std.debug.print(
                        "Shutdown also failed: {s}\n",
                        .{@errorName(shutdown_err)},
                    );
                }

                std.debug.print(
                    "Preserved samples: {}\n",
                    .{failure.samples.len},
                );

                return;
            },
        };

        const result = analyzer.analyze(run, thresholds);
        analyzer.updateSummary(&summary, result.classification);
        report.printAnalysis(result);

        if (circuit == scenarios.historical_baseline.circuit) {
            const comparison = analyzer.compareToBaseline(
                result,
                scenarios.historical_baseline,
                20.0,
            );
            report.printBaselineComparison(comparison);
        }
    }

    report.printSummary(summary);
}

test {
    _ = analyzer;
    _ = simulator;
    _ = runner;
}
