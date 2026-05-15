const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zpui = b.addModule("zpui", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    linkNativeMacOS(b, zpui, target);

    const exe = b.addExecutable(.{
        .name = "zpui",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zpui", .module = zpui },
            },
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the native ZPUI smoke test");
    run_step.dependOn(&run_cmd.step);

    const mod_tests = b.addTest(.{ .root_module = zpui });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

fn linkNativeMacOS(b: *std.Build, module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    if (target.result.os.tag != .macos) return;

    module.addCSourceFile(.{
        .file = b.path("src/native/macos_app.m"),
        .flags = &.{"-fobjc-arc"},
        .language = .objective_c,
    });
    module.linkFramework("Cocoa", .{});
    module.linkFramework("Metal", .{});
    module.linkFramework("QuartzCore", .{});
    module.linkSystemLibrary("objc", .{});
}
