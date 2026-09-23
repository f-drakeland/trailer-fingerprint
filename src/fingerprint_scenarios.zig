//! Synthetic decoded observations.
//!
//! These are NOT captures from a real trailer and the vendor/model names are
//! intentionally generic. They exercise the identity engine before we own a
//! J2497 interface or real replay files.

const model = @import("fingerprint_model.zig");

const trailer_a_modules = [_]model.ModuleIdentity{
    .{ .kind = .abs, .manufacturer = "Vendor-A", .model = "ABS-4S2M", .serial = "A-ABS-1001", .software = "3.2" },
    .{ .kind = .tpms, .manufacturer = "Vendor-T", .model = "TPMS-8", .serial = "A-TPMS-2207" },
    .{ .kind = .gateway, .manufacturer = "Vendor-G", .model = "GATE-1", .serial = "A-GW-7711" },
};

const dolly_d_modules = [_]model.ModuleIdentity{
    .{ .kind = .abs, .manufacturer = "Vendor-D", .model = "DOLLY-ABS", .serial = "D-ABS-0440" },
};

const trailer_b_modules = [_]model.ModuleIdentity{
    .{ .kind = .abs, .manufacturer = "Vendor-B", .model = "ABS-4S2M", .serial = "B-ABS-5008" },
    .{ .kind = .tpms, .manufacturer = "Vendor-T", .model = "TPMS-8", .serial = "B-TPMS-4110" },
};

pub const known_profiles = [_]model.EquipmentProfile{
    .{
        .profile_id = "TRAILER-A",
        .unit_class = .semitrailer,
        .modules = &trailer_a_modules,
    },
    .{
        .profile_id = "DOLLY-D",
        .unit_class = .converter_dolly,
        .modules = &dolly_d_modules,
    },
    .{
        .profile_id = "TRAILER-B",
        .unit_class = .semitrailer,
        .modules = &trailer_b_modules,
    },
};

// Trailer A after a normal maintenance event: ABS ECU changed, TPMS and
// gateway survived. This is the maintenance-continuity case we care about.
const observed_lead_modules = [_]model.ModuleIdentity{
    .{ .kind = .abs, .manufacturer = "Vendor-A", .model = "ABS-4S2M", .serial = "A-ABS-2099", .software = "3.4" },
    .{ .kind = .tpms, .manufacturer = "Vendor-T", .model = "TPMS-8", .serial = "A-TPMS-2207" },
    .{ .kind = .gateway, .manufacturer = "Vendor-G", .model = "GATE-1", .serial = "A-GW-7711" },
};

const observed_dolly_modules = [_]model.ModuleIdentity{
    .{ .kind = .abs, .manufacturer = "Vendor-D", .model = "DOLLY-ABS", .serial = "D-ABS-0440" },
};

// Trailer B kept its ABS ECU but its TPMS controller changed.
const observed_rear_modules = [_]model.ModuleIdentity{
    .{ .kind = .abs, .manufacturer = "Vendor-B", .model = "ABS-4S2M", .serial = "B-ABS-5008" },
    .{ .kind = .tpms, .manufacturer = "Vendor-T", .model = "TPMS-8", .serial = "B-TPMS-9001" },
};

pub const observed_doubles = [_]model.EquipmentSnapshot{
    .{
        .observed_name = "observed unit 1",
        .unit_class = .semitrailer,
        .position = .lead,
        .modules = &observed_lead_modules,
    },
    .{
        .observed_name = "observed unit 2",
        .unit_class = .converter_dolly,
        .position = .dolly,
        .modules = &observed_dolly_modules,
    },
    .{
        .observed_name = "observed unit 3",
        .unit_class = .semitrailer,
        .position = .rear,
        .modules = &observed_rear_modules,
    },
};

// A deliberately difficult case: same fleet specification, but no serial
// survives. The engine must not automatically merge it into Trailer A.
const fleet_twin_modules = [_]model.ModuleIdentity{
    .{ .kind = .abs, .manufacturer = "Vendor-A", .model = "ABS-4S2M", .serial = "TWIN-ABS-9991" },
    .{ .kind = .tpms, .manufacturer = "Vendor-T", .model = "TPMS-8", .serial = "TWIN-TPMS-9992" },
    .{ .kind = .gateway, .manufacturer = "Vendor-G", .model = "GATE-1", .serial = "TWIN-GW-9993" },
};

pub const fleet_twin = model.EquipmentSnapshot{
    .observed_name = "fleet-spec lookalike",
    .unit_class = .semitrailer,
    .position = .single,
    .modules = &fleet_twin_modules,
};
