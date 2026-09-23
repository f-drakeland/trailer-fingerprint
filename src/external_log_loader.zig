//! Adapter for common text logs produced around J1708/J1587 tooling.
//!
//! The fingerprint engine should not require a custom .tfc file once real
//! traffic becomes available. This loader accepts two common shapes used by
//! existing open tooling:
//!
//!   89,EA,06,53,57,2D,32,2E,31
//!   (123123123.123123) j1708 89EA0653572D322E31 ; optional comment
//!   MSG: [0x89,0xf5,0x4,0xe1,0x0,0x0,0x0]
//!
//! It intentionally stops at the J1708/J1587 message boundary. J2497 waveform
//! demodulation is still outside this project stage.

const std = @import("std");
const capture_loader = @import("capture_loader.zig");

pub const ExternalLogError = capture_loader.CaptureError || error{
    OddHexDigitCount,
};

pub fn parse(text: []const u8) ExternalLogError!capture_loader.Capture {
    var capture = capture_loader.Capture{
        .name = "external J1708 log",
        .unit_class = .unknown,
        .position = .unknown,
    };

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        if (capture.frame_count >= capture_loader.max_frames) return error.TooManyFrames;

        const frame = if (prettyMsgPayload(line)) |payload|
            try parsePrettyPayload(payload)
        else if (payloadSlice(line)) |payload|
            try parsePayload(payload)
        else
            continue;
        // Real-world logs may contain non-J1587 chatter or truncated lines.
        // Keep the import boundary strict enough that downstream parsing does
        // not receive impossible frames.
        if (frame.len < 3) return error.FrameTooShort;

        capture.frames[capture.frame_count] = frame;
        capture.frame_count += 1;
    }

    if (capture.frame_count == 0) return error.NoFrames;
    return capture;
}

fn prettyMsgPayload(line: []const u8) ?[]const u8 {
    if (std.mem.indexOf(u8, line, "MSG:")) |index| {
        const rest = line[index + "MSG:".len ..];
        const open = std.mem.indexOfScalar(u8, rest, '[') orelse return null;
        const after_open = rest[open + 1 ..];
        const close = std.mem.indexOfScalar(u8, after_open, ']') orelse return null;
        return after_open[0..close];
    }
    return null;
}

fn parsePrettyPayload(payload: []const u8) ExternalLogError!capture_loader.Frame {
    var frame = capture_loader.Frame{};
    var tokens = std.mem.splitScalar(u8, payload, ',');

    while (tokens.next()) |raw_token| {
        var token = std.mem.trim(u8, raw_token, " \t");
        if (token.len == 0) continue;

        if (token.len >= 2 and token[0] == '0' and (token[1] == 'x' or token[1] == 'X')) {
            token = token[2..];
        }
        if (token.len == 0 or token.len > 2) return error.InvalidHex;

        var value: u8 = 0;
        for (token) |ch| {
            if (!std.ascii.isHex(ch)) return error.InvalidHex;
            value = (value << 4) | hexNibble(ch);
        }

        if (frame.len >= capture_loader.max_frame_bytes) return error.FrameTooLong;
        frame.bytes[frame.len] = value;
        frame.len += 1;
    }

    return frame;
}

fn payloadSlice(line: []const u8) ?[]const u8 {
    // Truck Duck / pretty_j1587 documented style:
    // (timestamp) j1708 HEXBYTES ; comment
    if (std.mem.indexOf(u8, line, "j1708")) |index| {
        var rest = trimLeadingAny(line[index + "j1708".len ..], " \t:=");
        if (std.mem.indexOfScalar(u8, rest, ';')) |comment_index| {
            rest = rest[0..comment_index];
        }
        return std.mem.trim(u8, rest, " \t");
    }

    // Plain logger style: a line consisting of hex bytes separated by commas,
    // spaces, colons, dashes, or no delimiter at all.
    const first = line[0];
    if (!std.ascii.isHex(first)) return null;

    if (std.mem.indexOfScalar(u8, line, ';')) |comment_index| {
        return std.mem.trim(u8, line[0..comment_index], " \t");
    }
    return line;
}

fn trimLeadingAny(input: []const u8, chars: []const u8) []const u8 {
    var start: usize = 0;
    while (start < input.len and containsByte(chars, input[start])) : (start += 1) {}
    return input[start..];
}

fn containsByte(haystack: []const u8, needle: u8) bool {
    for (haystack) |ch| {
        if (ch == needle) return true;
    }
    return false;
}

fn parsePayload(payload: []const u8) ExternalLogError!capture_loader.Frame {
    var frame = capture_loader.Frame{};
    var high_nibble: ?u8 = null;

    var index: usize = 0;
    while (index < payload.len) : (index += 1) {
        const ch = payload[index];

        if (std.ascii.isHex(ch)) {
            const nibble = hexNibble(ch);
            if (high_nibble) |high| {
                if (frame.len >= capture_loader.max_frame_bytes) return error.FrameTooLong;
                frame.bytes[frame.len] = (high << 4) | nibble;
                frame.len += 1;
                high_nibble = null;
            } else {
                high_nibble = nibble;
            }
            continue;
        }

        switch (ch) {
            ' ', '\t', ',', ':', '-', '_' => {},
            else => return error.InvalidHex,
        }
    }

    if (high_nibble != null) return error.OddHexDigitCount;
    return frame;
}

fn hexNibble(ch: u8) u8 {
    return if (ch >= '0' and ch <= '9')
        ch - '0'
    else if (ch >= 'a' and ch <= 'f')
        ch - 'a' + 10
    else
        ch - 'A' + 10;
}

test "plain comma-delimited logger output becomes frames" {
    const text =
        \\89,EA,06,53,57,2D,32,2E,31
        \\A7,ED,11,31,44,45,4D,4F,30,30,30,30,30,30,30,30,30,30,30,31
    ;

    const capture = try parse(text);
    try std.testing.expectEqual(@as(usize, 2), capture.frame_count);
    try std.testing.expectEqual(@as(u8, 0x89), capture.frames[0].bytes[0]);
    try std.testing.expectEqual(@as(u8, 0xea), capture.frames[0].bytes[1]);
}

test "Truck Duck style timestamp and comments are ignored" {
    const text =
        \\(123123123.123123) j1708 89EA0653572D322E31 ; software id
        \\(123123124.000000) j1708 A7ED113144454D4F303030303030303030303031 ; VIN
    ;

    const capture = try parse(text);
    try std.testing.expectEqual(@as(usize, 2), capture.frame_count);
    try std.testing.expectEqual(@as(usize, 9), capture.frames[0].len);
}

test "compact maximum checksum-stripped frame length is accepted" {
    const text =
        \\(1.0) j1708 89ED113144454D4F303030303030303030303031
    ;

    const capture = try parse(text);
    try std.testing.expectEqual(@as(usize, 1), capture.frame_count);
    try std.testing.expectEqual(capture_loader.max_frame_bytes, capture.frames[0].len);
}

test "compact frame above checksum-stripped limit is rejected" {
    const text =
        \\(1.0) j1708 89ED113144454D4F30303030303030303030303031
    ;

    try std.testing.expectError(error.FrameTooLong, parse(text));
}

test "pretty_j1587 MSG output becomes a frame" {
    const text =
        \\MSG: [0x89,0xf5,0x4,0xe1,0x0,0x0,0x0]
    ;

    const capture = try parse(text);
    try std.testing.expectEqual(@as(usize, 1), capture.frame_count);
    try std.testing.expectEqual(@as(usize, 7), capture.frames[0].len);
    try std.testing.expectEqual(@as(u8, 0x89), capture.frames[0].bytes[0]);
    try std.testing.expectEqual(@as(u8, 0xf5), capture.frames[0].bytes[1]);
}

test "header lines are tolerated" {
    const text =
        \\Truck Duck capture started
        \\interface: plc
        \\(1.0) j1708 89EA0653572D322E31
    ;
    const capture = try parse(text);
    try std.testing.expectEqual(@as(usize, 1), capture.frame_count);
}

test "odd number of hex digits is rejected" {
    try std.testing.expectError(error.OddHexDigitCount, parse("89EA0\n"));
}
