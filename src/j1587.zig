//! Minimal J1587 identity decoder for the equipment-fingerprint prototype.
//!
//! Input is a checksum-stripped J1708/J1587 message after J2497/PLC
//! demodulation. This module now understands the identity-related parameters
//! Trailer Fingerprint currently cares about:
//!   PID 192 - multisection transport
//!   PID 234 - software identification
//!   PID 237 - VIN
//!   PID 243 - component identification
//!   PID 245 - total vehicle distance (telemetry, not identity)
//!
//! PID 243 and long PID 234 values may exceed the J1708 packet limit, so the
//! multisection layer lives in j1587_multisection.zig.

const std = @import("std");
const discovery = @import("discovery.zig");
const model = @import("fingerprint_model.zig");

pub const pid_multisection: u8 = 192;
pub const pid_software_identification: u8 = 234;
pub const pid_vin: u8 = 237;
pub const pid_component_identification: u8 = 243;
pub const pid_total_vehicle_distance: u8 = 245;

pub const DecodeError = error{
    TooShort,
    UnsupportedPid,
    InvalidLength,
    MissingDelimiter,
    MissingComponentMid,
    EmptyVin,
};

pub const Message = struct {
    source_mid: u8,
    pid: u8,
    data: []const u8,
};

/// Parse one checksum-stripped, page-one variable-length PID (192..253).
/// Fixed-length requests and PID 254 escape data do not have this layout.
pub fn parseMessage(message: []const u8) DecodeError!Message {
    if (message.len < 3) return error.TooShort;

    if (message[1] < 192 or message[1] > 253) return error.UnsupportedPid;

    const data_count: usize = message[2];
    if (message.len != 3 + data_count) return error.InvalidLength;

    return .{
        .source_mid = message[0],
        .pid = message[1],
        .data = message[3..],
    };
}

pub const DecodedComponent = struct {
    source_mid: u8,
    component_mid: u8,
    manufacturer: []const u8,
    model_name: []const u8,
    serial: []const u8,

    pub fn discovered(self: DecodedComponent, software: ?[]const u8) discovery.DiscoveredModule {
        return .{
            .source = .j2497_j1708,
            .endpoint_mid = self.component_mid,
            .identity = .{
                .kind = kindFromMid(self.component_mid),
                .manufacturer = self.manufacturer,
                .model = self.model_name,
                .serial = self.serial,
                .software = software,
            },
        };
    }
};

/// Decode PID 243 parameter data. `data` is the original PID 243 data field,
/// not a PID 192 section wrapper.
pub fn decodeComponentData(source_mid: u8, data: []const u8) DecodeError!DecodedComponent {
    if (data.len < 2) return error.MissingComponentMid;

    const component_mid = data[0];
    const fields = data[1..];

    const first_delim = std.mem.indexOfScalar(u8, fields, '*') orelse return error.MissingDelimiter;
    const after_first = fields[first_delim + 1 ..];
    const second_rel = std.mem.indexOfScalar(u8, after_first, '*') orelse return error.MissingDelimiter;
    const second_delim = first_delim + 1 + second_rel;

    return .{
        .source_mid = source_mid,
        .component_mid = component_mid,
        .manufacturer = std.mem.trim(u8, fields[0..first_delim], " "),
        .model_name = fields[first_delim + 1 .. second_delim],
        .serial = fields[second_delim + 1 ..],
    };
}

pub fn decodeComponentIdentification(message: []const u8) DecodeError!DecodedComponent {
    const parsed = try parseMessage(message);
    if (parsed.pid != pid_component_identification) return error.UnsupportedPid;
    return decodeComponentData(parsed.source_mid, parsed.data);
}

pub fn decodeSoftwareData(data: []const u8) []const u8 {
    return std.mem.trim(u8, data, " \x00");
}

pub const TotalVehicleDistance = struct {
    source_mid: u8,
    raw_count: u32,
    kilometers: f64,
    miles: f64,
};

pub fn decodeTotalVehicleDistanceData(source_mid: u8, data: []const u8) DecodeError!TotalVehicleDistance {
    if (data.len != 4) return error.InvalidLength;

    const raw: u32 = @as(u32, data[0]) |
        (@as(u32, data[1]) << 8) |
        (@as(u32, data[2]) << 16) |
        (@as(u32, data[3]) << 24);
    const raw_f: f64 = @floatFromInt(raw);

    return .{
        .source_mid = source_mid,
        .raw_count = raw,
        .kilometers = raw_f * 0.161,
        .miles = raw_f * 0.1,
    };
}

pub fn decodeVinData(data: []const u8) DecodeError![]const u8 {
    const vin = std.mem.trim(u8, data, " \x00");
    if (vin.len == 0) return error.EmptyVin;
    if (vin.len > 17) return error.InvalidLength;
    return vin;
}

/// Small, deliberately conservative subset of standardized J1587 MIDs.
/// Unknown component MIDs remain usable identity anchors as `.other`.
pub fn kindFromMid(mid: u8) model.ModuleKind {
    return switch (mid) {
        137, 138, 139 => .abs,
        147, 148, 149 => .reefer,
        167, 168, 169 => .tpms,
        else => .other,
    };
}

test "parse checksum-stripped variable-length J1587 message" {
    const parsed = try parseMessage("\x89\xea\x06SW-2.1");
    try std.testing.expectEqual(@as(u8, 137), parsed.source_mid);
    try std.testing.expectEqual(pid_software_identification, parsed.pid);
    try std.testing.expectEqualStrings("SW-2.1", parsed.data);
}

test "decode PID 243 parameter data after reassembly" {
    const payload = "\x89DEMO *ABS-4S2M*ABS-2099";
    const decoded = try decodeComponentData(137, payload);

    try std.testing.expectEqual(@as(u8, 137), decoded.source_mid);
    try std.testing.expectEqual(@as(u8, 137), decoded.component_mid);
    try std.testing.expectEqual(model.ModuleKind.abs, kindFromMid(decoded.component_mid));
    try std.testing.expectEqualStrings("DEMO", decoded.manufacturer);
    try std.testing.expectEqualStrings("ABS-4S2M", decoded.model_name);
    try std.testing.expectEqualStrings("ABS-2099", decoded.serial);
}

test "decode PID 245 total vehicle distance from public example bytes" {
    const distance = try decodeTotalVehicleDistanceData(137, "\xe1\x00\x00\x00");
    try std.testing.expectEqual(@as(u32, 225), distance.raw_count);
    try std.testing.expectApproxEqAbs(@as(f64, 22.5), distance.miles, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 36.225), distance.kilometers, 0.0001);
}

test "decode trailer VIN parameter data" {
    const vin = try decodeVinData("1DEMO000000000001");
    try std.testing.expectEqualStrings("1DEMO000000000001", vin);
}

test "fixed requests and escape payloads are never variable-length identity messages" {
    try std.testing.expectError(error.UnsupportedPid, parseMessage("\x88\x80\xf5\x89"));
    try std.testing.expectError(error.UnsupportedPid, parseMessage("\x88\xff\x80\x99\x89"));
    try std.testing.expectError(error.UnsupportedPid, parseMessage("\x89\xfe\xac\x01"));
}
