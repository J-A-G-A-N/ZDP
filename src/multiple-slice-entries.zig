const std = @import("std");
const DataWriter = @import("root.zig").DataWriter;
const MSE = struct {
    x: []f64,
    y: []f64,
    z: []f64,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, size: usize) !@This() {
        const res = @This(){
            .x = try allocator.alloc(f64, size),
            .y = try allocator.alloc(f64, size),
            .z = try allocator.alloc(f64, size),
            .allocator = allocator,
        };
        return res;
    }
    fn fillsincos(self: *const @This(), min: f64, max: f64) void {
        linspace(self.z, min, max);
        for (self.x, self.y, self.z) |*x, *y, *z| {
            x.* = @sin(z.*);
            y.* = @cos(z.*);
        }
    }
    fn fillLorenz(self: *const @This(), dt: f64) void {
        const sigma = 10.0;
        const rho = 28.0;
        const beta = 8.0 / 3.0;

        var x: f64 = 0.01;
        var y: f64 = 0.0;
        var z: f64 = 0.0;

        for (self.x, self.y, self.z) |*xo, *yo, *zo| {
            xo.* = x;
            yo.* = y;
            zo.* = z;

            const dx = sigma * (y - x);
            const dy = x * (rho - z) - y;
            const dz = x * y - beta * z;

            x += dx * dt;
            y += dy * dt;
            z += dz * dt;
        }
    }
    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.x);
        self.allocator.free(self.y);
        self.allocator.free(self.z);
    }
};
fn linspace(x: []f64, min: f64, max: f64) void {
    const dx: f64 = (max - min) / (@as(f64, @floatFromInt(x.len)) - 1.0);
    for (x, 0..) |*cx, i| {
        cx.* = min + dx * @as(f64, @floatFromInt(i));
    }
}
const dir = "out/";
fn test_MSE(allocator: std.mem.Allocator) !void {
    const dw = DataWriter(MSE);
    const size = 40_000;
    var _test = try MSE.init(allocator, size);
    defer _test.deinit();
    _test.fillLorenz(0.001);
    var d_writer = dw{ .data = &_test, .allocator = allocator };
    const text_file = try std.fs.cwd().createFile(dir ++ "MSE.txt", .{});
    defer text_file.close();
    const text_file_writer = text_file.writer();
    try d_writer.writeAllFieldsAsText(text_file_writer);

    const bin_file = try std.fs.cwd().createFile(dir ++ "MSE.bin", .{});
    defer bin_file.close();
    const bin_file_writer = bin_file.writer();
    const start = std.time.microTimestamp();
    try d_writer.writeAllFieldsAsBytes(bin_file_writer);
    const end = std.time.microTimestamp();
    std.debug.print("{} us\n", .{end - start});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    try test_MSE(allocator);
}
