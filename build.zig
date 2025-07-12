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
    try buildTextExe(b, target, optimize, lib_mod);
    const clean_step = b.step("clean", "clean out dir and zig-out");

    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("out")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("src/__pycache__/")).step);
    const clean_zig_cache = b.step("clean-cache", "clean 'out' dir ");
    clean_zig_cache.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);
    const delete_o_files_step = b.step("clean-obj", "Delete all .o files recursively");
    delete_o_files_step.makeFn = deleteObjectFiles;
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn deleteObjectFiles(step: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
    _ = options;
    _ = step;
    const dir = try std.fs.cwd().openDir("./", .{ .iterate = true });

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.endsWith(u8, entry.name, ".o")) {
            dir.deleteFile(entry.name) catch |err| {
                std.debug.print("Unable to delete File {s}:{s}\n", .{ entry.name, @errorName(err) });
            };
            std.debug.print("Deleted  {s}\n", .{entry.name});
        }
    }
}

inline fn buildTextExe(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    module: *std.Build.Module,
) !void {
    const test_dir_name = "tests/test-zig";

    var test_dir = try std.fs.cwd().openDir(test_dir_name, .{ .iterate = true });
    defer test_dir.close();

    var iter = test_dir.iterate();
    const run_all_step = b.step("run-all", "Run all executables");

    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
        if (std.mem.eql(u8, entry.name, "ensuredir.zig")) continue;

        const exe_name_without_ext = std.fs.path.stem(entry.name);
        const exe_source_file = b.fmt("{s}/{s}", .{ test_dir_name, entry.name });
        const exe = b.addExecutable(.{
            .name = exe_name_without_ext,
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path(exe_source_file),
        });
        exe.root_module.addImport("zdp", module);
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_all_step.dependOn(&run_cmd.step);
    }
}
