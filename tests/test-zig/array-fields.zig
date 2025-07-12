const std = @import("std");
const zdp = @import("zdp");
const DataWriter = zdp.DataWriter;

const ensureDir = @import("ensuredir.zig").ensureDir;
fn AFS(comptime N: usize) type {
    return struct {
        x_data: [N]f64,
        y_data: [N]f64,
    };
}
pub fn sin(comptime N: usize, x: *[N]f64, y: *[N]f64) void {
    for (x, y) |*i, *j| {
        j.* = std.math.sin(i.*);
    }
}
fn linspace(comptime N: usize, array: *[N]f64, min: f64, max: f64) void {
    const delta = (max - min) / @as(f64, @floatFromInt(N - 1));
    for (array, 0..) |*val, i| {
        val.* = min + delta * @as(f64, @floatFromInt(i));
    }
}
pub fn main() !void {
    const N = 100;
    const min: f64 = 0;
    const max: f64 = 2 * std.math.pi;
    const arrayfieldstruct = AFS(N);
    var afs = arrayfieldstruct{ .x_data = undefined, .y_data = undefined };
    linspace(N, &afs.x_data, min, max);
    sin(N, &afs.x_data, &afs.y_data);

    const out_dir = "out/";
    const allocator = std.heap.page_allocator;
    const dw = DataWriter(arrayfieldstruct);
    const afs_dw = dw.init(&afs, allocator);
    try ensureDir("out");
    try afs_dw.write(out_dir ++ "AFS", .binary);
}
