const std = @import("std");
const Header = struct {};
const lib = @import("write_data_lib");
const DataWriter = lib.DataWriter;

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

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    try test_TestDataf64MD_5(allocator);
}
