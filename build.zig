const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zmtl4_dep = b.dependency("zmtl4", .{
        .target = target,
        .optimize = optimize,
    });
    const zmtl4 = zmtl4_dep.module("zmtl4");

    const core = b.addModule("zpui-core", .{
        .root_source_file = b.path("src/core.zig"),
        .target = target,
        .optimize = optimize,
    });

    const app = addAppModule(b, "zpui-app", target, optimize, zmtl4);
    _ = addAppModule(b, "zpui", target, optimize, zmtl4);

    const exe = b.addExecutable(.{
        .name = "zpui",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zpui-app", .module = app },
            },
        }),
    });
    b.installArtifact(exe);
    installMetalShaders(b, target);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the ZPUI host window");
    run_step.dependOn(&run_cmd.step);

    const core_tests = b.addTest(.{ .root_module = core });
    const run_core_tests = b.addRunArtifact(core_tests);

    const app_tests = b.addTest(.{ .root_module = app });
    const run_app_tests = b.addRunArtifact(app_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_core_tests.step);
    test_step.dependOn(&run_app_tests.step);
}

fn addAppModule(
    b: *std.Build,
    name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    zmtl4: *std.Build.Module,
) *std.Build.Module {
    const module = b.addModule(name, .{
        .root_source_file = b.path("src/zpui.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.addImport("zmtl4", zmtl4);
    linkMacOSPlatform(b, module, target);
    return module;
}

fn linkMacOSPlatform(b: *std.Build, module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    if (target.result.os.tag != .macos) return;

    module.addCSourceFile(.{
        .file = b.path("src/platform/macos_app.m"),
        .flags = &.{"-fobjc-arc"},
        .language = .objective_c,
    });
    module.linkFramework("Cocoa", .{});
    module.linkFramework("CoreGraphics", .{});
    module.linkFramework("CoreText", .{});
    module.linkFramework("Metal", .{});
    module.linkFramework("QuartzCore", .{});
    module.linkSystemLibrary("objc", .{});
}

fn installMetalShaders(b: *std.Build, target: std.Build.ResolvedTarget) void {
    if (target.result.os.tag != .macos) return;

    const compile_shader = b.addSystemCommand(&.{ "xcrun", "-sdk", "macosx", "metal", "-c" });
    compile_shader.addFileArg(b.path("src/shaders/solid_quad.metal"));
    compile_shader.addArg("-o");
    const air = compile_shader.addOutputFileArg("solid_quad.air");

    const link_shader = b.addSystemCommand(&.{ "xcrun", "-sdk", "macosx", "metallib" });
    link_shader.addFileArg(air);
    link_shader.addArg("-o");
    const metallib = link_shader.addOutputFileArg("zpui.metallib");

    const install_shader = b.addInstallFileWithDir(metallib, .bin, "zpui.metallib");
    b.getInstallStep().dependOn(&install_shader.step);
}
