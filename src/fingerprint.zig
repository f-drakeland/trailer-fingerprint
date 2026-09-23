const std = @import("std");
const model = @import("fingerprint_model.zig");

const Candidate = struct {
    profile_index: usize,
    rank: i32,
    evidence: model.MatchEvidence,
};

pub fn matchEquipment(
    observed: model.EquipmentSnapshot,
    profiles: []const model.EquipmentProfile,
) model.ProfileMatch {
    if (observed.vin == null and observed.modules.len == 0) {
        return .{
            .status = .insufficient_identity,
            .observed_name = observed.observed_name,
            .profile_id = null,
            .evidence = .{ .observed_modules = 0 },
            .profile_index = null,
        };
    }
    if (profiles.len == 0) {
        return .{
            .status = .new_profile,
            .observed_name = observed.observed_name,
            .profile_id = null,
            .evidence = .{ .observed_modules = observed.modules.len },
            .profile_index = null,
        };
    }

    var best: ?Candidate = null;
    var tied_best = false;

    for (profiles, 0..) |profile, index| {
        if (profile.unit_class != observed.unit_class and
            profile.unit_class != .unknown and
            observed.unit_class != .unknown)
        {
            continue;
        }

        const candidate = compareProfile(observed, profile, index);

        if (best == null or candidate.rank > best.?.rank) {
            best = candidate;
            tied_best = false;
        } else if (candidate.rank == best.?.rank) {
            tied_best = true;
        }
    }

    const winner = best orelse {
        return .{
            .status = .new_profile,
            .observed_name = observed.observed_name,
            .profile_id = null,
            .evidence = .{ .observed_modules = observed.modules.len },
            .profile_index = null,
        };
    };

    const profile = profiles[winner.profile_index];
    var status = classify(winner.evidence);

    // If two historical profiles fit equally well, do not pretend we know
    // which physical unit is present.
    if (tied_best and status != .identity_conflict) {
        status = .ambiguous;
    }

    return .{
        .status = status,
        .observed_name = observed.observed_name,
        .profile_id = if (status == .new_profile) null else profile.profile_id,
        .evidence = winner.evidence,
        .tied_best_candidate = tied_best,
        .profile_index = if (status == .new_profile) null else winner.profile_index,
    };
}

fn compareProfile(
    observed: model.EquipmentSnapshot,
    profile: model.EquipmentProfile,
    profile_index: usize,
) Candidate {
    var evidence = model.MatchEvidence{
        .observed_modules = observed.modules.len,
        .known_modules = profile.modules.len,
    };

    if (observed.vin) |observed_vin| {
        if (profile.vin) |known_vin| {
            if (std.mem.eql(u8, observed_vin, known_vin)) {
                evidence.vin_match = true;
            } else {
                evidence.vin_conflict = true;
            }
        }
    }

    for (observed.modules) |observed_module| {
        var saw_same_model = false;

        for (profile.modules) |known_module| {
            if (observed_module.kind != known_module.kind) continue;

            if (sameModuleSerial(observed_module, known_module)) {
                evidence.exact_module_serials += 1;
                saw_same_model = false;
                break;
            }

            if (sameModuleModel(observed_module, known_module)) {
                saw_same_model = true;
            }
        }

        if (saw_same_model) evidence.replacement_candidates += 1;
    }

    // Internal ordering only. These numbers are intentionally not presented as
    // confidence percentages to users.
    var rank: i32 = 0;
    if (evidence.vin_conflict) rank -= 10_000;
    if (evidence.vin_match) rank += 2_000;
    rank += @as(i32, @intCast(evidence.exact_module_serials)) * 100;
    rank += @as(i32, @intCast(evidence.replacement_candidates)) * 10;

    return .{
        .profile_index = profile_index,
        .rank = rank,
        .evidence = evidence,
    };
}

fn classify(evidence: model.MatchEvidence) model.MatchStatus {
    if (evidence.vin_conflict) return .identity_conflict;
    if (evidence.vin_match) return .recognized;

    // One surviving unique module serial can be a strong identity anchor.
    // Multiple surviving anchors make maintenance continuity much stronger.
    if (evidence.exact_module_serials >= 1) return .recognized;

    // Same-model replacements without any surviving serial are plausible
    // continuity, but identical fleet-spec trailers can look exactly like this.
    if (evidence.replacement_candidates >= 2) return .ambiguous;
    if (evidence.replacement_candidates == 1) return .probable_match;

    return .new_profile;
}

fn sameModuleSerial(a: model.ModuleIdentity, b: model.ModuleIdentity) bool {
    return a.kind == b.kind and
        std.mem.eql(u8, a.manufacturer, b.manufacturer) and
        std.mem.eql(u8, a.model, b.model) and
        std.mem.eql(u8, a.serial, b.serial);
}

fn sameModuleModel(a: model.ModuleIdentity, b: model.ModuleIdentity) bool {
    return a.kind == b.kind and
        std.mem.eql(u8, a.manufacturer, b.manufacturer) and
        std.mem.eql(u8, a.model, b.model);
}


pub const ModuleContinuity = enum {
    exact_serial,
    same_model_new_serial,
    unseen,

    pub fn label(self: ModuleContinuity) []const u8 {
        return switch (self) {
            .exact_serial => "surviving serial anchor",
            .same_model_new_serial => "same model, new serial",
            .unseen => "not previously observed",
        };
    }
};

pub fn moduleContinuity(
    observed_module: model.ModuleIdentity,
    profile: model.EquipmentProfile,
) ModuleContinuity {
    var same_model = false;

    for (profile.modules) |known_module| {
        if (observed_module.kind != known_module.kind) continue;
        if (sameModuleSerial(observed_module, known_module)) return .exact_serial;
        if (sameModuleModel(observed_module, known_module)) same_model = true;
    }

    return if (same_model) .same_model_new_serial else .unseen;
}

pub fn summarizeConsist(matches: []const model.ProfileMatch) model.ConsistSummary {
    var summary = model.ConsistSummary{ .total_units = matches.len };

    for (matches) |match| {
        switch (match.status) {
            .recognized => summary.recognized += 1,
            .probable_match => summary.probable += 1,
            .ambiguous => summary.ambiguous += 1,
            .new_profile => summary.new_units += 1,
            .identity_conflict => summary.conflicts += 1,
            .insufficient_identity => summary.insufficient_identity += 1,
        }
    }

    return summary;
}

test "telemetry-only observation is not misclassified as a new identity" {
    const profiles = [_]model.EquipmentProfile{};
    const modules = [_]model.ModuleIdentity{};
    const result = matchEquipment(.{
        .observed_name = "telemetry-only",
        .unit_class = .unknown,
        .modules = &modules,
    }, &profiles);

    try std.testing.expectEqual(model.MatchStatus.insufficient_identity, result.status);
}

test "surviving modules preserve identity after an ABS replacement" {
    const known_modules = [_]model.ModuleIdentity{
        .{ .kind = .abs, .manufacturer = "VendorA", .model = "ABS-4S2M", .serial = "ABS-OLD" },
        .{ .kind = .tpms, .manufacturer = "VendorT", .model = "TPMS-1", .serial = "TP-777" },
        .{ .kind = .gateway, .manufacturer = "VendorG", .model = "GW-1", .serial = "GW-888" },
    };
    const observed_modules = [_]model.ModuleIdentity{
        .{ .kind = .abs, .manufacturer = "VendorA", .model = "ABS-4S2M", .serial = "ABS-NEW" },
        .{ .kind = .tpms, .manufacturer = "VendorT", .model = "TPMS-1", .serial = "TP-777" },
        .{ .kind = .gateway, .manufacturer = "VendorG", .model = "GW-1", .serial = "GW-888" },
    };
    const profiles = [_]model.EquipmentProfile{
        .{ .profile_id = "P-1", .unit_class = .semitrailer, .modules = &known_modules },
    };

    const result = matchEquipment(.{
        .observed_name = "lead",
        .unit_class = .semitrailer,
        .modules = &observed_modules,
    }, &profiles);

    try std.testing.expectEqual(model.MatchStatus.recognized, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.evidence.exact_module_serials);
    try std.testing.expectEqual(@as(usize, 1), result.evidence.replacement_candidates);
}

test "identical fleet specification without surviving serials is ambiguous" {
    const known_modules = [_]model.ModuleIdentity{
        .{ .kind = .abs, .manufacturer = "VendorA", .model = "ABS-X", .serial = "1" },
        .{ .kind = .tpms, .manufacturer = "VendorT", .model = "TPMS-X", .serial = "2" },
    };
    const observed_modules = [_]model.ModuleIdentity{
        .{ .kind = .abs, .manufacturer = "VendorA", .model = "ABS-X", .serial = "9" },
        .{ .kind = .tpms, .manufacturer = "VendorT", .model = "TPMS-X", .serial = "8" },
    };
    const profiles = [_]model.EquipmentProfile{
        .{ .profile_id = "P-1", .unit_class = .semitrailer, .modules = &known_modules },
    };

    const result = matchEquipment(.{
        .observed_name = "unknown",
        .unit_class = .semitrailer,
        .modules = &observed_modules,
    }, &profiles);

    try std.testing.expectEqual(model.MatchStatus.ambiguous, result.status);
}

test "conflicting VIN is never silently merged" {
    const known_modules = [_]model.ModuleIdentity{
        .{ .kind = .abs, .manufacturer = "VendorA", .model = "ABS-X", .serial = "1" },
    };
    const profiles = [_]model.EquipmentProfile{
        .{ .profile_id = "P-1", .unit_class = .semitrailer, .vin = "VIN-ONE", .modules = &known_modules },
    };

    const result = matchEquipment(.{
        .observed_name = "unknown",
        .unit_class = .semitrailer,
        .vin = "VIN-TWO",
        .modules = &known_modules,
    }, &profiles);

    try std.testing.expectEqual(model.MatchStatus.identity_conflict, result.status);
}
