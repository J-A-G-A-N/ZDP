// Currently Supports a struct with slices, mulit-dim slices

// -------------------------------------------------
// Format
// -------------------------------------------------

//
// DATA.*
// [field_count: usize]
//
// For each field:
//   [field_name_len: usize]
//   [field_name: []u8]
//   [dim: usize]                  // For a slice, typically 1 (1D), but can be more if needed
//   [shape_len: usize]           // Length of the shape array (should equal `dim`)
//   [shape: [shape_len]usize]    // Each entry is length in that dimension
//   [element_size: usize]        // Size in bytes of base type, e.g., 8 for f64, 4 for i32
//   [actual values in flat array]
const std = @import("std");
pub fn DataWriter(comptime T: type) type {
    return struct {
        data: *const T,
        allocator: std.mem.Allocator,
        pub fn init(_struct: *T) @This() {
            return @This(){
                .data = _struct,
                .allocator = undefined,
            };
        }
        pub fn writeAllFieldsAsText(self: @This(), writer: anytype) !void {
            const info = @typeInfo(T);
            if (info != .@"struct") return error.NotAStruct;

            comptime var count: usize = 0;
            inline for (info.@"struct".fields) |s_field| {
                if (s_field.type == std.mem.Allocator) continue;
                count += 1;
            }
            try writer.print("DATA.*\n", .{});
            try writer.print("{}\n", .{count});
            inline for (info.@"struct".fields) |s_field| {
                if (s_field.type == std.mem.Allocator) continue;
                //const field_type = s_field.type;
                //const field_info = @typeInfo(field_type);

                const field_name = s_field.name;
                const field_value = @field(self.data.*, field_name);
                try writer.print("{}\n", .{field_name.len});
                try writer.print("{s}\n", .{field_name});
                const slice_depth = getSliceDepth(s_field.type);
                try writer.print("{}\n", .{slice_depth});
                const slice_shape = try getSliceShape(field_value, slice_depth);
                try writer.print("{}\n", .{slice_shape.len});
                for (slice_shape) |s| {
                    try writer.print("{}\n", .{s});
                }
                const base_type = getBaseType(s_field.type);
                const base_type_size = @sizeOf(base_type);
                try writer.print("{}\n", .{base_type_size});
                const flat_res = try get_flat(self.allocator, field_value);
                defer self.allocator.free(flat_res);
                for (flat_res) |val| {
                    try writer.print("{d:.6}\n", .{val});
                }
            }
        }
        pub fn writeAllFieldsAsBytes(self: @This(), writer: anytype) !void {
            const info = @typeInfo(T);
            if (info != .@"struct") return error.NotAStruct;

            comptime var count: usize = 0;
            inline for (info.@"struct".fields) |s_field| {
                if (s_field.type == std.mem.Allocator) continue;
                count += 1;
            }
            const header = "DATA.*";
            try writer.writeAll(header);
            try writer.writeInt(usize, count, .little);
            inline for (info.@"struct".fields) |s_field| {
                if (s_field.type == std.mem.Allocator) continue;
                //const field_type = s_field.type;
                //const field_info = @typeInfo(field_type);

                const field_name = s_field.name;
                const field_value = @field(self.data.*, field_name);
                try writer.writeInt(usize, field_name.len, .little);
                try writer.writeAll(field_name);
                const slice_depth = getSliceDepth(s_field.type);
                try writer.writeInt(usize, slice_depth, .little);
                const slice_shape = try getSliceShape(field_value, slice_depth);
                try writer.writeInt(usize, slice_shape.len, .little);
                for (slice_shape) |s| {
                    try writer.writeInt(usize, s, .little);
                }
                const base_type = getBaseType(s_field.type);
                const base_type_size = @sizeOf(base_type);
                try writer.writeInt(usize, base_type_size, .little);
                const flat_res = try get_flat(self.allocator, field_value);
                defer self.allocator.free(flat_res);
                try writer.writeAll(std.mem.sliceAsBytes(flat_res));
            }
        }

        fn get_flat(allocator: std.mem.Allocator, value: anytype) ![]f64 {
            var flat = std.ArrayList(f64).init(allocator);
            errdefer flat.deinit();

            try flatten_recursive(value, &flat);

            return flat.toOwnedSlice(); // caller owns this memory
        }

        fn flatten_recursive(value: anytype, flat: *std.ArrayList(f64)) !void {
            const Type = @TypeOf(value);
            const info = @typeInfo(Type);

            switch (info) {
                .pointer => |ptr_info| {
                    if (ptr_info.size == .slice) {
                        for (value) |item| {
                            try flatten_recursive(item, flat);
                        }
                        return;
                    }
                },
                .array => {
                    for (value) |item| {
                        try flatten_recursive(item, flat);
                    }
                    return;
                },
                else => {
                    try flat.append(value);
                },
            }
        }

        fn getBaseType(comptime Type: type) type {
            const info = @typeInfo(Type);
            return switch (info) {
                .pointer => |ptr_info| if (ptr_info.size == .slice)
                    getBaseType(ptr_info.child)
                else
                    Type,
                else => Type,
            };
        }

        fn getSliceShape(value: anytype, depth: usize) ![]usize {
            const allocator = std.heap.page_allocator;
            var shape = try allocator.alloc(usize, depth);

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

        fn getSliceDepth(comptime field_type: type) usize {
            const info = @typeInfo(field_type);
            if (info == .pointer and info.pointer.size == .slice) {
                return 1 + getSliceDepth(info.pointer.child);
            }
            return 0;
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
