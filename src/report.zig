const std = @import("std");
const model = @import("model.zig");

pub fn printInspectionHeader(trailer_id: []const u8) void {
    std.debug.print("Trailer Fingerprint simulator v0.4\n", .{});
    std.debug.print("Trailer inspection: {s}\n", .{trailer_id});
    std.debug.print("Mode: simulated live test runner\n", .{});
    std.debug.print("Simulation values are not SAE limits.\n", .{});
}

pub fn printAnalysis(result: model.Analysis) void {
    std.debug.print("\nCircuit: {s}\n", .{result.circuit.label()});
    std.debug.print("Result:  {s}\n", .{result.classification.label()});

    if (result.protection_tripped) {
        std.debug.print("Output protection: TRIPPED -- circuit power removed\n", .{});
    }

    if (result.stats) |stats| {
        std.debug.print("Samples: {}\n", .{stats.sample_count});
        std.debug.print("Voltage: min={} V  max={} V  avg={} V\n", .{
            stats.min_voltage,
            stats.max_voltage,
            stats.avg_voltage,
        });
        std.debug.print("Current: min={} A  max={} A  avg={} A\n", .{
            stats.min_current,
            stats.max_current,
            stats.avg_current,
        });
    }
}

pub fn printBaselineComparison(comparison: model.BaselineComparison) void {
    if (!comparison.comparable) return;

    std.debug.print("Historical baseline: {} A avg\n", .{comparison.baseline_current});
    std.debug.print("Observed:            {} A avg\n", .{comparison.observed_current});
    std.debug.print("Change:              {}%\n", .{comparison.percent_change});
    std.debug.print("Material change:     {s}\n", .{
        if (comparison.changed) "YES" else "NO",
    });
}

pub fn printSummary(summary: model.InspectionSummary) void {
    std.debug.print("\nInspection summary\n", .{});
    std.debug.print("Total circuits tested: {}\n", .{summary.total});
    std.debug.print("Stable responses:      {}\n", .{summary.stable});
    std.debug.print("Needs attention:       {}\n", .{summary.attention});
    std.debug.print("Protection aborts:     {}\n", .{summary.aborted});
}
