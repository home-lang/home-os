// Pantry Native Integration for home-os
// Bridges Pantry's Zig implementation with Home language

const std = @import("std");
const pantry = @import("pantry");

// C-compatible exports for Home FFI
export fn pantry_init_native() callconv(.C) c_int {
    // Initialize Pantry
    return 0;
}

export fn pantry_install_native(
    package_name: [*:0]const u8,
    version: [*:0]const u8,
    _: c_int, // system_wide - unused for now
) callconv(.C) c_int {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const pkg_name = std.mem.span(package_name);
    const pkg_version = std.mem.span(version);

    // Create package list
    var packages = std.ArrayList([]const u8).init(allocator);
    defer packages.deinit();

    // Format package with version
    const pkg_with_version = std.fmt.allocPrint(
        allocator,
        "{s}@{s}",
        .{ pkg_name, pkg_version },
    ) catch return 1;
    defer allocator.free(pkg_with_version);

    packages.append(pkg_with_version) catch return 1;

    // Call Pantry's install command
    const result = pantry.commands.installCommand(allocator, packages.items) catch return 1;
    defer result.deinit(allocator);

    if (result.exit_code != 0) {
        return @intCast(result.exit_code);
    }

    return 0;
}

export fn pantry_remove_native(package_name: [*:0]const u8) callconv(.C) c_int {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const pkg_name = std.mem.span(package_name);

    var packages = std.ArrayList([]const u8).init(allocator);
    defer packages.deinit();
    packages.append(pkg_name) catch return 1;

    // Call Pantry's remove command
    const result = pantry.commands.removeCommand(allocator, packages.items) catch return 1;
    defer result.deinit(allocator);

    return @intCast(result.exit_code);
}

export fn pantry_list_native(buffer: [*]u8, buffer_size: usize) callconv(.C) c_int {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Call Pantry's list command
    const result = pantry.commands.listCommand(allocator, "table", false) catch return 1;
    defer result.deinit(allocator);

    if (result.message) |msg| {
        const copy_len = @min(msg.len, buffer_size - 1);
        @memcpy(buffer[0..copy_len], msg[0..copy_len]);
        buffer[copy_len] = 0;
    }

    return 0;
}

export fn pantry_update_native(package_name: [*:0]const u8) callconv(.C) c_int {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const pkg_name = std.mem.span(package_name);

    var packages = std.ArrayList([]const u8).init(allocator);
    defer packages.deinit();
    packages.append(pkg_name) catch return 1;

    // Call Pantry's update command
    const result = pantry.commands.updateCommand(allocator, packages.items, true) catch return 1;
    defer result.deinit(allocator);

    return @intCast(result.exit_code);
}

export fn pantry_bootstrap_native() callconv(.C) c_int {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Call Pantry's bootstrap command
    const result = pantry.commands.bootstrapCommand(
        allocator,
        "/usr/local",
        false, // skip_bun
        false, // skip_shell
        false, // verbose
    ) catch return 1;
    defer result.deinit(allocator);

    return @intCast(result.exit_code);
}

export fn pantry_resolve_deps_native(deps_file: [*:0]const u8) callconv(.C) c_int {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file_path = std.mem.span(deps_file);

    // Read and parse deps file
    const deps_result = pantry.deps.parseDepsFile(allocator, file_path) catch return 1;
    defer deps_result.deinit(allocator);

    // Install all dependencies
    if (deps_result.dependencies) |dependencies| {
        const result = pantry.commands.installCommand(allocator, dependencies) catch return 1;
        defer result.deinit(allocator);

        return @intCast(result.exit_code);
    }

    return 0;
}
