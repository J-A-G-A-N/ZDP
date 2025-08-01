// Currently Supports a struct with slices, mulit-dim slices

// -------------------------------------------------
// Format
// -------------------------------------------------
const HEADER = "DATA.*01";
//
// DATA.*01
// [field_count: usize]
//
// For each field:
//   [field_type_mark:usize]
//   [field_name_len: usize]
//   [field_name: []u8]
//   [dim: usize]                  // For a slice
//   [shape: [dim]usize]    // Each entry is length in that dimension
//   [element_size: usize]        // Size in bytes of base type, e.g., 8 for f64, 4 for i32
//   [actual values in flat array]
const std = @import("std");
const FileFormat = enum {
    text,
    binary,
};

const FieldTypeMarker = enum(u8) {
    _struct = 0x01,
    slice = 0x02,
    array = 0x03,
    unknown = 0x04,
};
const FieldMeta = struct {
    name: []const u8,
    field_type_marker: FieldTypeMarker,
    depth: usize,
    shape: []usize,
    total_elemnts: usize,
    base_type_size: u8,
    flat_res: []const u8,
};

pub fn DataWriter(comptime T: type) type {
    const info = @typeInfo(T);
    if (info != .@"struct") @compileError("DataWriter Expects a Struct");

    return struct {
        data: *const T,
        metas: std.ArrayList(FieldMeta),
        allocator: std.mem.Allocator,
        parse_done: bool = false,
        const Self = @This();
        const fields: []const std.builtin.Type.StructField = std.meta.fields(T);
        pub fn init(_struct: *T, allocator: std.mem.Allocator) @This() {
            return @This(){
                .data = _struct,
                .metas = std.ArrayList(FieldMeta).init(allocator),
                .allocator = allocator,
                .parse_done = false,
            };
        }
        pub fn deinit(self: *Self) void {
            for (self.metas.items) |meta| {
                self.allocator.free(meta.shape);
                self.allocator.free(meta.flat_res);
            }
            self.metas.deinit();
        }
        pub fn debugPrintFields(self: *const @This()) void {
            _ = self;
            inline for (fields) |field| {
                std.debug.print("{any}\n", .{field});
            }
        }
        fn getFieldTypeMarker(field_type_info: std.builtin.Type) FieldTypeMarker {
            return switch (field_type_info) {
                .@"struct" => return FieldTypeMarker._struct,
                .pointer => |ptr| {
                    if (ptr.size == .slice) {
                        return FieldTypeMarker.slice;
                    }
                },
                .array => return FieldTypeMarker.array,
                else => {},
            };
        }
        fn collectMeta(self: *Self, field: std.builtin.Type.StructField) !?FieldMeta {
            if (field.type == std.mem.Allocator) return null;

            const field_type_info = @typeInfo(field.type);
            switch (field_type_info) {
                .int => return null,
                .float => return null,
                else => {},
            }

            const name = field.name;
            const value = @field(self.data.*, name);
            const depth = getDepth(field.type);
            const shape = try getSliceShape(self.allocator, value, depth);
            const field_type_marker = getFieldTypeMarker(field_type_info);
            var total_elemnts: usize = 1;

            const base_type = resolveBaseType(field.type);
            for (shape) |s| {
                total_elemnts *= s;
            }
            const flat_res = try get_flat_optimized(
                self.allocator,
                value,
                base_type,
                total_elemnts,
            );

            return FieldMeta{
                .field_type_marker = field_type_marker,
                .name = name,
                .depth = depth,
                .shape = shape,
                .total_elemnts = total_elemnts,
                .base_type_size = @sizeOf(base_type),
                .flat_res = std.mem.sliceAsBytes(flat_res),
            };
        }
        fn parse(self: *Self) !void {
            if (self.parse_done) return;
            self.metas.clearRetainingCapacity();
            inline for (fields) |field| {
                if (field.type == std.mem.Allocator) continue;
                if (try self.collectMeta(field)) |meta| try self.metas.append(meta);
            }
            self.parse_done = true;
        }
        pub fn write(self: *@This(), comptime file_path: []const u8, comptime file_format: FileFormat) !void {
            const ext = switch (file_format) {
                .text => ".txt",
                .binary => ".bin",
            };
            const file = try std.fs.cwd().createFile(file_path ++ ext, .{});
            defer file.close();
            var bw = std.io.bufferedWriter(file.writer());
            const writer = bw.writer();
            if (!self.parse_done) try self.parse();
            switch (file_format) {
                .text => try self.writeAllFieldAsText(writer),
                .binary => try self.writeAllFieldAsBytes(writer),
            }
            try bw.flush();
        }
        fn writeAllFieldAsBytes(self: *Self, writer: anytype) !void {
            const metas = self.metas.items;
            try writer.writeAll(HEADER);
            try writer.writeInt(usize, metas.len, .little);
            for (metas) |meta| {
                try writer.writeInt(usize, @intFromEnum(meta.field_type_marker), .little);
                try writer.writeInt(usize, meta.name.len, .little);
                try writer.writeAll(meta.name);
                try writer.writeInt(usize, meta.depth, .little);
                for (meta.shape) |s| try writer.writeInt(usize, s, .little);
                try writer.writeInt(usize, meta.base_type_size, .little);

                try writer.writeAll(meta.flat_res);
            }
        }

        fn writeAllFieldAsText(self: *Self, writer: anytype) !void {
            const metas = self.metas.items;
            try writer.print("{s}\n{d}\n", .{ HEADER, metas.len });
            var meta_index: usize = 0;
            inline for (fields) |field| {
                if (field.type == std.mem.Allocator) continue;
                const meta = metas[meta_index];
                meta_index += 1;
                try writer.print(
                    "{d}\n{d}\n{s}\n{d}\n",
                    .{
                        @intFromEnum(meta.field_type_marker),
                        meta.name.len,
                        meta.name,
                        meta.depth,
                    },
                );
                for (meta.shape) |s| try writer.print("{d}\n", .{s});
                try writer.print("{}\n", .{meta.base_type_size});
                const base_type = resolveBaseType(@TypeOf(@field(self.data.*, field.name)));

                const flat_res_typed = std.mem.bytesAsSlice(base_type, meta.flat_res);
                for (flat_res_typed) |val| {
                    try writer.print("{}\n", .{val});
                }
            }
        }

        pub fn flattenVectorSliceType(comptime VecSliceType: type) type {
            const VecType = std.meta.Child(VecSliceType); // @Vector(n, T)
            const vec_info = @typeInfo(VecType);

            if (vec_info != .vector) {
                @compileError("Expected slice of vector type");
            }

            const n = vec_info.vector.len;
            const Type = vec_info.vector.child;

            return [n]Type;
        }
    };
}
fn get_flat_optimized(
    allocator: std.mem.Allocator,
    value: anytype,
    base_type: type,
    return_len: usize,
) ![]base_type {
    var flat = try allocator.alloc(base_type, return_len);
    var index: usize = 0;
    flatten_recursive_optimized(value, base_type, &flat, &index);
    return flat;
}
fn flatten_recursive_optimized(value: anytype, base_type: type, flat: *[]base_type, index: *usize) void {
    const Type = @TypeOf(value);
    const _info = @typeInfo(Type);
    const max_len = flat.*.len;
    switch (_info) {
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice) {
                for (value) |item| {
                    flatten_recursive_optimized(
                        item,
                        base_type,
                        flat,
                        index,
                    );
                }
                return;
            }
        },
        .array => {
            for (value) |item| {
                flatten_recursive_optimized(
                    item,
                    base_type,
                    flat,
                    index,
                );
            }
            return;
        },
        else => {
            if (index.* < max_len) {
                flat.*[index.*] = value;
                index.* += 1;
            }
        },
    }
}
fn getDepth(comptime Type: type) usize {
    comptime var current_type = Type;
    comptime var depth: usize = 0;

    inline while (true) {
        const _info = @typeInfo(current_type);
        switch (_info) {
            .array => |arr| {
                depth += 1;
                current_type = arr.child;
            },
            .pointer => |ptr| if (ptr.size == .slice) {
                depth += 1;
                current_type = ptr.child;
            } else {
                current_type = ptr.child;
            },
            else => break,
        }
    }
    return depth;
}
fn resolveBaseType(comptime Type: type) type {
    var current_type = Type;
    inline while (true) {
        const tag = @typeInfo(current_type);
        switch (tag) {
            .pointer => current_type = tag.pointer.child,
            .array => current_type = tag.array.child,
            .vector => current_type = tag.vector.child,
            // .optional => t = tag.optional.child, // (future use)
            else => break,
        }
    }
    return current_type;
}
fn getShapeRecursive(allocator: std.mem.Allocator, value: anytype, max_depth: usize, level: usize, shape: []usize) !void {
    if (level >= max_depth) return;

    const val_type = @TypeOf(value);
    const info = @typeInfo(val_type);

    // Slice check
    if (info != .pointer or info.pointer.size != .slice) return;

    shape[level] = value.len;

    if (value.len == 0) {
        for (shape[level + 1 ..]) |*s| s.* = 0;
        return;
    }

    try getShapeRecursive(allocator, value[0], max_depth, level + 1, shape);
}

pub fn getSliceShape(allocator: std.mem.Allocator, value: anytype, depth: usize) ![]usize {
    const shape = try allocator.alloc(usize, depth);
    for (shape) |*s| s.* = 0;

    try getShapeRecursive(allocator, value, depth, 0, shape);

    return shape;
}
// Old imp
// fn getSliceShape(allocator: std.mem.Allocator, value: anytype, depth: usize) ![]usize {
//     var shape = try allocator.alloc(usize, depth);
//
//     var current = value;
//     var i: usize = 0;
//     while (i < depth) : (i += 1) {
//         shape[i] = current.len;
//
//         if (current.len == 0) {
//             for (shape[i + 1 ..]) |*s| s.* = 0;
//             break;
//         }
//
//         const Elem = @TypeOf(current[0]);
//         if (@typeInfo(Elem) != .pointer or @typeInfo(Elem).pointer.size != .slice) {
//             break; // reached the base scalar (e.g., f64)
//         }
//
//         current = current[0];
//     }
//
//     return shape;
// }
// -------------------------------------------------
// Concept Begins
// -------------------------------------------------
//// DATA.*
// field_count
// [lenght of Field Name][Field Name][dim][len of shape][shape][element_size]
// [const []u8][usize][usize][usize][usize]
// -------------------------------------------------
// Concept Ends
// -------------------------------------------------
