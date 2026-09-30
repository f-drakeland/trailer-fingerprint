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
///
/// Timing is supplied separately from the hardware backend:
///
///   clock.nowMs() -> u64
///   clock.waitUntilMs(deadline_ms)
///
/// The runner owns measurement cadence. The clock owns elapsed time, and the
/// backend owns hardware access. This keeps simulated time deterministic without
/// forcing a real hardware backend to implement scheduling policy.
pub fn runCircuit(
    backend: anytype,
    clock: anytype,
    circuit: model.Circuit,
    thresholds: model.Thresholds,
    config: RunConfig,
    sample_buffer: []model.Sample,
) model.TestRun {
    backend.enable(circuit);
    const start_ms = clock.nowMs();

    // Power-off cleanup belongs to the test runner, not to callers. As this
    // function gains more early-exit paths, defer keeps the invariant simple:
    // a completed run always asks the backend to remove power.
    defer backend.disable();

    const requested = @min(config.sample_count, sample_buffer.len);
    var used: usize = 0;
    var protection_tripped = false;

    while (used < requested) {
        const sample_index: u64 = @intCast(used);
        const deadline_ms =
            start_ms + sample_index * @as(u64, config.sample_interval_ms);

        if (sample_index != 0) {
            clock.waitUntilMs(deadline_ms);
        }

        const time_ms: u32 = @intCast(clock.nowMs() - start_ms);
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

pub const VirtualClock = struct {
    now_ms: u64 = 0,

    pub fn nowMs(self: *const VirtualClock) u64 {
        return self.now_ms;
    }

    pub fn waitUntilMs(self: *VirtualClock, deadline_ms: u64) void {
        if (deadline_ms > self.now_ms) {
            self.now_ms = deadline_ms;
        }
    }
};

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

const SlowStubBackend = struct {
    trailer_id: []const u8 = "SLOW-STUB",
    clock: *VirtualClock,
    work_ms: u64 = 30,
    output_enabled: bool = false,

    pub fn enable(self: *SlowStubBackend, circuit: model.Circuit) void {
        _ = circuit;
        self.output_enabled = true;
    }

    pub fn disable(self: *SlowStubBackend) void {
        self.output_enabled = false;
    }

    pub fn sample(self: *SlowStubBackend, time_ms: u32) model.Sample {
        const reading = model.Sample{
            .time_ms = time_ms,
            .voltage = 12.6,
            .current = 4.0,
        };

        // Simulate time consumed by a real hardware measurement.
        self.clock.now_ms += self.work_ms;

        return reading;
    }
};

test "runner uses the backend contract rather than the simulator type" {
    var backend = StubBackend{};
    var clock = VirtualClock{};
    var samples: [8]model.Sample = undefined;

    const run = runCircuit(
        &backend,
        &clock,
        .tail_marker,
        .{},
        .{},
        &samples,
    );

    try std.testing.expectEqualStrings("STUB-TRAILER", run.trailer_id);
    try std.testing.expect(run.protection_tripped);
    try std.testing.expectEqual(@as(usize, 3), run.samples.len);

    try std.testing.expectEqual(@as(u32, 0), run.samples[0].time_ms);
    try std.testing.expectEqual(@as(u32, 100), run.samples[1].time_ms);
    try std.testing.expectEqual(@as(u32, 200), run.samples[2].time_ms);

    try std.testing.expectEqual(@as(u64, 200), clock.nowMs());

    try std.testing.expect(!backend.output_enabled);
    try std.testing.expect(backend.active_circuit == null);
}

test "runner uses absolute deadlines so backend work does not accumulate drift" {
    var clock = VirtualClock{};
    var backend = SlowStubBackend{
        .clock = &clock,
    };
    var samples: [4]model.Sample = undefined;

    const run = runCircuit(
        &backend,
        &clock,
        .tail_marker,
        .{},
        .{
            .sample_interval_ms = 100,
            .sample_count = 4,
        },
        &samples,
    );

    try std.testing.expectEqual(@as(usize, 4), run.samples.len);

    try std.testing.expectEqual(@as(u32, 0), run.samples[0].time_ms);
    try std.testing.expectEqual(@as(u32, 100), run.samples[1].time_ms);
    try std.testing.expectEqual(@as(u32, 200), run.samples[2].time_ms);
    try std.testing.expectEqual(@as(u32, 300), run.samples[3].time_ms);

    try std.testing.expect(!backend.output_enabled);
}

test "runner records actual elapsed time when backend work exceeds the interval" {
    var clock = VirtualClock{};
    var backend = SlowStubBackend{
        .clock = &clock,
        .work_ms = 130,
    };
    var samples: [3]model.Sample = undefined;

    const run = runCircuit(
        &backend,
        &clock,
        .tail_marker,
        .{},
        .{
            .sample_interval_ms = 100,
            .sample_count = 3,
        },
        &samples,
    );

    try std.testing.expectEqual(@as(usize, 3), run.samples.len);

    try std.testing.expectEqual(@as(u32, 0), run.samples[0].time_ms);
    try std.testing.expectEqual(@as(u32, 130), run.samples[1].time_ms);
    try std.testing.expectEqual(@as(u32, 260), run.samples[2].time_ms);

    try std.testing.expect(!backend.output_enabled);
}
