//! Protocol-shaped replay fixtures for v0.8.
//!
//! The identities are fictional, but the J1587 framing now respects the J1708
//! packet-size constraint. Long PID 243 Component Identification values are
//! carried as PID 192 multisection messages instead of impossible oversized
//! single packets.
//!
//! All fixtures are checksum-stripped because the prototype input boundary is
//! after the transport has validated/removed the J1708 checksum.

const std = @import("std");
const j1587 = @import("j1587.zig");

// Current observation: same physical trailer after its ABS ECU was replaced.
// The TPMS serial survives. Software identification enriches the ABS endpoint.
// VIN is also available in this fixture, but Trailer Fingerprint does not require it.
const current_abs_software = "\x89\xea\x06SW-2.1";
const current_abs_243_0 = "\x89\xc0\x11\xf3\x10\x18\x89DEMO *ABS-4S2";
const current_tpms_243_0 = "\xa7\xc0\x11\xf3\x10\x17\xa7DEMO *TPMS-8*";
const current_vin = "\x89\xed\x111DEMO000000000001";
const current_abs_243_1 = "\x89\xc0\x0c\xf3\x11M*ABS-2099";
const current_tpms_243_1 = "\xa7\xc0\x0b\xf3\x11TPMS-2207";

pub const current_trailer = [_][]const u8{
    current_abs_software,
    current_abs_243_0,
    current_tpms_243_0,
    current_vin,
    current_abs_243_1,
    current_tpms_243_1,
};

// Same observation with VIN intentionally absent. This proves the engine still
// recognizes continuity from surviving module anchors alone.
pub const current_trailer_no_vin = [_][]const u8{
    current_abs_software,
    current_abs_243_0,
    current_tpms_243_0,
    current_abs_243_1,
    current_tpms_243_1,
};

// Fleet-spec lookalike: same make/model constellation, different serials and a
// conflicting VIN. It must never be merged into the known physical trailer.
const twin_abs_243_0 = "\x89\xc0\x11\xf3\x10\x18\x89DEMO *ABS-4S2";
const twin_tpms_243_0 = "\xa7\xc0\x11\xf3\x10\x17\xa7DEMO *TPMS-8*";
const twin_vin = "\x89\xed\x111DEMO000000000002";
const twin_abs_243_1 = "\x89\xc0\x0c\xf3\x11M*TWIN-ABS";
const twin_tpms_243_1 = "\xa7\xc0\x0b\xf3\x11TWIN-TPMS";

pub const fleet_twin = [_][]const u8{
    twin_abs_243_0,
    twin_tpms_243_0,
    twin_vin,
    twin_abs_243_1,
    twin_tpms_243_1,
};


fn expectReplayFramesWellFormed(messages: []const []const u8) !void {
    for (messages) |message| {
        _ = try j1587.parseMessage(message);
        // The prototype boundary is checksum-stripped J1708/J1587. Real J1708
        // packets are limited to 21 bytes including checksum, so a replay frame
        // must be no more than 20 bytes at this boundary.
        try std.testing.expect(message.len <= 20);
    }
}

test "all protocol replay frames have internally consistent lengths" {
    try expectReplayFramesWellFormed(&current_trailer);
    try expectReplayFramesWellFormed(&current_trailer_no_vin);
    try expectReplayFramesWellFormed(&fleet_twin);
}
