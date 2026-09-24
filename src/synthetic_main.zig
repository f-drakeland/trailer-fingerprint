const std = @import("std");
const fingerprint = @import("fingerprint.zig");
const model = @import("fingerprint_model.zig");
const scenarios = @import("fingerprint_scenarios.zig");
const replay = @import("replay_scenarios.zig");
const normalizer = @import("normalizer.zig");
const report = @import("fingerprint_report.zig");

pub fn main() !void {
    std.debug.print(
        \\TFS - Trailer Fingerprint Software - experimental physical-equipment matcher
        \\Pipeline: synthetic discovery replay -> normalization -> fingerprinting
        \\Fictional profiles and observations; recognition is not field-validated.
        \\
    , .{});

    var matches: [replay.doubles_capture.len]model.ProfileMatch = undefined;

    for (replay.doubles_capture, 0..) |discovered, index| {
        report.printDiscovery(discovered);
        const normalized = try normalizer.normalize(discovered);
        const observed = normalized.snapshot();
        const result = fingerprint.matchEquipment(observed, &scenarios.known_profiles);
        matches[index] = result;
        report.printUnit(observed, result, &scenarios.known_profiles);
    }

    const consist = fingerprint.summarizeConsist(&matches);
    report.printConsist(consist);

    report.printDiscovery(replay.fleet_twin_capture);
    const twin_normalized = try normalizer.normalize(replay.fleet_twin_capture);
    const twin = twin_normalized.snapshot();
    report.printUnit(
        twin,
        fingerprint.matchEquipment(twin, &scenarios.known_profiles),
        &scenarios.known_profiles,
    );
}
