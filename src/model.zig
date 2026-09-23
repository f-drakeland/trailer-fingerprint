//! Core Trailer Fingerprint domain types.
//!
//! The model deliberately records observations rather than pretending to know
//! which physical component failed. A real instrument should make the narrowest
//! claim supported by the measurements it actually captured.

pub const Circuit = enum {
    clearance_identification,
    left_turn,
    stop,
    right_turn,
    tail_marker,
    auxiliary_abs_power,

    pub fn label(self: Circuit) []const u8 {
        return switch (self) {
            .clearance_identification => "clearance / identification",
            .left_turn => "left turn",
            .stop => "stop",
            .right_turn => "right turn",
            .tail_marker => "tail / marker",
            .auxiliary_abs_power => "auxiliary / ABS power",
        };
    }
};

/// One observation captured while Trailer Fingerprint has a circuit energized.
pub const Sample = struct {
    time_ms: u32,
    voltage: f32,
    current: f32,
};

/// The complete evidence captured from one circuit test.
pub const TestRun = struct {
    trailer_id: []const u8,
    circuit: Circuit,
    samples: []const Sample,

    /// A real Trailer Fingerprint output stage must be able to remove power when a
    /// protection threshold is crossed. The simulator preserves that event.
    protection_tripped: bool = false,
};

pub const Classification = enum {
    stable_response,
    no_load_detected,
    unstable_load,
    overcurrent_abort,
    low_source_voltage,
    insufficient_data,

    pub fn label(self: Classification) []const u8 {
        return switch (self) {
            .stable_response => "STABLE RESPONSE",
            .no_load_detected => "NO LOAD DETECTED",
            .unstable_load => "UNSTABLE LOAD",
            .overcurrent_abort => "OVERCURRENT / TEST ABORTED",
            .low_source_voltage => "LOW SOURCE VOLTAGE",
            .insufficient_data => "INSUFFICIENT DATA",
        };
    }
};

/// Simulation-only limits. None of these values are SAE diagnostic limits.
pub const Thresholds = struct {
    min_source_voltage: f32 = 10.5,
    no_load_current: f32 = 0.10,
    unstable_current_span: f32 = 2.0,
    overcurrent_limit: f32 = 15.0,
};

pub const Statistics = struct {
    sample_count: usize,
    min_voltage: f32,
    max_voltage: f32,
    avg_voltage: f32,
    min_current: f32,
    max_current: f32,
    avg_current: f32,
};

pub const Analysis = struct {
    trailer_id: []const u8,
    circuit: Circuit,
    classification: Classification,
    stats: ?Statistics,
    protection_tripped: bool,
};

pub const Baseline = struct {
    trailer_id: []const u8,
    circuit: Circuit,
    avg_current: f32,
};

pub const BaselineComparison = struct {
    comparable: bool,
    baseline_current: f32,
    observed_current: f32,
    percent_change: f32,
    changed: bool,
};

pub const InspectionSummary = struct {
    total: usize = 0,
    stable: usize = 0,
    attention: usize = 0,
    aborted: usize = 0,
};
