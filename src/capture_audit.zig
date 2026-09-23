//! Conservative inspection of external checksum-stripped J1708 records.
//! Source observations, request destinations and identity evidence stay separate.
//! Supports single-parameter records; unsupported/ambiguous records never become
//! identities. This is not a checksum validator or a J1939 decoder.
const std = @import("std");
const loader = @import("external_log_loader.zig");
const capture_loader = @import("capture_loader.zig");
const j1587 = @import("j1587.zig");

pub const Audit = struct {
    records: usize = 0,
    quarantined: usize = 0,
    ignored_lines: usize = 0,
    unsupported: usize = 0,
    requests: usize = 0,
    vendor_escape: usize = 0,
    source_records: [256]usize = [_]usize{0} ** 256,
    request_targets: [256]usize = [_]usize{0} ** 256,
    requested_pids: [512]usize = [_]usize{0} ** 512,
    parameters: [256]usize = [_]usize{0} ** 256,
    // Only supported identity/telemetry frames reach the existing bounded ingest.
    capture: capture_loader.Capture = .{},

    fn observe(self: *Audit, frame: capture_loader.Frame) !void {
        const raw = frame.bytes[0..frame.len];
        if (raw.len < 3 or raw[0] < 128) {
            self.quarantined += 1;
            return;
        }
        const source = raw[0];
        const pid = raw[1];
        if (pid == 128 or (pid == 255 and raw[2] == 128)) {
            const extended = pid == 255;
            const expected: usize = if (extended) 5 else 4;
            if (raw.len != expected) {
                self.quarantined += 1;
                return;
            }
            const requested: usize = if (extended) 256 + @as(usize, raw[3]) else raw[2];
            self.source_records[source] += 1;
            self.requests += 1;
            self.request_targets[raw[expected - 1]] += 1;
            self.requested_pids[requested] += 1;
            return;
        }
        if (pid == 254) {
            // The third byte is a destination MID, not a length or serial.
            self.source_records[source] += 1;
            self.vendor_escape += 1;
            self.parameters[pid] += 1;
            return;
        }
        if (pid == 255) {
            self.unsupported += 1;
            return;
        }
        const expected: usize = if (pid < 128) 3 else if (pid < 192) 4 else 3 + @as(usize, raw[2]);
        if (raw.len != expected) {
            // Includes combined parameters; this audit deliberately supports only
            // one parameter per record and cannot safely split unknown formats.
            self.quarantined += 1;
            return;
        }
        self.source_records[source] += 1;
        self.parameters[pid] += 1;
        switch (pid) {
            192, 234, 237, 243, 245 => {
                _ = try j1587.parseMessage(raw);
                if (self.capture.frame_count == capture_loader.max_frames) return error.TooManyFrames;
                self.capture.frames[self.capture.frame_count] = frame;
                self.capture.frame_count += 1;
            },
            else => self.unsupported += 1,
        }
    }
};

pub fn inspect(text: []const u8) !Audit {
    var result = Audit{};
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const frame = loader.parseRecord(line) catch |err| {
            if (err == error.UnsupportedTransport) return err;
            result.records += 1;
            result.quarantined += 1;
            continue;
        };
        if (frame) |record| {
            result.records += 1;
            try result.observe(record);
        } else if (std.mem.trim(u8, line, " \t\r").len > 0) {
            result.ignored_lines += 1;
        }
    }
    if (result.records == 0) return error.NoFrames;
    return result;
}

pub fn print(audit: *const Audit) void {
    std.debug.print("Record audit: {d} records; {d} quarantined; {d} unsupported parameters; {d} ignored lines\n", .{
        audit.records, audit.quarantined, audit.unsupported, audit.ignored_lines,
    });
    std.debug.print("Directed requests: {d}; vendor escape records: {d}\n", .{ audit.requests, audit.vendor_escape });
    std.debug.print("MID 137: {d} requests addressed to it; {d} source records observed\n", .{ audit.request_targets[137], audit.source_records[137] });
    if (audit.request_targets[137] > 0 and audit.source_records[137] == 0) {
        std.debug.print("MID 137 queried; no response observed.\n", .{});
    }
    std.debug.print("Supported identity/telemetry frames: {d}. Input assumes removed checksums; capture setup remains unverified.\n", .{audit.capture.frame_count});
}

test "authentic excerpt distinguishes requested MID 137 from responding sources" {
    const audit = try inspect(@embedFile("fixtures/nov4thhardstop-excerpt.j1708log"));
    try std.testing.expectEqual(@as(usize, 20), audit.records);
    try std.testing.expectEqual(@as(usize, 15), audit.requests);
    try std.testing.expectEqual(@as(usize, 3), audit.request_targets[137]);
    try std.testing.expectEqual(@as(usize, 0), audit.source_records[137]);
    try std.testing.expectEqual(@as(usize, 2), audit.source_records[139]);
    try std.testing.expectEqual(@as(usize, 5), audit.requested_pids[245]);
    try std.testing.expectEqual(@as(usize, 5), audit.requested_pids[194]);
    try std.testing.expectEqual(@as(usize, 5), audit.requested_pids[409]);
    try std.testing.expectEqual(@as(usize, 3), audit.quarantined);
    try std.testing.expectEqual(@as(usize, 0), audit.capture.frame_count);
}

test "CAN fixture is rejected rather than interpreted as J1587" {
    try std.testing.expectError(error.UnsupportedTransport, inspect(@embedFile("fixtures/candump-excerpt.log")));
}

test "request target bytes and opaque escape data cannot manufacture identities" {
    const audit = try inspect("88 80 F3 89\n88 FF 80 ED 89\n89 FE AC 01\n89 80 89\n");
    try std.testing.expectEqual(@as(usize, 2), audit.request_targets[137]);
    try std.testing.expectEqual(@as(usize, 1), audit.vendor_escape);
    try std.testing.expectEqual(@as(usize, 1), audit.quarantined);
    try std.testing.expectEqual(@as(usize, 0), audit.capture.frame_count);
}

test "more than 128 background records do not exhaust the identity buffer" {
    const audit = try inspect("(1.0) j1708 8880f589\n" ** 625);
    try std.testing.expectEqual(@as(usize, 625), audit.requests);
    try std.testing.expectEqual(@as(usize, 0), audit.capture.frame_count);
}

test "quarantined records do not prevent a later valid identity parameter" {
    const audit = try inspect("(1.0) j1708 6400\n(2.0) j1708 zz\n(3.0) j1708 89EA0653572D322E31\n");
    try std.testing.expectEqual(@as(usize, 2), audit.quarantined);
    try std.testing.expectEqual(@as(usize, 1), audit.capture.frame_count);
}
