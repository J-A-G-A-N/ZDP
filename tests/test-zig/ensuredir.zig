const std = @import("std");
pub fn ensureDir(name: []const u8) !void {
    const cwd = std.fs.cwd();
    cwd.access(name, .{}) catch |err| switch (err) {
        error.FileNotFound => try cwd.makeDir(name),
        else => {
            std.debug.print("{any}\n", .{err});
        },
    };
}
