const std = @import("std");
const capture_audit = @import("capture_audit.zig");
const capture_loader = @import("capture_loader.zig");
const external_log_loader = @import("external_log_loader.zig");
const fingerprint = @import("fingerprint.zig");
const j1587 = @import("j1587.zig");
const multisection = @import("j1587_multisection.zig");
const normalizer = @import("normalizer.zig");
const protocol_ingest = @import("protocol_ingest.zig");
const report = @import("fingerprint_report.zig");
const scenarios = @import("protocol_scenarios.zig");

const default_captures = [_][]const u8{
    "captures/current_trailer.tfc",
    "captures/current_trailer_no_vin.tfc",
    "captures/fleet_twin.tfc",
    "captures/current_trailer_truckduck.log",
    "captures/public_pretty_j1587_sample.log",
    "src/fixtures/nov4thhardstop-excerpt.j1708log",
};

pub fn main(init: std.process.Init) !void {
    std.debug.print(
        \\Trailer Fingerprint codename - equipment fingerprint engine v0.11
        \\Pipeline: capture/log file -> J1708/J1587 -> PID 192 reassembly -> identity enrichment -> normalization -> fingerprinting
        \\.tfc files are Trailer Fingerprint interchange captures; .log/.txt can use common J1708 logger or Truck Duck text shapes.
        \\Input still begins AFTER J2497/PLC demodulation; no waveform decoder is claimed yet.
        \\Pass one or more files after `--`, or run with no arguments for the included corpus.
        \\
    , .{});

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 1) {
        for (args[1..]) |path| {
            try runCapture(init.io, init.gpa, path);
        }
        return;
    }

    for (default_captures) |path| {
        try runCapture(init.io, init.gpa, path);
    }
}

fn runCapture(io: std.Io, allocator: std.mem.Allocator, path: []const u8) !void {
    const contents = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(32 * 1024 * 1024));
    defer allocator.free(contents);

    var capture = if (isNativeCapture(path))
        try capture_loader.parse(contents)
    else blk: {
        const audit = capture_audit.inspect(contents) catch |err| {
            if (err == error.UnsupportedTransport) {
                std.debug.print("Unsupported transport: {s} contains SocketCAN frames. Use a J1939 analysis tool; CAN addresses are not J1587 MIDs.\n", .{path});
            }
            return err;
        };
        std.debug.print("Inspecting: {s}\n", .{path});
        capture_audit.print(&audit);
        break :blk audit.capture;
    };

    // External logs generally do not carry our metadata. Give the observation
    // a useful name while leaving class/position unknown rather than guessing.
    if (!isNativeCapture(path)) capture.name = path;

    var message_slices: [capture_loader.max_frames][]const u8 = undefined;
    const messages = capture.messageSlices(&message_slices);

    // Validate framing at the capture boundary before handing anything to the
    // multisection or identity layers. This makes malformed captures fail near
    // their source instead of surfacing as mysterious fingerprint behavior.
    for (messages) |message| {
        _ = try j1587.parseMessage(message);
    }

    var ingested = try protocol_ingest.ingestUnit(
        capture.name,
        capture.unit_class,
        capture.position,
        messages,
    );
    const discovered = ingested.discoveredUnit();

    std.debug.print("Capture: {s}\n", .{path});
    report.printDiscovery(discovered);
    report.printDistanceTelemetry(ingested.distanceSamples());

    const normalized = try normalizer.normalize(discovered);
    const snapshot = normalized.snapshot();
    report.printUnit(
        snapshot,
        fingerprint.matchEquipment(snapshot, &scenarios.known_profiles),
        &scenarios.known_profiles,
    );
}

fn isNativeCapture(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".tfc");
}

test "capture file parser feeds the real ingest and fingerprint path" {
    const text =
        \\@name in-memory known trailer
        \\@class semitrailer
        \\@position single
        \\89 EA 06 53 57 2D 32 2E 31
        \\89 C0 11 F3 10 18 89 44 45 4D 4F 20 2A 41 42 53 2D 34 53 32
        \\A7 C0 11 F3 10 17 A7 44 45 4D 4F 20 2A 54 50 4D 53 2D 38 2A
        \\89 ED 11 31 44 45 4D 4F 30 30 30 30 30 30 30 30 30 30 30 31
        \\89 C0 0C F3 11 4D 2A 41 42 53 2D 32 30 39 39
        \\A7 C0 0B F3 11 54 50 4D 53 2D 32 32 30 37
    ;

    var capture = try capture_loader.parse(text);
    var message_slices: [capture_loader.max_frames][]const u8 = undefined;
    const messages = capture.messageSlices(&message_slices);

    var ingested = try protocol_ingest.ingestUnit(
        capture.name,
        capture.unit_class,
        capture.position,
        messages,
    );
    const normalized = try normalizer.normalize(ingested.discoveredUnit());
    const snapshot = normalized.snapshot();
    const matched = fingerprint.matchEquipment(snapshot, &scenarios.known_profiles);

    try std.testing.expectEqual(@import("fingerprint_model.zig").MatchStatus.recognized, matched.status);
    try std.testing.expectEqualStrings("PROTO-TRAILER-A", matched.profile_id.?);
}

test "external logger text feeds the same ingest and fingerprint path" {
    const text =
        \\(1000.000) j1708 89EA0653572D322E31 ; SW-2.1
        \\(1000.010) j1708 89C011F310188944454D4F202A4142532D345332
        \\(1000.020) j1708 A7C011F31017A744454D4F202A54504D532D382A
        \\(1000.030) j1708 89ED113144454D4F303030303030303030303031
        \\(1000.040) j1708 89C00CF3114D2A4142532D32303939
        \\(1000.050) j1708 A7C00BF31154504D532D32323037
    ;

    var capture = try external_log_loader.parse(text);
    var message_slices: [capture_loader.max_frames][]const u8 = undefined;
    const messages = capture.messageSlices(&message_slices);

    var ingested = try protocol_ingest.ingestUnit(
        "external-log-test",
        .unknown,
        .unknown,
        messages,
    );
    const normalized = try normalizer.normalize(ingested.discoveredUnit());
    const snapshot = normalized.snapshot();
    const matched = fingerprint.matchEquipment(snapshot, &scenarios.known_profiles);

    try std.testing.expectEqual(@import("fingerprint_model.zig").MatchStatus.recognized, matched.status);
    try std.testing.expectEqualStrings("PROTO-TRAILER-A", matched.profile_id.?);
}

test "pretty_j1587 public sample reaches telemetry without inventing identity" {
    const text =
        \\MSG: [0x89,0xf5,0x4,0xe1,0x0,0x0,0x0]
    ;

    var capture = try external_log_loader.parse(text);
    var message_slices: [capture_loader.max_frames][]const u8 = undefined;
    const messages = capture.messageSlices(&message_slices);

    var ingested = try protocol_ingest.ingestUnit(
        "public-pretty-j1587-sample",
        .unknown,
        .unknown,
        messages,
    );
    const normalized = try normalizer.normalize(ingested.discoveredUnit());
    const snapshot = normalized.snapshot();
    const matched = fingerprint.matchEquipment(snapshot, &scenarios.known_profiles);

    try std.testing.expectEqual(@as(usize, 1), ingested.distanceSamples().len);
    try std.testing.expectEqual(@import("fingerprint_model.zig").MatchStatus.insufficient_identity, matched.status);
}

test {
    _ = capture_audit;
    _ = capture_loader;
    _ = external_log_loader;
    _ = fingerprint;
    _ = j1587;
    _ = multisection;
    _ = normalizer;
    _ = protocol_ingest;
}

test "authentic request-only excerpt yields insufficient identity through full pipeline" {
    var audit = try capture_audit.inspect(@embedFile("fixtures/nov4thhardstop-excerpt.j1708log"));
    var slices: [capture_loader.max_frames][]const u8 = undefined;
    var ingested = try protocol_ingest.ingestUnit("research excerpt", .unknown, .unknown, audit.capture.messageSlices(&slices));
    try std.testing.expectEqual(@as(usize, 0), ingested.module_count);
    try std.testing.expectEqual(@as(usize, 0), ingested.endpoint_count);
    try std.testing.expectEqual(@as(usize, 0), ingested.distance_count);
    try std.testing.expect(ingested.vin == null);
    const normalized = try normalizer.normalize(ingested.discoveredUnit());
    const matched = fingerprint.matchEquipment(normalized.snapshot(), &scenarios.known_profiles);
    try std.testing.expectEqual(@import("fingerprint_model.zig").MatchStatus.insufficient_identity, matched.status);
}
