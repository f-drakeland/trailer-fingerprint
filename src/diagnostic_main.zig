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

    var summary = model.InspectionSummary{};
    report.printInspectionHeader(backend.trailer_id);

    for (scenarios.test_circuits) |circuit| {
        // A real device would fill this buffer with ADC/current-sensor readings.
        // For now the simulator backend creates those readings on demand.
        var sample_buffer: [8]model.Sample = undefined;

        const run = runner.runCircuit(
            &backend,
            circuit,
            thresholds,
            config,
            &sample_buffer,
        );

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
