//! Synthetic discovery captures.
//!
//! These records intentionally represent the OUTPUT of a future decoder rather
//! than pretending to be raw J2497 bytes. The purpose of v0.6 is to prove the
//! pipeline boundary: discovery -> normalization -> fingerprinting.

const discovery = @import("discovery.zig");

const lead_modules = [_]discovery.DiscoveredModule{
    .{
        .source = .synthetic_replay,
        .endpoint = "ABS endpoint",
        .identity = .{ .kind = .abs, .manufacturer = "Vendor-A", .model = "ABS-4S2M", .serial = "A-ABS-2099", .software = "3.4" },
    },
    .{
        .source = .synthetic_replay,
        .endpoint = "TPMS endpoint",
        .identity = .{ .kind = .tpms, .manufacturer = "Vendor-T", .model = "TPMS-8", .serial = "A-TPMS-2207" },
    },
    .{
        .source = .synthetic_replay,
        .endpoint = "gateway endpoint",
        .identity = .{ .kind = .gateway, .manufacturer = "Vendor-G", .model = "GATE-1", .serial = "A-GW-7711" },
    },
};

const dolly_modules = [_]discovery.DiscoveredModule{
    .{
        .source = .synthetic_replay,
        .endpoint = "dolly ABS endpoint",
        .identity = .{ .kind = .abs, .manufacturer = "Vendor-D", .model = "DOLLY-ABS", .serial = "D-ABS-0440" },
    },
};

const rear_modules = [_]discovery.DiscoveredModule{
    .{
        .source = .synthetic_replay,
        .endpoint = "rear ABS endpoint",
        .identity = .{ .kind = .abs, .manufacturer = "Vendor-B", .model = "ABS-4S2M", .serial = "B-ABS-5008" },
    },
    .{
        .source = .synthetic_replay,
        .endpoint = "rear TPMS endpoint",
        .identity = .{ .kind = .tpms, .manufacturer = "Vendor-T", .model = "TPMS-8", .serial = "B-TPMS-9001" },
    },
};

pub const doubles_capture = [_]discovery.DiscoveredUnit{
    .{
        .observed_name = "observed unit 1",
        .unit_class = .semitrailer,
        .position = .lead,
        .modules = &lead_modules,
    },
    .{
        .observed_name = "observed unit 2",
        .unit_class = .converter_dolly,
        .position = .dolly,
        .modules = &dolly_modules,
    },
    .{
        .observed_name = "observed unit 3",
        .unit_class = .semitrailer,
        .position = .rear,
        .modules = &rear_modules,
    },
};

const twin_modules = [_]discovery.DiscoveredModule{
    .{
        .source = .synthetic_replay,
        .identity = .{ .kind = .abs, .manufacturer = "Vendor-A", .model = "ABS-4S2M", .serial = "TWIN-ABS-9991" },
    },
    .{
        .source = .synthetic_replay,
        .identity = .{ .kind = .tpms, .manufacturer = "Vendor-T", .model = "TPMS-8", .serial = "TWIN-TPMS-9992" },
    },
    .{
        .source = .synthetic_replay,
        .identity = .{ .kind = .gateway, .manufacturer = "Vendor-G", .model = "GATE-1", .serial = "TWIN-GW-9993" },
    },
};

pub const fleet_twin_capture = discovery.DiscoveredUnit{
    .observed_name = "fleet-spec lookalike",
    .unit_class = .semitrailer,
    .position = .single,
    .modules = &twin_modules,
};
