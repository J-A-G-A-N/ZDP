const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zdp",
        .root_module = lib_mod,
        .use_llvm = false,
    });

    const llvm = b.option(bool, "llvm", "Use llvm to build") orelse false;
    if (llvm) {
        lib.use_llvm = true;
    }

    b.installArtifact(lib);

    _ = b.addModule("zdp", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const clean_step = b.step("clean", "clean out dir and zig-out");
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("out")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("src/__pycache__/")).step);
    const clean_zig_cache = b.step("clean-cache", "clean 'out' dir ");
    clean_zig_cache.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
