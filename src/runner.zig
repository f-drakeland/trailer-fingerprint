const std = @import("std");
const model = @import("model.zig");

pub const RunConfig = struct {
    sample_interval_ms: u32 = 100,
    sample_count: usize = 6,
};

/// Perform one complete Trailer Fingerprint circuit test against any backend that
/// provides this small contract:
///
///   backend.trailer_id: []const u8
///   backend.enable(circuit)
///   backend.sample(time_ms) -> model.Sample
///   backend.disable()
///
/// The runner deliberately knows nothing about Simulator, ADCs, GPIO, I2C,
/// or a particular microcontroller. That is what lets the same test sequence
/// survive the transition from Mac simulation to bench hardware.
pub fn runCircuit(
    backend: anytype,
    circuit: model.Circuit,
    thresholds: model.Thresholds,
    config: RunConfig,
    sample_buffer: []model.Sample,
) model.TestRun {
    backend.enable(circuit);

    // Power-off cleanup belongs to the test runner, not to callers. As this
    // function gains more early-exit paths, defer keeps the invariant simple:
    // a completed run always asks the backend to remove power.
    defer backend.disable();

    const requested = @min(config.sample_count, sample_buffer.len);
    var used: usize = 0;
    var protection_tripped = false;

    while (used < requested) {
        const sample_index: u32 = @intCast(used);
        const time_ms = sample_index * config.sample_interval_ms;
        const reading = backend.sample(time_ms);

        sample_buffer[used] = reading;
        used += 1;

        if (reading.current > thresholds.overcurrent_limit) {
            protection_tripped = true;
            break;
        }
    }

    return .{
        .trailer_id = backend.trailer_id,
        .circuit = circuit,
        .samples = sample_buffer[0..used],
        .protection_tripped = protection_tripped,
    };
}

const StubBackend = struct {
    trailer_id: []const u8 = "STUB-TRAILER",
    output_enabled: bool = false,
    active_circuit: ?model.Circuit = null,

    pub fn enable(self: *StubBackend, circuit: model.Circuit) void {
        self.output_enabled = true;
        self.active_circuit = circuit;
    }

    pub fn disable(self: *StubBackend) void {
        self.output_enabled = false;
        self.active_circuit = null;
    }

    pub fn sample(self: *const StubBackend, time_ms: u32) model.Sample {
        if (!self.output_enabled) {
            return .{ .time_ms = time_ms, .voltage = 0.0, .current = 0.0 };
        }

        return .{
            .time_ms = time_ms,
            .voltage = 12.6,
            .current = if (time_ms < 200) 4.0 else 16.0,
        };
    }
};

test "runner uses the backend contract rather than the simulator type" {
    var backend = StubBackend{};
    var samples: [8]model.Sample = undefined;

    const run = runCircuit(
        &backend,
        .tail_marker,
        .{},
        .{},
        &samples,
    );

    try std.testing.expectEqualStrings("STUB-TRAILER", run.trailer_id);
    try std.testing.expect(run.protection_tripped);
    try std.testing.expectEqual(@as(usize, 3), run.samples.len);
    try std.testing.expect(!backend.output_enabled);
    try std.testing.expect(backend.active_circuit == null);
}
