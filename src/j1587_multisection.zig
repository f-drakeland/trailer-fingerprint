//! SAE J1587 PID 192 multisection reassembly.
//!
//! Long J1587 parameters cannot fit in one J1708 message. PID 192 splits one
//! original parameter across sequential sections. Real receivers are expected
//! to tolerate concurrent multisection transfers from different transmitters,
//! so this prototype keeps a small fixed bank keyed by source MID + target PID.

const std = @import("std");
const j1587 = @import("j1587.zig");

pub const max_parameter_bytes = 239;
pub const max_concurrent_transfers = 8;

pub const ReassemblyError = j1587.DecodeError || error{
    NotMultisection,
    InvalidSection,
    MissingFirstSection,
    OutOfOrderSection,
    NoFreeSlot,
    ParameterTooLarge,
    LengthMismatch,
};

pub const ReassembledParameter = struct {
    source_mid: u8,
    pid: u8,
    data: []const u8,
};

pub const PushResult = union(enum) {
    pending,
    complete: ReassembledParameter,
};

const Section = struct {
    source_mid: u8,
    target_pid: u8,
    last_section: u8,
    current_section: u8,
    total_length: ?usize,
    segment: []const u8,
};

const Slot = struct {
    active: bool = false,
    source_mid: u8 = 0,
    target_pid: u8 = 0,
    last_section: u8 = 0,
    next_section: u8 = 0,
    total_length: usize = 0,
    length: usize = 0,
    buffer: [max_parameter_bytes]u8 = undefined,
};

pub const Bank = struct {
    slots: [max_concurrent_transfers]Slot,

    pub fn init() Bank {
        var bank: Bank = undefined;
        for (&bank.slots) |*slot| slot.* = .{};
        return bank;
    }

    pub fn push(self: *Bank, raw_message: []const u8) ReassemblyError!PushResult {
        const section = try parseSection(raw_message);

        if (section.current_section == 0) {
            if (section.last_section == 0) return error.InvalidSection;
            const total_length = section.total_length orelse return error.InvalidSection;
            if (total_length > max_parameter_bytes) return error.ParameterTooLarge;

            var slot = self.findSlot(section.source_mid, section.target_pid) orelse
                self.findFreeSlot() orelse return error.NoFreeSlot;

            slot.* = .{};
            slot.active = true;
            slot.source_mid = section.source_mid;
            slot.target_pid = section.target_pid;
            slot.last_section = section.last_section;
            slot.next_section = 1;
            slot.total_length = total_length;
            try appendSegment(slot, section.segment);

            if (section.current_section == section.last_section) {
                return try finish(slot);
            }
            return .pending;
        }

        const slot = self.findSlot(section.source_mid, section.target_pid) orelse
            return error.MissingFirstSection;

        if (section.last_section != slot.last_section) return error.InvalidSection;
        if (section.current_section != slot.next_section) return error.OutOfOrderSection;

        try appendSegment(slot, section.segment);
        slot.next_section += 1;

        if (section.current_section == section.last_section) {
            return try finish(slot);
        }

        return .pending;
    }

    fn findSlot(self: *Bank, source_mid: u8, target_pid: u8) ?*Slot {
        for (&self.slots) |*slot| {
            if (slot.active and slot.source_mid == source_mid and slot.target_pid == target_pid) {
                return slot;
            }
        }
        return null;
    }

    fn findFreeSlot(self: *Bank) ?*Slot {
        for (&self.slots) |*slot| {
            if (!slot.active) return slot;
        }
        return null;
    }
};

fn parseSection(raw_message: []const u8) ReassemblyError!Section {
    const message = try j1587.parseMessage(raw_message);
    if (message.pid != j1587.pid_multisection) return error.NotMultisection;
    if (message.data.len < 2) return error.InvalidSection;

    const target_pid = message.data[0];
    const section_info = message.data[1];
    const last_section = section_info >> 4;
    const current_section = section_info & 0x0f;
    if (current_section > last_section) return error.InvalidSection;

    if (current_section == 0) {
        if (message.data.len < 4) return error.InvalidSection;
        const total_length: usize = message.data[2];
        return .{
            .source_mid = message.source_mid,
            .target_pid = target_pid,
            .last_section = last_section,
            .current_section = current_section,
            .total_length = total_length,
            .segment = message.data[3..],
        };
    }

    if (message.data.len < 3) return error.InvalidSection;
    return .{
        .source_mid = message.source_mid,
        .target_pid = target_pid,
        .last_section = last_section,
        .current_section = current_section,
        .total_length = null,
        .segment = message.data[2..],
    };
}

fn appendSegment(slot: *Slot, segment: []const u8) ReassemblyError!void {
    if (slot.length + segment.len > slot.total_length or
        slot.length + segment.len > max_parameter_bytes)
    {
        return error.ParameterTooLarge;
    }

    @memcpy(slot.buffer[slot.length .. slot.length + segment.len], segment);
    slot.length += segment.len;
}

fn finish(slot: *Slot) ReassemblyError!PushResult {
    if (slot.length != slot.total_length) return error.LengthMismatch;

    const result = ReassembledParameter{
        .source_mid = slot.source_mid,
        .pid = slot.target_pid,
        .data = slot.buffer[0..slot.length],
    };
    slot.active = false;
    return .{ .complete = result };
}

test "reassembles a realistic two-section PID 243" {
    const first = "\x89\xc0\x11\xf3\x10\x18\x89DEMO *ABS-4S2";
    const second = "\x89\xc0\x0c\xf3\x11M*ABS-2099";

    // J1708 permits 21 total bytes including checksum; these fixtures omit it.
    try std.testing.expect(first.len <= 20);
    try std.testing.expect(second.len <= 20);

    var bank = Bank.init();
    try std.testing.expectEqual(PushResult.pending, try bank.push(first));

    const result = try bank.push(second);
    switch (result) {
        .pending => return error.TestUnexpectedResult,
        .complete => |parameter| {
            try std.testing.expectEqual(@as(u8, 137), parameter.source_mid);
            try std.testing.expectEqual(j1587.pid_component_identification, parameter.pid);
            try std.testing.expectEqualStrings("\x89DEMO *ABS-4S2M*ABS-2099", parameter.data);
        },
    }
}

test "concurrent transmitters can interleave multisection identity messages" {
    const abs_first = "\x89\xc0\x11\xf3\x10\x18\x89DEMO *ABS-4S2";
    const tpms_first = "\xa7\xc0\x11\xf3\x10\x17\xa7DEMO *TPMS-8*";
    const abs_second = "\x89\xc0\x0c\xf3\x11M*ABS-2099";
    const tpms_second = "\xa7\xc0\x0b\xf3\x11TPMS-2207";

    var bank = Bank.init();
    _ = try bank.push(abs_first);
    _ = try bank.push(tpms_first);

    const abs_result = try bank.push(abs_second);
    const tpms_result = try bank.push(tpms_second);

    switch (abs_result) {
        .complete => |parameter| try std.testing.expectEqualStrings("\x89DEMO *ABS-4S2M*ABS-2099", parameter.data),
        .pending => return error.TestUnexpectedResult,
    }
    switch (tpms_result) {
        .complete => |parameter| try std.testing.expectEqualStrings("\xa7DEMO *TPMS-8*TPMS-2207", parameter.data),
        .pending => return error.TestUnexpectedResult,
    }
}
