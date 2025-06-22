const std = @import("std");
pub fn ensureDir(name: []const u8) !void {
    const cwd = std.fs.cwd();
    cwd.access(name, .{}) catch |err| switch (err) {
        error.FileNotFound => try cwd.makeDir(name),
        else => {
            std.debug.print("{any}\n", .{err});
        },
    };
}
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const dir_name = "out";
    try ensureDir(dir_name);

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("write_data_lib", lib_mod);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "write_data",
        .root_module = lib_mod,
        .use_llvm = false,
    });

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "executable",
        .root_module = exe_mod,
        .use_llvm = false,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    const clean_step = b.step("clean", "clean out dir and zig-out");
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path("out")).step);
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
