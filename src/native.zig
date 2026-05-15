const builtin = @import("builtin");
const metal = @import("gpu/metal.zig");
const render = @import("render.zig");

pub const NativeError = error{
    UnsupportedPlatform,
    MetalUnavailable,
    CocoaStartupFailed,
};

extern fn zpui_run_macos_hello_window() c_int;

comptime {
    _ = metal.zpui_metal_create_layer;
    _ = metal.zpui_metal_resize_layer;
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
