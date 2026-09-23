//! Normalized equipment-identity types.
//!
//! This layer deliberately does NOT know how a module was discovered.
//! A future J2497/J1708 decoder, J1939 adapter, or other backend can all emit
//! the same normalized module identities. The fingerprint engine only reasons
//! about identity continuity.

pub const UnitClass = enum {
    semitrailer,
    converter_dolly,
    unknown,

    pub fn label(self: UnitClass) []const u8 {
        return switch (self) {
            .semitrailer => "semitrailer",
            .converter_dolly => "converter dolly",
            .unknown => "unknown unit",
        };
    }
};

pub const Position = enum {
    lead,
    dolly,
    rear,
    single,
    unknown,

    pub fn label(self: Position) []const u8 {
        return switch (self) {
            .lead => "lead",
            .dolly => "dolly",
            .rear => "rear",
            .single => "single",
            .unknown => "position unknown",
        };
    }
};

pub const ModuleKind = enum {
    abs,
    tpms,
    gateway,
    tire_inflation,
    reefer,
    other,

    pub fn label(self: ModuleKind) []const u8 {
        return switch (self) {
            .abs => "ABS ECU",
            .tpms => "TPMS controller",
            .gateway => "gateway / trailer information module",
            .tire_inflation => "tire inflation controller",
            .reefer => "reefer controller",
            .other => "other module",
        };
    }
};

/// One electronically observable identity anchor.
///
/// Serial is intentionally separate from make/model. A replacement module can
/// have the same make/model while carrying a different serial number.
pub const ModuleIdentity = struct {
    kind: ModuleKind,
    manufacturer: []const u8,
    model: []const u8,
    serial: []const u8,
    software: ?[]const u8 = null,
};

/// One observation of one physical equipment unit.
///
/// `vin` is optional by design. Trailer Fingerprint must remain useful when the vehicle
/// network does not expose a VIN and the driver provides no manual input.
pub const EquipmentSnapshot = struct {
    observed_name: []const u8,
    unit_class: UnitClass,
    position: Position = .unknown,
    vin: ?[]const u8 = null,
    modules: []const ModuleIdentity,
};

/// Historical identity record for a physical unit.
pub const EquipmentProfile = struct {
    profile_id: []const u8,
    unit_class: UnitClass,
    vin: ?[]const u8 = null,
    modules: []const ModuleIdentity,
};

pub const MatchStatus = enum {
    recognized,
    probable_match,
    ambiguous,
    new_profile,
    identity_conflict,
    insufficient_identity,

    pub fn label(self: MatchStatus) []const u8 {
        return switch (self) {
            .recognized => "RECOGNIZED",
            .probable_match => "PROBABLE MATCH",
            .ambiguous => "AMBIGUOUS",
            .new_profile => "NEW PROFILE",
            .identity_conflict => "IDENTITY CONFLICT",
            .insufficient_identity => "INSUFFICIENT IDENTITY EVIDENCE",
        };
    }
};

/// The result deliberately exposes reasons instead of a pretend-precise
/// confidence percentage.
pub const MatchEvidence = struct {
    exact_module_serials: usize = 0,
    replacement_candidates: usize = 0,
    observed_modules: usize = 0,
    known_modules: usize = 0,
    vin_match: bool = false,
    vin_conflict: bool = false,
};

pub const ProfileMatch = struct {
    status: MatchStatus,
    observed_name: []const u8,
    profile_id: ?[]const u8,
    evidence: MatchEvidence,
    tied_best_candidate: bool = false,
    profile_index: ?usize = null,
};

pub const ConsistStatus = enum {
    recognized,
    partial,
    ambiguous,
    new_consist,

    pub fn label(self: ConsistStatus) []const u8 {
        return switch (self) {
            .recognized => "RECOGNIZED CONSIST",
            .partial => "PARTIALLY RECOGNIZED",
            .ambiguous => "AMBIGUOUS CONSIST",
            .new_consist => "NEW CONSIST",
        };
    }
};

pub const ConsistSummary = struct {
    total_units: usize = 0,
    recognized: usize = 0,
    probable: usize = 0,
    ambiguous: usize = 0,
    new_units: usize = 0,
    conflicts: usize = 0,
    insufficient_identity: usize = 0,

    pub fn status(self: ConsistSummary) ConsistStatus {
        if (self.total_units == 0) return .new_consist;
        if (self.insufficient_identity == self.total_units) return .new_consist;
        if (self.conflicts > 0 or self.ambiguous > 0) return .ambiguous;
        if (self.recognized == self.total_units) return .recognized;
        if ((self.recognized + self.probable) > 0) return .partial;
        return .new_consist;
    }
};
