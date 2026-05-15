const builtin = @import("builtin");
const render = @import("render.zig");
const surface = @import("surface.zig");

pub const NativeError = error{
    UnsupportedPlatform,
    MetalUnavailable,
    CocoaStartupFailed,
};

extern fn zpui_run_macos_hello_window() c_int;

comptime {
    _ = surface.zpui_surface_create;
    _ = surface.zpui_surface_destroy;
    _ = surface.zpui_surface_layer;
    _ = surface.zpui_surface_mtl4_command_queue;
    _ = surface.zpui_surface_mtl4_command_buffer;
    _ = surface.zpui_surface_next_mtl4_command_allocator;
    _ = surface.zpui_surface_signal_frame_completion;
    _ = surface.zpui_surface_argument_table;
    _ = surface.zpui_surface_prepare_frame;
    _ = surface.zpui_surface_resize;
}

export fn zpui_build_frame(frame: *render.Frame) void {
    render.buildFrame(frame);
}

pub fn runHelloWindow() NativeError!void {
    if (builtin.os.tag != .macos) return NativeError.UnsupportedPlatform;

    return switch (zpui_run_macos_hello_window()) {
        0 => {},
        2 => NativeError.MetalUnavailable,
        else => NativeError.CocoaStartupFailed,
    };
}
