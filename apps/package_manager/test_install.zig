const std = @import("std");
const pantry = @import("pantry");

pub fn main(init: std.process.Init) !void {
    _ = init;
    std.debug.print("Pantry install test: OK\n", .{});
}
