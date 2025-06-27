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
//   [field_name_len: usize]
//   [field_name: []u8]
//   [dim: usize]                  // For a slice
//   [shape_len: usize]           // Length of the shape array (should equal `dim`)
//   [shape: [shape_len]usize]    // Each entry is length in that dimension
//   [element_size: usize]        // Size in bytes of base type, e.g., 8 for f64, 4 for i32
//   [actual values in flat array]
const std = @import("std");
const FileFormat = enum {
    text,
    binary,
};
pub fn DataWriter(comptime T: type) type {
    const info = @typeInfo(T);
    if (info != .@"struct") @compileError("DataWriter Expects a Struct");

    return struct {
        data: *const T,
        allocator: std.mem.Allocator,
        const fields: []const std.builtin.Type.StructField = std.meta.fields(T);
        pub fn init(_struct: *T, allocator: std.mem.Allocator) @This() {
            return @This(){
                .data = _struct,
                .allocator = allocator,
            };
        }
        pub fn debugPrintFields(self: *const @This()) void {
            _ = self;
            inline for (fields) |field| {
                std.debug.print("{any}\n", .{field});
            }
        }
        fn writeAllFieldsAsText(self: @This(), writer: anytype) !void {
            comptime var count: usize = 0;
            inline for (fields) |s_field| {
                if (s_field.type == std.mem.Allocator) continue;
                const field_type_info = @typeInfo(s_field.type);
                switch (field_type_info) {
                    .int => continue,
                    .float => continue,
                    else => {},
                }
                count += 1;
            }

            try writer.print(HEADER ++ "\n", .{});
            try writer.print("{}\n", .{count});
            inline for (fields) |s_field| {
                if (s_field.type == std.mem.Allocator) continue;
                const field_type_info = @typeInfo(s_field.type);
                switch (field_type_info) {
                    .int => continue,
                    .float => continue,
                    else => {},
                }

                const field_name = s_field.name;
                const field_value = @field(self.data.*, field_name);
                try writer.print("{}\n", .{field_name.len});
                try writer.print("{s}\n", .{field_name});
                const slice_depth = getDepth(s_field.type);
                try writer.print("{}\n", .{slice_depth});
                const slice_shape = try self.getSliceShape(field_value, slice_depth);
                defer self.allocator.free(slice_shape);
                try writer.print("{}\n", .{slice_shape.len});
                for (slice_shape) |s| {
                    try writer.print("{}\n", .{s});
                }
                const base_type = resolveBaseType(s_field.type);
                const base_type_size = @sizeOf(base_type);
                try writer.print("{}\n", .{base_type_size});
                const flat_res = try get_flat(self.allocator, field_value, base_type);
                defer self.allocator.free(flat_res);
                for (flat_res) |val| {
                    try writer.print("{}\n", .{val});
                }
            }
        }
        pub fn write(self: @This(), comptime file_path: []const u8, comptime file_format: FileFormat) !void {
            const ext = switch (file_format) {
                .text => ".txt",
                .binary => ".bin",
            };
            const file = try std.fs.cwd().createFile(file_path ++ ext, .{});
            defer file.close();
            const writer = file.writer();
            switch (file_format) {
                .text => try self.writeAllFieldsAsText(writer),
                .binary => try self.writeAllFieldsAsBytes(writer),
            }
        }
        fn writeAllFieldsAsBytes(self: @This(), writer: anytype) !void {
            if (info != .@"struct") return error.NotAStruct;
            comptime var count: usize = 0;
            inline for (fields) |s_field| {
                if (s_field.type == std.mem.Allocator) continue;
                const field_type_info = @typeInfo(s_field.type);
                switch (field_type_info) {
                    .int => continue,
                    .float => continue,
                    else => {},
                }

                count += 1;
            }
            // Write Header
            try writer.writeAll(HEADER);
            // Write header length
            try writer.writeInt(usize, count, .little);
            // Write header length
            inline for (info.@"struct".fields) |s_field| {
                if (s_field.type == std.mem.Allocator) continue;
                const field_type_info = @typeInfo(s_field.type);
                switch (field_type_info) {
                    .int => continue,
                    .float => continue,
                    else => {},
                }
                try self.writeSliceAsBytes(s_field, writer);
            }
        }
        fn writeSliceAsBytes(self: @This(), field: anytype, writer: anytype) !void {
            const name = field.name;
            const Type = field.type;
            const base_type = resolveBaseType(Type);
            const base_type_size = @sizeOf(base_type);

            const field_value = @field(self.data.*, name);
            try writer.writeInt(usize, name.len, .little);
            try writer.writeAll(name);
            const slice_depth = getDepth(field.type);
            try writer.writeInt(usize, slice_depth, .little);
            const slice_shape = try self.getSliceShape(field_value, slice_depth);
            defer self.allocator.free(slice_shape);
            try writer.writeInt(usize, slice_shape.len, .little);
            for (slice_shape) |s| {
                try writer.writeInt(usize, s, .little);
            }
            try writer.writeInt(usize, base_type_size, .little);
            const flat_res = try get_flat(self.allocator, field_value, base_type);
            defer self.allocator.free(flat_res);
            try writer.writeAll(std.mem.sliceAsBytes(flat_res));
        }

        fn get_flat(allocator: std.mem.Allocator, value: anytype, base_type: type) ![]f64 {
            var flat = std.ArrayList(f64).init(allocator);
            errdefer flat.deinit();

            try flatten_recursive(value, base_type, &flat);

            return flat.toOwnedSlice();
        }

        fn flatten_recursive(value: anytype, base_type: type, flat: *std.ArrayList(base_type)) !void {
            const Type = @TypeOf(value);
            const _info = @typeInfo(Type);

            switch (_info) {
                .pointer => |ptr_info| {
                    if (ptr_info.size == .slice) {
                        for (value) |item| {
                            try flatten_recursive(
                                item,
                                base_type,
                                flat,
                            );
                        }
                        return;
                    }
                },
                .array => {
                    for (value) |item| {
                        try flatten_recursive(
                            item,
                            base_type,
                            flat,
                        );
                    }
                    return;
                },
                else => {
                    try flat.append(value);
                },
            }
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

        fn getSliceShape(self: @This(), value: anytype, depth: usize) ![]usize {
            var shape = try self.allocator.alloc(usize, depth);

            var current = value;
            var i: usize = 0;
            while (i < depth) : (i += 1) {
                shape[i] = current.len;

                if (current.len == 0) {
                    for (shape[i + 1 ..]) |*s| s.* = 0;
                    break;
                }

                const Elem = @TypeOf(current[0]);
                if (@typeInfo(Elem) != .pointer or @typeInfo(Elem).pointer.size != .slice) {
                    break; // reached the base scalar (e.g., f64)
                }

                current = current[0];
            }

            return shape;
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
