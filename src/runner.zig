const std = @import("std");
const model = @import("model.zig");

pub const RunConfig = struct {
    sample_interval_ms: u32 = 100,
    sample_count: usize = 6,
    software_abort_current_limit: f32 = 15.0,
};

pub const Operation = enum {
    enable,
    sample,
    disable,
};

pub const RunFailure = struct {
    primary_operation: Operation,
    primary_error: anyerror,
    shutdown_error: ?anyerror = null,

    trailer_id: []const u8,
    circuit: model.Circuit,
    samples: []const model.Sample,
    software_overcurrent_abort: bool = false,
};

pub const RunOutcome = union(enum) {
    completed: model.TestRun,
    failed: RunFailure,
};

/// Perform one complete Trailer Fingerprint circuit test against any backend that
/// provides this small contract:
///
///   backend.trailer_id: []const u8
///   backend.enable(circuit) -> !void
///   backend.sample(time_ms) -> !model.Sample
///   backend.disable() -> !void
/// Backend access failures terminate execution without being treated as
/// electrical evidence from the tested circuit.
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
    config: RunConfig,
    sample_buffer: []model.Sample,
) RunOutcome {
    backend.enable(circuit) catch |err| {
        var shutdown_error: ?anyerror = null;

        backend.disable() catch |disable_err| {
            shutdown_error = disable_err;
        };

        return .{
            .failed = .{
                .primary_operation = .enable,
                .primary_error = err,
                .shutdown_error = shutdown_error,
                .trailer_id = backend.trailer_id,
                .circuit = circuit,
                .samples = sample_buffer[0..0],
            },
        };
    };

    const start_ms = clock.nowMs();

    const requested = @min(config.sample_count, sample_buffer.len);
    var used: usize = 0;
    var software_overcurrent_abort = false;

    while (used < requested) {
        const sample_index: u64 = @intCast(used);
        const deadline_ms =
            start_ms + sample_index * @as(u64, config.sample_interval_ms);

        if (sample_index != 0) {
            clock.waitUntilMs(deadline_ms);
        }

        const time_ms: u32 = @intCast(clock.nowMs() - start_ms);

        const reading = backend.sample(time_ms) catch |err| {
            var shutdown_error: ?anyerror = null;

            backend.disable() catch |disable_err| {
                shutdown_error = disable_err;
            };

            return .{
                .failed = .{
                    .primary_operation = .sample,
                    .primary_error = err,
                    .shutdown_error = shutdown_error,
                    .trailer_id = backend.trailer_id,
                    .circuit = circuit,
                    .samples = sample_buffer[0..used],
                    .software_overcurrent_abort = software_overcurrent_abort,
                },
            };
        };

        sample_buffer[used] = reading;
        used += 1;

        const hardware_fault =
            reading.hardware_diagnostic == .fault_reported;
        const software_overcurrent =
            reading.current > config.software_abort_current_limit;

        if (software_overcurrent) {
            software_overcurrent_abort = true;
        }

        if (hardware_fault or software_overcurrent) {
            break;
        }
    }

    backend.disable() catch |err| {
        return .{
            .failed = .{
                .primary_operation = .disable,
                .primary_error = err,
                .trailer_id = backend.trailer_id,
                .circuit = circuit,
                .samples = sample_buffer[0..used],
                .software_overcurrent_abort = software_overcurrent_abort,
            },
        };
    };

    return .{
        .completed = .{
            .trailer_id = backend.trailer_id,
            .circuit = circuit,
            .samples = sample_buffer[0..used],
            .software_overcurrent_abort = software_overcurrent_abort,
        },
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

    pub fn enable(self: *StubBackend, circuit: model.Circuit) !void {
        self.output_enabled = true;
        self.active_circuit = circuit;
    }

    pub fn disable(self: *StubBackend) !void {
        self.output_enabled = false;
        self.active_circuit = null;
    }

    pub fn sample(self: *const StubBackend, time_ms: u32) !model.Sample {
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

    pub fn enable(self: *SlowStubBackend, circuit: model.Circuit) !void {
        _ = circuit;
        self.output_enabled = true;
    }

    pub fn disable(self: *SlowStubBackend) !void {
        self.output_enabled = false;
    }

    pub fn sample(self: *SlowStubBackend, time_ms: u32) !model.Sample {
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

const FaultStubBackend = struct {
    trailer_id: []const u8 = "FAULT-STUB",
    output_enabled: bool = false,

    pub fn enable(self: *FaultStubBackend, circuit: model.Circuit) !void {
        _ = circuit;
        self.output_enabled = true;
    }

    pub fn disable(self: *FaultStubBackend) !void {
        self.output_enabled = false;
    }

    pub fn sample(self: *const FaultStubBackend, time_ms: u32) !model.Sample {
        _ = self;

        return .{
            .time_ms = time_ms,
            .voltage = 12.6,
            .current = 4.0,
            .hardware_diagnostic = if (time_ms >= 100)
                .fault_reported
            else
                .none,
        };
    }
};

const EnableFailBackend = struct {
    trailer_id: []const u8 = "ENABLE-FAIL",
    disable_called: bool = false,
    sample_called: bool = false,

    pub fn enable(self: *EnableFailBackend, circuit: model.Circuit) !void {
        _ = self;
        _ = circuit;
        return error.EnableFailed;
    }

    pub fn disable(self: *EnableFailBackend) !void {
        self.disable_called = true;
    }

    pub fn sample(self: *EnableFailBackend, time_ms: u32) !model.Sample {
        self.sample_called = true;

        return .{
            .time_ms = time_ms,
            .voltage = 0.0,
            .current = 0.0,
        };
    }
};

fn expectCompleted(outcome: RunOutcome) !model.TestRun {
    return switch (outcome) {
        .completed => |run| run,
        .failed => error.UnexpectedRunFailure,
    };
}

const SampleFailBackend = struct {
    trailer_id: []const u8 = "SAMPLE-FAIL",
    output_enabled: bool = false,
    disable_called: bool = false,
    sample_calls: usize = 0,

    pub fn enable(self: *SampleFailBackend, circuit: model.Circuit) !void {
        _ = circuit;
        self.output_enabled = true;
    }

    pub fn disable(self: *SampleFailBackend) !void {
        self.disable_called = true;
        self.output_enabled = false;
    }

    pub fn sample(self: *SampleFailBackend, time_ms: u32) !model.Sample {
        self.sample_calls += 1;

        if (self.sample_calls == 3) {
            return error.SampleFailed;
        }

        return .{
            .time_ms = time_ms,
            .voltage = 12.6,
            .current = 4.0,
        };
    }
};

const DisableFailBackend = struct {
    trailer_id: []const u8 = "DISABLE-FAIL",
    output_enabled: bool = false,
    disable_called: bool = false,

    pub fn enable(self: *DisableFailBackend, circuit: model.Circuit) !void {
        _ = circuit;
        self.output_enabled = true;
    }

    pub fn disable(self: *DisableFailBackend) !void {
        self.disable_called = true;
        return error.DisableFailed;
    }

    pub fn sample(_: *const DisableFailBackend, time_ms: u32) !model.Sample {
        return .{
            .time_ms = time_ms,
            .voltage = 12.6,
            .current = 4.0,
        };
    }
};

const SampleAndDisableFailBackend = struct {
    trailer_id: []const u8 = "SAMPLE-DISABLE-FAIL",
    disable_called: bool = false,
    sample_calls: usize = 0,

    pub fn enable(
        _: *SampleAndDisableFailBackend,
        circuit: model.Circuit,
    ) !void {
        _ = circuit;
    }

    pub fn disable(self: *SampleAndDisableFailBackend) !void {
        self.disable_called = true;
        return error.DisableFailed;
    }

    pub fn sample(
        self: *SampleAndDisableFailBackend,
        time_ms: u32,
    ) !model.Sample {
        self.sample_calls += 1;

        if (self.sample_calls == 3) {
            return error.SampleFailed;
        }

        return .{
            .time_ms = time_ms,
            .voltage = 12.6,
            .current = 4.0,
        };
    }
};

test "runner uses the backend contract rather than the simulator type" {
    var backend = StubBackend{};
    var clock = VirtualClock{};
    var samples: [8]model.Sample = undefined;

    const run = try expectCompleted(runCircuit(
        &backend,
        &clock,
        .tail_marker,
        .{},
        &samples,
    ));

    try std.testing.expectEqualStrings("STUB-TRAILER", run.trailer_id);
    try std.testing.expect(run.software_overcurrent_abort);
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

    const run = try expectCompleted(runCircuit(
        &backend,
        &clock,
        .tail_marker,
        .{
            .sample_interval_ms = 100,
            .sample_count = 4,
        },
        &samples,
    ));

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

    const run = try expectCompleted(runCircuit(
        &backend,
        &clock,
        .tail_marker,
        .{
            .sample_interval_ms = 100,
            .sample_count = 3,
        },
        &samples,
    ));

    try std.testing.expectEqual(@as(usize, 3), run.samples.len);

    try std.testing.expectEqual(@as(u32, 0), run.samples[0].time_ms);
    try std.testing.expectEqual(@as(u32, 130), run.samples[1].time_ms);
    try std.testing.expectEqual(@as(u32, 260), run.samples[2].time_ms);

    try std.testing.expect(!backend.output_enabled);
}

test "runner aborts on hardware fault without calling it overcurrent" {
    var backend = FaultStubBackend{};
    var clock = VirtualClock{};
    var samples: [6]model.Sample = undefined;

    const run = try expectCompleted(runCircuit(
        &backend,
        &clock,
        .tail_marker,
        .{
            .sample_interval_ms = 100,
            .sample_count = 6,
        },
        &samples,
    ));

    try std.testing.expectEqual(@as(usize, 2), run.samples.len);
    try std.testing.expectEqual(
        model.HardwareDiagnostic.fault_reported,
        run.samples[1].hardware_diagnostic,
    );

    // A generic hardware fault is evidence of a fault, not proof of overcurrent.
    try std.testing.expect(!run.software_overcurrent_abort);
    try std.testing.expect(!backend.output_enabled);
}

test "enable failure is preserved and shutdown is still attempted" {
    var backend = EnableFailBackend{};
    var clock = VirtualClock{};
    var samples: [4]model.Sample = undefined;

    const outcome = runCircuit(
        &backend,
        &clock,
        .tail_marker,
        .{},
        &samples,
    );

    switch (outcome) {
        .completed => return error.ExpectedRunFailure,
        .failed => |failure| {
            try std.testing.expectEqual(
                Operation.enable,
                failure.primary_operation,
            );
            try std.testing.expect(failure.primary_error == error.EnableFailed);
            try std.testing.expect(failure.shutdown_error == null);
            try std.testing.expectEqual(@as(usize, 0), failure.samples.len);
        },
    }

    try std.testing.expect(backend.disable_called);
    try std.testing.expect(!backend.sample_called);
}

test "sample failure preserves earlier samples and attempts shutdown" {
    var backend = SampleFailBackend{};
    var clock = VirtualClock{};
    var samples: [4]model.Sample = undefined;

    const outcome = runCircuit(
        &backend,
        &clock,
        .tail_marker,
        .{
            .sample_interval_ms = 100,
            .sample_count = 4,
        },
        &samples,
    );

    switch (outcome) {
        .completed => return error.ExpectedRunFailure,
        .failed => |failure| {
            try std.testing.expectEqual(
                Operation.sample,
                failure.primary_operation,
            );
            try std.testing.expect(failure.primary_error == error.SampleFailed);
            try std.testing.expect(failure.shutdown_error == null);

            try std.testing.expectEqual(
                @as(usize, 2),
                failure.samples.len,
            );

            try std.testing.expectEqual(
                @as(u32, 0),
                failure.samples[0].time_ms,
            );
            try std.testing.expectEqual(
                @as(u32, 100),
                failure.samples[1].time_ms,
            );
        },
    }

    try std.testing.expectEqual(@as(usize, 3), backend.sample_calls);
    try std.testing.expect(backend.disable_called);
    try std.testing.expect(!backend.output_enabled);
}

test "disable failure is reported after preserving completed samples" {
    var backend = DisableFailBackend{};
    var clock = VirtualClock{};
    var samples: [2]model.Sample = undefined;

    const outcome = runCircuit(
        &backend,
        &clock,
        .tail_marker,
        .{
            .sample_interval_ms = 100,
            .sample_count = 2,
        },
        &samples,
    );

    switch (outcome) {
        .completed => return error.ExpectedRunFailure,
        .failed => |failure| {
            try std.testing.expectEqual(
                Operation.disable,
                failure.primary_operation,
            );
            try std.testing.expect(failure.primary_error == error.DisableFailed);
            try std.testing.expect(failure.shutdown_error == null);

            try std.testing.expectEqual(
                @as(usize, 2),
                failure.samples.len,
            );

            try std.testing.expect(!failure.software_overcurrent_abort);
        },
    }

    try std.testing.expect(backend.disable_called);

    // A failed shutdown command is not evidence that power was removed.
    try std.testing.expect(backend.output_enabled);
}

test "sample failure remains primary when shutdown also fails" {
    var backend = SampleAndDisableFailBackend{};
    var clock = VirtualClock{};
    var samples: [4]model.Sample = undefined;

    const outcome = runCircuit(
        &backend,
        &clock,
        .tail_marker,
        .{
            .sample_interval_ms = 100,
            .sample_count = 4,
        },
        &samples,
    );

    switch (outcome) {
        .completed => return error.ExpectedRunFailure,
        .failed => |failure| {
            try std.testing.expectEqual(
                Operation.sample,
                failure.primary_operation,
            );
            try std.testing.expect(
                failure.primary_error == error.SampleFailed,
            );
            if (failure.shutdown_error) |shutdown_err| {
                try std.testing.expect(shutdown_err == error.DisableFailed);
            } else {
                return error.ExpectedShutdownFailure;
            }

            try std.testing.expectEqual(
                @as(usize, 2),
                failure.samples.len,
            );
        },
    }

    try std.testing.expectEqual(@as(usize, 3), backend.sample_calls);
    try std.testing.expect(backend.disable_called);
}

test "software abort limit is controlled by RunConfig" {
    var backend = StubBackend{};
    var clock = VirtualClock{};
    var samples: [4]model.Sample = undefined;

    const run = try expectCompleted(runCircuit(
        &backend,
        &clock,
        .tail_marker,
        .{
            .sample_interval_ms = 100,
            .sample_count = 4,
            .software_abort_current_limit = 20.0,
        },
        &samples,
    ));

    try std.testing.expect(!run.software_overcurrent_abort);
    try std.testing.expectEqual(@as(usize, 4), run.samples.len);

    // StubBackend reaches 16 A starting at 200 ms. That remains below this
    // runner's 20 A software-abort limit, so execution must continue.
    try std.testing.expectEqual(@as(f32, 16.0), run.samples[2].current);
    try std.testing.expectEqual(@as(f32, 16.0), run.samples[3].current);
}
