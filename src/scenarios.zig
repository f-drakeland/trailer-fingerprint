const model = @import("model.zig");
const simulator = @import("simulator.zig");

pub const trailer_id = "532781";

pub const profiles = [_]simulator.CircuitProfile{
    .{
        .circuit = .clearance_identification,
        .behavior = .stable,
        .nominal_voltage = 12.60,
        .nominal_current = 3.12,
    },
    .{
        .circuit = .left_turn,
        .behavior = .stable,
        .nominal_voltage = 12.60,
        .nominal_current = 2.72,
    },
    .{
        .circuit = .stop,
        .behavior = .no_load,
        .nominal_voltage = 12.60,
        .nominal_current = 0.0,
    },
    .{
        .circuit = .right_turn,
        .behavior = .intermittent,
        .nominal_voltage = 12.60,
        .nominal_current = 2.74,
    },
    .{
        .circuit = .tail_marker,
        .behavior = .stable,
        .nominal_voltage = 12.60,
        .nominal_current = 4.30,
    },
};

pub const test_circuits = [_]model.Circuit{
    .clearance_identification,
    .left_turn,
    .stop,
    .right_turn,
    .tail_marker,
};

pub const historical_baseline = model.Baseline{
    .trailer_id = trailer_id,
    .circuit = .tail_marker,
    .avg_current = 5.80,
};
