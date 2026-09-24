//! Owns decoded component observations independently of capture and reassembly buffers.

const std = @import("std");
const discovery = @import("discovery.zig");
const j1587 = @import("j1587.zig");
const multisection = @import("j1587_multisection.zig");
const model = @import("fingerprint_model.zig");

pub const max_modules_per_unit = 12;
pub const max_endpoints_per_unit = 12;
pub const max_distance_observations = 12;

pub const IngestError = std.mem.Allocator.Error || j1587.DecodeError || multisection.ReassemblyError || error{
    TooManyModules,
    TooManyEndpoints,
    ConflictingVin,
};

const EndpointState = struct {
    used: bool = false,
    source_mid: u8 = 0,
    software: ?[]const u8 = null,
    module_index: ?usize = null,
};

/// Owns its text. Deinitialize once; returned views borrow this result.
pub const IngestedUnit = struct {
    arena: std.heap.ArenaAllocator,
    observed_name: []const u8,
    unit_class: model.UnitClass,
    position: model.Position,
    vin: ?[]const u8 = null,
    modules: [max_modules_per_unit]discovery.DiscoveredModule = undefined,
    module_count: usize = 0,
    endpoints: [max_endpoints_per_unit]EndpointState = undefined,
    endpoint_count: usize = 0,
    distance_observations: [max_distance_observations]j1587.TotalVehicleDistance = undefined,
    distance_count: usize = 0,

    pub fn deinit(self: *IngestedUnit) void {
        self.arena.deinit();
    }

    pub fn distanceSamples(self: *const IngestedUnit) []const j1587.TotalVehicleDistance {
        return self.distance_observations[0..self.distance_count];
    }

    pub fn discoveredUnit(self: *const IngestedUnit) discovery.DiscoveredUnit {
        return .{
            .observed_name = self.observed_name,
            .unit_class = self.unit_class,
            .position = self.position,
            .vin = self.vin,
            .modules = self.modules[0..self.module_count],
        };
    }

    fn endpoint(self: *IngestedUnit, source_mid: u8) IngestError!*EndpointState {
        for (self.endpoints[0..self.endpoint_count]) |*entry| {
            if (entry.source_mid == source_mid) return entry;
        }

        if (self.endpoint_count >= max_endpoints_per_unit) return error.TooManyEndpoints;
        const index = self.endpoint_count;
        self.endpoint_count += 1;
        self.endpoints[index] = .{
            .used = true,
            .source_mid = source_mid,
        };
        return &self.endpoints[index];
    }

    fn applyParameter(
        self: *IngestedUnit,
        source_mid: u8,
        pid: u8,
        data: []const u8,
    ) IngestError!void {
        switch (pid) {
            j1587.pid_component_identification => {
                const decoded = try j1587.decodeComponentData(source_mid, try self.arena.allocator().dupe(u8, data));
                const endpoint_state = try self.endpoint(source_mid);
                const discovered = decoded.discovered(endpoint_state.software);

                if (endpoint_state.module_index) |index| {
                    self.modules[index] = discovered;
                    return;
                }

                if (self.module_count >= max_modules_per_unit) return error.TooManyModules;
                const index = self.module_count;
                self.modules[index] = discovered;
                self.module_count += 1;
                endpoint_state.module_index = index;
            },
            j1587.pid_software_identification => {
                const software = try self.arena.allocator().dupe(u8, j1587.decodeSoftwareData(data));
                const endpoint_state = try self.endpoint(source_mid);
                endpoint_state.software = software;
                if (endpoint_state.module_index) |index| {
                    self.modules[index].identity.software = software;
                }
            },
            j1587.pid_vin => {
                const vin = try j1587.decodeVinData(data);
                if (self.vin) |known| {
                    if (!std.mem.eql(u8, known, vin)) return error.ConflictingVin;
                } else {
                    self.vin = try self.arena.allocator().dupe(u8, vin);
                }
            },
            j1587.pid_total_vehicle_distance => {
                const decoded = try j1587.decodeTotalVehicleDistanceData(source_mid, data);
                for (self.distance_observations[0..self.distance_count]) |*existing| {
                    if (existing.source_mid == source_mid) {
                        existing.* = decoded;
                        return;
                    }
                }
                if (self.distance_count >= max_distance_observations) return error.TooManyEndpoints;
                self.distance_observations[self.distance_count] = decoded;
                self.distance_count += 1;
            },
            else => {},
        }
    }
};

pub fn ingestUnit(
    allocator: std.mem.Allocator,
    observed_name: []const u8,
    unit_class: model.UnitClass,
    position: model.Position,
    messages: []const []const u8,
) IngestError!IngestedUnit {
    var result = IngestedUnit{
        .arena = std.heap.ArenaAllocator.init(allocator),
        .observed_name = undefined,
        .unit_class = unit_class,
        .position = position,
    };
    errdefer result.deinit();
    result.observed_name = try result.arena.allocator().dupe(u8, observed_name);

    var reassembly = multisection.Bank.init();

    for (messages) |raw| {
        const parsed = try j1587.parseMessage(raw);

        if (parsed.pid == j1587.pid_multisection) {
            const pushed = try reassembly.push(raw);
            switch (pushed) {
                .pending => {},
                .complete => |parameter| {
                    try result.applyParameter(parameter.source_mid, parameter.pid, parameter.data);
                },
            }
            continue;
        }

        try result.applyParameter(parsed.source_mid, parsed.pid, parsed.data);
    }

    return result;
}

test "multisection component IDs plus software and VIN form one discovered unit" {
    const messages = [_][]const u8{
        "\x89\xea\x06SW-2.1",
        "\x89\xc0\x11\xf3\x10\x18\x89DEMO *ABS-4S2",
        "\xa7\xc0\x11\xf3\x10\x17\xa7DEMO *TPMS-8*",
        "\x89\xed\x111DEMO000000000001",
        "\x89\xc0\x0c\xf3\x11M*ABS-2099",
        "\xa7\xc0\x0b\xf3\x11TPMS-2207",
    };

    var ingested = try ingestUnit(std.testing.allocator, "test", .semitrailer, .single, &messages);
    defer ingested.deinit();
    const unit = ingested.discoveredUnit();

    try std.testing.expectEqual(@as(usize, 2), unit.modules.len);
    try std.testing.expectEqualStrings("1DEMO000000000001", unit.vin.?);
    try std.testing.expectEqualStrings("SW-2.1", unit.modules[0].identity.software.?);
}

test "PID 245 is retained as telemetry and not a module identity" {
    const messages = [_][]const u8{
        "\x89\xf5\x04\xe1\x00\x00\x00",
    };

    var ingested = try ingestUnit(std.testing.allocator, "public-sample", .unknown, .unknown, &messages);
    defer ingested.deinit();
    const unit = ingested.discoveredUnit();
    const distances = ingested.distanceSamples();

    try std.testing.expectEqual(@as(usize, 0), unit.modules.len);
    try std.testing.expectEqual(@as(usize, 1), distances.len);
    try std.testing.expectEqual(@as(u8, 137), distances[0].source_mid);
    try std.testing.expectApproxEqAbs(@as(f64, 22.5), distances[0].miles, 0.0001);
}

test "conflicting VIN observations are rejected" {
    const messages = [_][]const u8{
        "\x89\xed\x111DEMO000000000001",
        "\xa7\xed\x111DEMO000000000002",
    };

    try std.testing.expectError(
        error.ConflictingVin,
        ingestUnit(std.testing.allocator, "test", .semitrailer, .single, &messages),
    );
}

// Complete one transfer before starting the next: both use the same bank slot.
test "owned identities survive slot reuse and capture mutation" {
    var software = "\x89\xea\x06SW-2.1".*;
    var vin = "\x89\xed\x111DEMO000000000001".*;
    var name = "capture".*;
    const messages = [_][]const u8{
        &software,
        &vin,
        "\x89\xc0\x11\xf3\x10\x18\x89DEMO *ABS-4S2",
        "\x89\xc0\x0c\xf3\x11M*ABS-2099",
        "\xa7\xc0\x11\xf3\x10\x17\xa7DEMO *TPMS-8*",
        "\xa7\xc0\x0b\xf3\x11TPMS-2207",
    };
    var ingested = try ingestUnit(std.testing.allocator, &name, .unknown, .unknown, &messages);
    defer ingested.deinit();
    @memset(&software, 0);
    @memset(&vin, 0);
    @memset(&name, 0);
    const unit = ingested.discoveredUnit();
    try std.testing.expectEqualStrings("capture", unit.observed_name);
    try std.testing.expectEqualStrings("1DEMO000000000001", unit.vin.?);
    try std.testing.expectEqualStrings("SW-2.1", unit.modules[0].identity.software.?);
    try std.testing.expectEqualStrings("DEMO", unit.modules[0].identity.manufacturer);
    try std.testing.expectEqualStrings("ABS-4S2M", unit.modules[0].identity.model);
    try std.testing.expectEqualStrings("ABS-2099", unit.modules[0].identity.serial);
    try std.testing.expectEqualStrings("TPMS-2207", unit.modules[1].identity.serial);
}

test "direct component identity owns its input" {
    var raw = "\x89\xf3\x06\x89A*B*C".*;
    const messages = [_][]const u8{&raw};
    var ingested = try ingestUnit(std.testing.allocator, "direct", .unknown, .unknown, &messages);
    defer ingested.deinit();
    @memset(&raw, 0);
    try std.testing.expectEqualStrings("C", ingested.discoveredUnit().modules[0].identity.serial);
}
