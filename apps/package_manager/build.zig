const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Pantry path - defaults to sibling project directory
    const pantry_path = b.option([]const u8, "pantry-path", "Path to pantry Zig source") orelse
        b.pathResolve(&.{ "..", "..", "..", "pantry", "packages", "zig", "src", "lib.zig" });

    // Add pantry dependency
    const pantry_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = pantry_path },
        .target = target,
    });

    // Build simple test executable
    const test_exe = b.addExecutable(.{
        .name = "test_pantry",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test_simple.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "pantry", .module = pantry_mod },
            },
        }),
    });

    b.installArtifact(test_exe);

    const run_test = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run integration tests");
    test_step.dependOn(&run_test.step);

    // Build installation test executable
    const install_test_exe = b.addExecutable(.{
        .name = "test_install",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test_install.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "pantry", .module = pantry_mod },
            },
        }),
    });

    b.installArtifact(install_test_exe);

    const run_install_test = b.addRunArtifact(install_test_exe);
    const install_test_step = b.step("test-install", "Run real installation test");
    install_test_step.dependOn(&run_install_test.step);
}
