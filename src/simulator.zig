const std = @import("std");
const model = @import("model.zig");

/// Behaviors supplied by the fake trailer. These are deterministic so tests and
/// demonstrations are repeatable.
pub const Behavior = enum {
    stable,
    no_load,
    intermittent,
    overcurrent,
    low_voltage,
};

pub const CircuitProfile = struct {
    circuit: model.Circuit,
    behavior: Behavior,
    nominal_voltage: f32,
    nominal_current: f32,
};

/// Software stand-in for the future physical Trailer Fingerprint measurement backend.
///
/// The test runner only needs three operations from a backend:
///   1. energize a selected circuit
///   2. capture a voltage/current sample
///   3. remove power
///
/// Real hardware can later replace this simulator without replacing the
/// analyzer or report code.
pub const Simulator = struct {
    trailer_id: []const u8,
    profiles: []const CircuitProfile,
    output_enabled: bool = false,
    active_circuit: ?model.Circuit = null,

    pub fn init(trailer_id: []const u8, profiles: []const CircuitProfile) Simulator {
        return .{
            .trailer_id = trailer_id,
            .profiles = profiles,
        };
    }

    pub fn enable(self: *Simulator, circuit: model.Circuit) void {
        self.active_circuit = circuit;
        self.output_enabled = true;
    }

    pub fn disable(self: *Simulator) void {
        self.output_enabled = false;
        self.active_circuit = null;
    }

    pub fn sample(self: *const Simulator, time_ms: u32) model.Sample {
        if (!self.output_enabled) {
            return .{ .time_ms = time_ms, .voltage = 0.0, .current = 0.0 };
        }

        const circuit = self.active_circuit orelse {
            return .{ .time_ms = time_ms, .voltage = 0.0, .current = 0.0 };
        };

        const profile = self.findProfile(circuit) orelse {
            return .{ .time_ms = time_ms, .voltage = 12.6, .current = 0.0 };
        };

        return sampleProfile(profile, time_ms);
    }

    fn findProfile(self: *const Simulator, circuit: model.Circuit) ?CircuitProfile {
        for (self.profiles) |profile| {
            if (profile.circuit == circuit) return profile;
        }
        return null;
    }
};

fn sampleProfile(profile: CircuitProfile, time_ms: u32) model.Sample {
    return switch (profile.behavior) {
        .stable => .{
            .time_ms = time_ms,
            .voltage = profile.nominal_voltage - stableVoltageOffset(time_ms),
            .current = profile.nominal_current + stableCurrentOffset(time_ms),
        },
        .no_load => .{
            .time_ms = time_ms,
            .voltage = profile.nominal_voltage,
            .current = if ((time_ms / 100) % 3 == 1) 0.01 else 0.0,
        },
        .intermittent => .{
            .time_ms = time_ms,
            .voltage = profile.nominal_voltage - 0.01,
            .current = intermittentCurrent(profile.nominal_current, time_ms),
        },
        .overcurrent => .{
            .time_ms = time_ms,
            .voltage = overcurrentVoltage(profile.nominal_voltage, time_ms),
            .current = overcurrentCurrent(time_ms),
        },
        .low_voltage => .{
            .time_ms = time_ms,
            .voltage = 9.8,
            .current = profile.nominal_current,
        },
    };
}

fn stableVoltageOffset(time_ms: u32) f32 {
    return switch ((time_ms / 100) % 4) {
        0 => 0.00,
        1 => 0.02,
        2 => 0.03,
        else => 0.02,
    };
}

fn stableCurrentOffset(time_ms: u32) f32 {
    return switch ((time_ms / 100) % 4) {
        0 => -0.02,
        1 => 0.03,
        2 => 0.00,
        else => 0.02,
    };
}

fn intermittentCurrent(nominal: f32, time_ms: u32) f32 {
    return switch ((time_ms / 100) % 6) {
        2 => 0.12,
        4 => 0.00,
        else => nominal,
    };
}

fn overcurrentCurrent(time_ms: u32) f32 {
    if (time_ms < 100) return 4.0;
    if (time_ms < 200) return 9.0;
    return 16.0;
}

fn overcurrentVoltage(nominal: f32, time_ms: u32) f32 {
    if (time_ms < 100) return nominal;
    if (time_ms < 200) return nominal - 0.3;
    return nominal - 0.8;
}

test "simulator does not produce a powered sample while disabled" {
    const profiles = [_]CircuitProfile{
        .{
            .circuit = .tail_marker,
            .behavior = .stable,
            .nominal_voltage = 12.6,
            .nominal_current = 5.8,
        },
    };

    var sim = Simulator.init("SIM", &profiles);
    const reading = sim.sample(0);

    try std.testing.expectEqual(@as(f32, 0.0), reading.voltage);
    try std.testing.expectEqual(@as(f32, 0.0), reading.current);
}
