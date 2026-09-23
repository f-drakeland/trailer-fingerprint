const std = @import("std");
const fingerprint = @import("fingerprint.zig");
const model = @import("fingerprint_model.zig");
const discovery = @import("discovery.zig");

pub fn printHeader() void {
    std.debug.print(
        \\Trailer Fingerprint codename - equipment fingerprint engine v0.2
        \\Pipeline: synthetic discovery replay -> normalization -> fingerprinting
        \\No raw J2497 capture is decoded yet.
        \\
    , .{});
}

pub fn printDiscovery(unit: discovery.DiscoveredUnit) void {
    std.debug.print("Discovery observations:\n", .{});
    if (unit.vin) |vin| {
        std.debug.print("  unit VIN observed: {s}\n", .{vin});
    }
    for (unit.modules) |module| {
        std.debug.print("  {s}: {s}", .{ module.identity.kind.label(), module.source.label() });
        if (module.endpoint) |endpoint| {
            std.debug.print(" ({s})", .{endpoint});
        }
        if (module.endpoint_mid) |mid| {
            std.debug.print(" (MID {})", .{mid});
        }
        if (module.identity.software) |software| {
            std.debug.print(" software={s}", .{software});
        }
        std.debug.print("\n", .{});
    }
}


pub fn printDistanceTelemetry(samples: []const @import("j1587.zig").TotalVehicleDistance) void {
    if (samples.len == 0) return;

    std.debug.print("Non-identity telemetry:\n", .{});
    for (samples) |sample| {
        std.debug.print(
            "  MID {} total vehicle distance: {d:.3} mi ({d:.3} km)\n",
            .{ sample.source_mid, sample.miles, sample.kilometers },
        );
    }
    std.debug.print("  Note: telemetry is retained as history, not used as an identity anchor.\n", .{});
}

pub fn printUnit(
    observed: model.EquipmentSnapshot,
    result: model.ProfileMatch,
    profiles: []const model.EquipmentProfile,
) void {
    std.debug.print("{s} ({s}, {s})\n", .{
        observed.observed_name,
        observed.unit_class.label(),
        observed.position.label(),
    });
    std.debug.print("Decision: {s}\n", .{result.status.label()});

    if (result.profile_id) |profile_id| {
        std.debug.print("Historical profile: {s}\n", .{profile_id});
    } else {
        std.debug.print("Historical profile: none assigned\n", .{});
    }

    std.debug.print("Surviving module serial anchors: {}\n", .{result.evidence.exact_module_serials});
    std.debug.print("Same-model replacement candidates: {}\n", .{result.evidence.replacement_candidates});
    std.debug.print("Observed modules: {}\n", .{result.evidence.observed_modules});

    if (result.evidence.vin_match) {
        std.debug.print("VIN evidence: exact match\n", .{});
    } else if (result.evidence.vin_conflict) {
        std.debug.print("VIN evidence: CONFLICT\n", .{});
    } else {
        std.debug.print("VIN evidence: unavailable / unused\n", .{});
    }

    if (result.profile_index) |index| {
        const profile = profiles[index];
        std.debug.print("Anchor continuity:\n", .{});
        for (observed.modules) |module| {
            const continuity = fingerprint.moduleContinuity(module, profile);
            std.debug.print("  {s}: {s} [{s}]\n", .{
                module.kind.label(),
                continuity.label(),
                module.serial,
            });
        }
    }

    if (result.tied_best_candidate) {
        std.debug.print("Warning: more than one historical profile fits equally well.\n", .{});
    }

    std.debug.print("\n", .{});
}

pub fn printConsist(summary: model.ConsistSummary) void {
    std.debug.print("Consist result: {s}\n", .{summary.status().label()});
    std.debug.print("Units observed: {}\n", .{summary.total_units});
    std.debug.print("Recognized: {}\n", .{summary.recognized});
    std.debug.print("Probable: {}\n", .{summary.probable});
    std.debug.print("Ambiguous: {}\n", .{summary.ambiguous});
    std.debug.print("New: {}\n", .{summary.new_units});
    std.debug.print("Identity conflicts: {}\n", .{summary.conflicts});
    std.debug.print("Insufficient identity: {}\n\n", .{summary.insufficient_identity});
}
