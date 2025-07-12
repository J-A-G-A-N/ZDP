const std = @import("std");
const ensureDir = @import("ensuredir.zig").ensureDir;
const zdp = @import("zdp");
const DataWriter = zdp.DataWriter;

pub const TestMD = struct {
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
fn linspace(x: []f64, min: f64, max: f64) void {
    const dx: f64 = (max - min) / (@as(f64, @floatFromInt(x.len)) - 1.0);
    for (x, 0..) |*cx, i| {
        cx.* = min + dx * @as(f64, @floatFromInt(i));
    }
}

const dir = "out/";
fn test_TestDataf64MD_5(allocator: std.mem.Allocator) !void {
    const dw = DataWriter(TestMD);
    var test_5dim = try TestMD.init(allocator, 50, 24, 13, 12, 1);
    defer test_5dim.deinit();

    var test_5dim_writer = dw.init(&test_5dim, allocator);
    try test_5dim_writer.write(dir ++ "TMD", .binary);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    try ensureDir("out");
    try test_TestDataf64MD_5(allocator);
}
