//! Historical profile used by the protocol replay demo.

const model = @import("fingerprint_model.zig");

const known_modules = [_]model.ModuleIdentity{
    .{ .kind = .abs, .manufacturer = "DEMO", .model = "ABS-4S2M", .serial = "ABS-1001", .software = "SW-1.9" },
    .{ .kind = .tpms, .manufacturer = "DEMO", .model = "TPMS-8", .serial = "TPMS-2207" },
};

pub const known_profiles = [_]model.EquipmentProfile{
    .{
        .profile_id = "PROTO-TRAILER-A",
        .unit_class = .semitrailer,
        .vin = "1DEMO000000000001",
        .modules = &known_modules,
    },
};
