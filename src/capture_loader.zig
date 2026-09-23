//! Simple, explicit replay-file loader for checksum-stripped J1708/J1587 frames.
//!
//! This is intentionally not a vendor capture format. It is Trailer Fingerprint's small
//! interchange format between future capture/conversion tools and the protocol
//! ingest pipeline. One frame is written as hex bytes per line.

const std = @import("std");
const model = @import("fingerprint_model.zig");

pub const max_frames = 128;
// J1708 permits 21 bytes including the checksum. This loader begins after
// checksum handling, so a stored replay frame is at most 20 bytes.
pub const max_frame_bytes = 20;

pub const CaptureError = error{
    NoFrames,
    TooManyFrames,
    FrameTooLong,
    FrameTooShort,
    InvalidHex,
    InvalidClass,
    InvalidPosition,
};

pub const Frame = struct {
    bytes: [max_frame_bytes]u8 = [_]u8{0} ** max_frame_bytes,
    len: usize = 0,
};

pub const Capture = struct {
    name: []const u8 = "unnamed capture",
    unit_class: model.UnitClass = .unknown,
    position: model.Position = .unknown,
    frames: [max_frames]Frame = [_]Frame{.{}} ** max_frames,
    frame_count: usize = 0,

    pub fn messageSlices(
        self: *const Capture,
        out: *[max_frames][]const u8,
    ) []const []const u8 {
        for (self.frames[0..self.frame_count], 0..) |*frame, index| {
            out[index] = frame.bytes[0..frame.len];
        }
        return out[0..self.frame_count];
    }
};

pub fn parse(text: []const u8) CaptureError!Capture {
    var capture = Capture{};
    var lines = std.mem.splitScalar(u8, text, '\n');

    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        if (std.mem.startsWith(u8, line, "@name ")) {
            capture.name = std.mem.trim(u8, line[6..], " \t");
            continue;
        }
        if (std.mem.startsWith(u8, line, "@class ")) {
            capture.unit_class = try parseClass(std.mem.trim(u8, line[7..], " \t"));
            continue;
        }
        if (std.mem.startsWith(u8, line, "@position ")) {
            capture.position = try parsePosition(std.mem.trim(u8, line[10..], " \t"));
            continue;
        }

        if (capture.frame_count >= max_frames) return error.TooManyFrames;
        capture.frames[capture.frame_count] = try parseFrame(line);
        capture.frame_count += 1;
    }

    if (capture.frame_count == 0) return error.NoFrames;
    return capture;
}

fn parseFrame(line: []const u8) CaptureError!Frame {
    var frame = Frame{};
    var tokens = std.mem.tokenizeAny(u8, line, " \t");

    while (tokens.next()) |token| {
        if (token.len != 2) return error.InvalidHex;
        if (frame.len >= max_frame_bytes) return error.FrameTooLong;

        frame.bytes[frame.len] = std.fmt.parseInt(u8, token, 16) catch return error.InvalidHex;
        frame.len += 1;
    }

    if (frame.len < 3) return error.FrameTooShort;
    return frame;
}

fn parseClass(value: []const u8) CaptureError!model.UnitClass {
    if (std.mem.eql(u8, value, "semitrailer")) return .semitrailer;
    if (std.mem.eql(u8, value, "converter_dolly")) return .converter_dolly;
    if (std.mem.eql(u8, value, "unknown")) return .unknown;
    return error.InvalidClass;
}

fn parsePosition(value: []const u8) CaptureError!model.Position {
    if (std.mem.eql(u8, value, "lead")) return .lead;
    if (std.mem.eql(u8, value, "dolly")) return .dolly;
    if (std.mem.eql(u8, value, "rear")) return .rear;
    if (std.mem.eql(u8, value, "single")) return .single;
    if (std.mem.eql(u8, value, "unknown")) return .unknown;
    return error.InvalidPosition;
}

test "capture text becomes protocol frames plus equipment metadata" {
    const text =
        \\# Trailer Fingerprint capture v1
        \\@name bench replay
        \\@class semitrailer
        \\@position single
        \\89 EA 06 53 57 2D 32 2E 31
        \\89 ED 11 31 44 45 4D 4F 30 30 30 30 30 30 30 30 30 30 30 31
    ;

    const capture = try parse(text);
    try std.testing.expectEqualStrings("bench replay", capture.name);
    try std.testing.expectEqual(model.UnitClass.semitrailer, capture.unit_class);
    try std.testing.expectEqual(model.Position.single, capture.position);
    try std.testing.expectEqual(@as(usize, 2), capture.frame_count);
    try std.testing.expectEqual(@as(u8, 0x89), capture.frames[0].bytes[0]);
    try std.testing.expectEqual(@as(u8, 0xea), capture.frames[0].bytes[1]);
}

test "bad capture hex is rejected before protocol ingest" {
    const text =
        \\@name broken
        \\89 EA ZZ
    ;
    try std.testing.expectError(error.InvalidHex, parse(text));
}

test "maximum checksum-stripped frame length is accepted" {
    const text =
        \\@name max legal frame
        \\89 ED 11 31 44 45 4D 4F 30 30 30 30 30 30 30 30 30 30 30 31
    ;

    const capture = try parse(text);
    try std.testing.expectEqual(@as(usize, 1), capture.frame_count);
    try std.testing.expectEqual(max_frame_bytes, capture.frames[0].len);
}

test "frame above checksum-stripped limit is rejected" {
    const text =
        \\@name too long
        \\89 ED 11 31 44 45 4D 4F 30 30 30 30 30 30 30 30 30 30 30 30 31
    ;

    try std.testing.expectError(error.FrameTooLong, parse(text));
}
