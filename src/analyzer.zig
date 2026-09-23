const std = @import("std");
const model = @import("model.zig");

pub fn analyze(run: model.TestRun, thresholds: model.Thresholds) model.Analysis {
    const stats = calculateStatistics(run.samples) orelse {
        return .{
            .trailer_id = run.trailer_id,
            .circuit = run.circuit,
            .classification = .insufficient_data,
            .stats = null,
            .protection_tripped = run.protection_tripped,
        };
    };

    const classification: model.Classification = if (
        run.protection_tripped or stats.max_current > thresholds.overcurrent_limit
    )
        .overcurrent_abort
    else if (stats.min_voltage < thresholds.min_source_voltage)
        .low_source_voltage
    else if (stats.max_current <= thresholds.no_load_current)
        .no_load_detected
    else if ((stats.max_current - stats.min_current) >= thresholds.unstable_current_span)
        .unstable_load
    else
        .stable_response;

    return .{
        .trailer_id = run.trailer_id,
        .circuit = run.circuit,
        .classification = classification,
        .stats = stats,
        .protection_tripped = run.protection_tripped,
    };
}

pub fn calculateStatistics(samples: []const model.Sample) ?model.Statistics {
    if (samples.len == 0) return null;

    var min_voltage = samples[0].voltage;
    var max_voltage = samples[0].voltage;
    var min_current = samples[0].current;
    var max_current = samples[0].current;
    var voltage_total: f32 = 0.0;
    var current_total: f32 = 0.0;

    for (samples) |sample| {
        min_voltage = @min(min_voltage, sample.voltage);
        max_voltage = @max(max_voltage, sample.voltage);
        min_current = @min(min_current, sample.current);
        max_current = @max(max_current, sample.current);
        voltage_total += sample.voltage;
        current_total += sample.current;
    }

    const count: f32 = @floatFromInt(samples.len);

    return .{
        .sample_count = samples.len,
        .min_voltage = min_voltage,
        .max_voltage = max_voltage,
        .avg_voltage = voltage_total / count,
        .min_current = min_current,
        .max_current = max_current,
        .avg_current = current_total / count,
    };
}

pub fn compareToBaseline(
    analysis: model.Analysis,
    baseline: model.Baseline,
    change_limit_percent: f32,
) model.BaselineComparison {
    if (analysis.stats == null or
        analysis.circuit != baseline.circuit or
        !std.mem.eql(u8, analysis.trailer_id, baseline.trailer_id) or
        baseline.avg_current == 0.0)
    {
        return .{
            .comparable = false,
            .baseline_current = baseline.avg_current,
            .observed_current = 0.0,
            .percent_change = 0.0,
            .changed = false,
        };
    }

    const observed = analysis.stats.?.avg_current;
    const percent_change = ((observed - baseline.avg_current) / baseline.avg_current) * 100.0;

    return .{
        .comparable = true,
        .baseline_current = baseline.avg_current,
        .observed_current = observed,
        .percent_change = percent_change,
        .changed = @abs(percent_change) >= change_limit_percent,
    };
}

pub fn updateSummary(summary: *model.InspectionSummary, classification: model.Classification) void {
    summary.total += 1;

    switch (classification) {
        .stable_response => summary.stable += 1,
        .overcurrent_abort => summary.aborted += 1,
        else => summary.attention += 1,
    }
}

test "stable response is classified conservatively" {
    const samples = [_]model.Sample{
        .{ .time_ms = 0, .voltage = 12.6, .current = 5.7 },
        .{ .time_ms = 100, .voltage = 12.5, .current = 5.8 },
        .{ .time_ms = 200, .voltage = 12.5, .current = 5.8 },
    };

    const result = analyze(.{
        .trailer_id = "TEST-1",
        .circuit = .tail_marker,
        .samples = &samples,
    }, .{});

    try std.testing.expectEqual(model.Classification.stable_response, result.classification);
}

test "zero response is no load detected, not a guessed diagnosis" {
    const samples = [_]model.Sample{
        .{ .time_ms = 0, .voltage = 12.6, .current = 0.0 },
        .{ .time_ms = 100, .voltage = 12.6, .current = 0.0 },
        .{ .time_ms = 200, .voltage = 12.6, .current = 0.0 },
    };

    const result = analyze(.{
        .trailer_id = "TEST-2",
        .circuit = .tail_marker,
        .samples = &samples,
    }, .{});

    try std.testing.expectEqual(model.Classification.no_load_detected, result.classification);
}

test "large current swing is unstable load" {
    const samples = [_]model.Sample{
        .{ .time_ms = 0, .voltage = 12.6, .current = 5.8 },
        .{ .time_ms = 100, .voltage = 12.6, .current = 0.2 },
        .{ .time_ms = 200, .voltage = 12.6, .current = 5.9 },
    };

    const result = analyze(.{
        .trailer_id = "TEST-3",
        .circuit = .tail_marker,
        .samples = &samples,
    }, .{});

    try std.testing.expectEqual(model.Classification.unstable_load, result.classification);
}

test "protection trip wins over other classifications" {
    const samples = [_]model.Sample{
        .{ .time_ms = 0, .voltage = 12.6, .current = 4.0 },
        .{ .time_ms = 100, .voltage = 11.8, .current = 14.0 },
    };

    const result = analyze(.{
        .trailer_id = "TEST-4",
        .circuit = .tail_marker,
        .samples = &samples,
        .protection_tripped = true,
    }, .{});

    try std.testing.expectEqual(model.Classification.overcurrent_abort, result.classification);
}

test "baseline comparison detects material change" {
    const samples = [_]model.Sample{
        .{ .time_ms = 0, .voltage = 12.6, .current = 4.2 },
        .{ .time_ms = 100, .voltage = 12.6, .current = 4.3 },
        .{ .time_ms = 200, .voltage = 12.6, .current = 4.4 },
    };

    const result = analyze(.{
        .trailer_id = "532781",
        .circuit = .tail_marker,
        .samples = &samples,
    }, .{});

    const comparison = compareToBaseline(result, .{
        .trailer_id = "532781",
        .circuit = .tail_marker,
        .avg_current = 5.8,
    }, 20.0);

    try std.testing.expect(comparison.comparable);
    try std.testing.expect(comparison.changed);
}
