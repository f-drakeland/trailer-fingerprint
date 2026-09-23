//! Protocol-agnostic discovery layer.
//!
//! The fingerprint engine should not care whether an identity came from a
//! synthetic replay, J2497/J1708, trailer-side J1939, or some future adapter.
//! This file represents what a discovery backend learned before normalization.

const model = @import("fingerprint_model.zig");

pub const DiscoverySource = enum {
    synthetic_replay,
    j2497_j1708,
    trailer_j1939,
    unknown,

    pub fn label(self: DiscoverySource) []const u8 {
        return switch (self) {
            .synthetic_replay => "synthetic replay",
            .j2497_j1708 => "J2497 / J1708",
            .trailer_j1939 => "trailer-side J1939",
            .unknown => "unknown source",
        };
    }
};

/// One module identity reported by a discovery backend.
/// `endpoint` is deliberately diagnostic metadata, not a permanent identity
/// anchor. Bus/source addresses may change across configurations.
pub const DiscoveredModule = struct {
    source: DiscoverySource,
    endpoint: ?[]const u8 = null,
    endpoint_mid: ?u8 = null,
    identity: model.ModuleIdentity,
};

pub const DiscoveredUnit = struct {
    observed_name: []const u8,
    unit_class: model.UnitClass,
    position: model.Position = .unknown,
    vin: ?[]const u8 = null,
    modules: []const DiscoveredModule,
};
