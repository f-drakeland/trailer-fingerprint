const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const fingerprint_exe = b.addExecutable(.{
        .name = "trailer-fingerprint",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(fingerprint_exe);

    const run_fingerprint = b.addRunArtifact(fingerprint_exe);
    if (b.args) |args| run_fingerprint.addArgs(args);
    const run_step = b.step("run", "Run the capture/log equipment fingerprint demo");
    run_step.dependOn(&run_fingerprint.step);

    const synthetic_exe = b.addExecutable(.{
        .name = "trailer-fingerprint-synthetic",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/synthetic_main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_synthetic = b.addRunArtifact(synthetic_exe);
    const synthetic_step = b.step("synthetic", "Run the preserved v0.6 synthetic consist demo");
    synthetic_step.dependOn(&run_synthetic.step);

    const diagnostic_exe = b.addExecutable(.{
        .name = "trailer-fingerprint-diagnostics",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/diagnostic_main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_diagnostics = b.addRunArtifact(diagnostic_exe);
    const diagnostics_step = b.step("diagnostics", "Run the v0.4 electrical diagnostic simulator");
    diagnostics_step.dependOn(&run_diagnostics.step);

    const fingerprint_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_fingerprint_tests = b.addRunArtifact(fingerprint_tests);

    const synthetic_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/synthetic_main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_synthetic_tests = b.addRunArtifact(synthetic_tests);

    const diagnostic_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/diagnostic_main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_diagnostic_tests = b.addRunArtifact(diagnostic_tests);

    const test_step = b.step("test", "Run protocol, fingerprint, synthetic, and diagnostic tests");
    test_step.dependOn(&run_fingerprint_tests.step);
    test_step.dependOn(&run_synthetic_tests.step);
    test_step.dependOn(&run_diagnostic_tests.step);
}
