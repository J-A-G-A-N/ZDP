const std = @import("std");
const Header = struct {};
const lib = @import("write_data_lib");
const DataWriter = lib.DataWriter;

const TestDataf64 = struct {
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
        // const sigma = 10.0;
        // const rho = 28.0;
        // const beta = 8.0 / 3.0;
        //
        // var x: f64 = 0.01;
        // var y: f64 = 0.0;
        // var z: f64 = 0.0;

        const sigma = 10.0;
        const rho = 28.0;
        const beta = 10.0 / 3.0;

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

    fn fillHelix(self: *const @This(), radius: f64, turns: f64, height: f64) void {
        const n = self.x.len;
        var angle: f64 = 0;
        const dtheta = (2 * std.math.pi * turns) / @as(f64, @floatFromInt(n));
        const dz = height / @as(f64, @floatFromInt(n));

        for (self.x, self.y, self.z, 0..) |*x, *y, *z, i| {
            angle = dtheta * @as(f64, @floatFromInt(i));
            x.* = radius * @cos(angle);
            y.* = radius * @sin(angle);
            z.* = dz * @as(f64, @floatFromInt(i));
        }
    }

    fn fillProjectile(self: *const @This(), v0: f64, angle_deg: f64, height0: f64) void {
        const g: f64 = 9.81;
        const angle_rad = angle_deg * std.math.pi / 180.0;
        const vx = v0 * @cos(angle_rad);
        const vz = v0 * @sin(angle_rad);
        const n = self.x.len;
        const t_max = (2 * vz) / g;
        const dt = t_max / @as(f64, @floatFromInt(n));

        for (self.x, self.y, self.z, 0..) |*x, *y, *z, i| {
            const t = dt * @as(f64, @floatFromInt(i));
            x.* = vx * t;
            y.* = 0.2 * @sin(2 * std.math.pi * t); // wiggle in y-direction (optional)
            z.* = height0 + vz * t - 0.5 * g * t * t;
        }
    }
};

pub const TestDataf64MD_5 = struct {
    x_data: [][][][][]f64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, d0: usize, d1: usize, d2: usize, d3: usize, d4: usize) !@This() {
        const x = try allocator.alloc([][][][]f64, d0);
        var count: f64 = 0.0;
        for (x) |*a| {
            a.* = try allocator.alloc([][][]f64, d1);
            for (a.*) |*b| {
                b.* = try allocator.alloc([][]f64, d2);
                for (b.*) |*c| {
                    c.* = try allocator.alloc([]f64, d3);
                    for (c.*) |*d| {
                        d.* = try allocator.alloc(f64, d4);
                        @memset(d.*, count); // initialize innermost with zeros
                        count += 1.0;
                    }
                }
            }
        }

        return .{
            .x_data = x,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.x_data) |a| {
            for (a) |b| {
                for (b) |c| {
                    for (c) |d| {
                        self.allocator.free(d); // free []f64
                    }
                    self.allocator.free(c); // free [][]f64
                }
                self.allocator.free(b); // free [][][]f64
            }
            self.allocator.free(a); // free [][][][]f64
        }
        self.allocator.free(self.x_data); // free [][][][][]f64
    }
};

pub const TestDataf64MD = struct {
    x: [][]f64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, outer_size: usize, inner_size: usize) !@This() {
        const x = try allocator.alloc([]f64, outer_size); // alloc outer slice

        // Allocate each inner slice
        for (x) |*row| {
            row.* = try allocator.alloc(f64, inner_size);
        }

        return @This(){
            .x = x,
            .allocator = allocator,
        };
    }

    pub fn fillsincos(self: *const @This(), min: f64, max: f64) void {
        const total_points = self.x.len * self.x[0].len;
        var flat_index: usize = 0;
        const step = (max - min) / @as(f64, @floatFromInt(total_points - 1));

        for (self.x) |row| {
            for (row) |*elem| {
                const x_val = min + step * @as(f64, @floatFromInt(flat_index));
                elem.* = x_val;
                flat_index += 1;
            }
        }
    }

    pub fn deinit(self: *@This()) void {
        // Free each inner slice
        for (self.x) |row| {
            self.allocator.free(row);
        }

        // Free outer slice
        self.allocator.free(self.x);
    }
};

const Vec3f64 = @Vector(3, f64);
const TestDataVec3f64 = struct {
    x: []Vec3f64,
    time: []f64,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, size: usize) !@This() {
        const res = @This(){
            .x = try allocator.alloc(Vec3f64, size),
            .time = try allocator.alloc(f64, size),
            .allocator = allocator,
        };
        return res;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.x);
        self.allocator.free(self.time);
    }
    pub fn generateHelicalPath(self: *@This(), t_max: f64) void {
        const n = self.x.len;
        const dt = t_max / @as(f64, @floatFromInt(n - 1));
        var t: f64 = 0.0;

        var i: usize = 0;
        while (i < n) : (i += 1) {
            self.time[i] = t;
            self.x[i] = .{
                @cos(t),
                @sin(t),
                t,
            };
            t += dt;
        }
    }
};
fn linspace(x: []f64, min: f64, max: f64) void {
    const dx: f64 = (max - min) / (@as(f64, @floatFromInt(x.len)) - 1.0);
    for (x, 0..) |*cx, i| {
        cx.* = min + dx * @as(f64, @floatFromInt(i));
    }
}

const dir = "out/";
fn test_TestDataf64MD_5(allocator: std.mem.Allocator) !void {
    const dw = DataWriter(TestDataf64MD_5);
    var test_5dim = try TestDataf64MD_5.init(allocator, 5, 4, 3, 2, 1);
    defer test_5dim.deinit();
    var d_writer = dw{ .data = &test_5dim, .allocator = allocator };
    const text_file = try std.fs.cwd().createFile(dir ++ "TestDataf64MD_5.txt", .{});
    defer text_file.close();
    const text_file_writer = text_file.writer();
    try d_writer.writeAllFieldsAsText(text_file_writer);

    const bin_file = try std.fs.cwd().createFile(dir ++ "TestDataf64MD_5.bin", .{});
    defer bin_file.close();
    const bin_file_writer = bin_file.writer();

    try d_writer.writeAllFieldsAsBytes(bin_file_writer);
}
fn test_TestDataf64(allocator: std.mem.Allocator) !void {
    const dw = DataWriter(TestDataf64);
    const size = 10_000_000;
    var _test = try TestDataf64.init(allocator, size);
    defer _test.deinit();
    //const val: f64 = 10 * std.math.pi;
    //_test.fillsincos(-val, val);
    _test.fillLorenz(0.001);
    var d_writer = dw{ .data = &_test, .allocator = allocator };
    const text_file = try std.fs.cwd().createFile(dir ++ "TestDataf64.txt", .{});
    defer text_file.close();
    const text_file_writer = text_file.writer();
    try d_writer.writeAllFieldsAsText(text_file_writer);

    const bin_file = try std.fs.cwd().createFile(dir ++ "TestDataf64.bin", .{});
    defer bin_file.close();
    const bin_file_writer = bin_file.writer();
    const start = std.time.microTimestamp();
    try d_writer.writeAllFieldsAsBytes(bin_file_writer);
    const end = std.time.microTimestamp();
    std.debug.print("{} us\n", .{end - start});
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    try test_TestDataf64MD_5(allocator);
    try test_TestDataf64(allocator);
}
