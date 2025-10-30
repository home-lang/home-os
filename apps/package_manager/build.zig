const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add zonfig dependency (required by pantry)
    const zonfig_mod = b.addModule("zonfig", .{
        .root_source_file = .{ .cwd_relative = "/Users/chrisbreuer/Code/zonfig/src/zonfig.zig" },
        .target = target,
    });

    // Add pantry dependency using cwd_relative for absolute path
    const pantry_mod = b.addModule("pantry", .{
        .root_source_file = .{ .cwd_relative = "/Users/chrisbreuer/Code/pantry/packages/zig/src/lib.zig" },
        .target = target,
    });
    
    // Add zonfig import to pantry module
    pantry_mod.addImport("zonfig", zonfig_mod);

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
