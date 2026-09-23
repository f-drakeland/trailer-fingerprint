//! Converts discovery-backend observations into the stable representation used
//! by the fingerprint engine.
//!
//! No allocator is needed for the current prototype. The normalized unit owns
//! a small fixed-capacity module array, which keeps the boundary simple while
//! we are still learning what real trailer networks expose.

const discovery = @import("discovery.zig");
const model = @import("fingerprint_model.zig");

pub const max_modules_per_unit = 12;

pub const NormalizeError = error{
    TooManyModules,
};

pub const NormalizedUnit = struct {
    observed_name: []const u8,
    unit_class: model.UnitClass,
    position: model.Position,
    vin: ?[]const u8,
    modules: [max_modules_per_unit]model.ModuleIdentity = undefined,
    module_count: usize = 0,

    pub fn snapshot(self: *const NormalizedUnit) model.EquipmentSnapshot {
        return .{
            .observed_name = self.observed_name,
            .unit_class = self.unit_class,
            .position = self.position,
            .vin = self.vin,
            .modules = self.modules[0..self.module_count],
        };
    }
};

pub fn normalize(unit: discovery.DiscoveredUnit) NormalizeError!NormalizedUnit {
    if (unit.modules.len > max_modules_per_unit) return error.TooManyModules;

    var result = NormalizedUnit{
        .observed_name = unit.observed_name,
        .unit_class = unit.unit_class,
        .position = unit.position,
        .vin = unit.vin,
    };

    for (unit.modules, 0..) |module, index| {
        result.modules[index] = module.identity;
    }
    result.module_count = unit.modules.len;

    return result;
}

test "normalizer preserves module identities" {
    const discovered_modules = [_]discovery.DiscoveredModule{
        .{
            .source = .synthetic_replay,
            .endpoint = "MID-136",
            .identity = .{
                .kind = .abs,
                .manufacturer = "Vendor-A",
                .model = "ABS-X",
                .serial = "SER-1",
            },
        },
    };

    const normalized = try normalize(.{
        .observed_name = "unit-1",
        .unit_class = .semitrailer,
        .modules = &discovered_modules,
    });

    const snapshot = normalized.snapshot();
    try @import("std").testing.expectEqual(@as(usize, 1), snapshot.modules.len);
    try @import("std").testing.expectEqualStrings("SER-1", snapshot.modules[0].serial);
}
