const builtin = @import("builtin");
const mtl = @import("zmtl4");
const render = @import("../render.zig");
const solid_quads = @import("../demo/solid_quads.zig");
const surface = @import("../surface.zig");

pub const Error = error{
    UnsupportedPlatform,
    MetalUnavailable,
    CocoaStartupFailed,
};

extern fn zpui_run_macos_hello_window() c_int;

comptime {
    _ = surface.zpui_surface_create;
    _ = surface.zpui_surface_destroy;
    _ = surface.zpui_surface_layer;
    _ = surface.zpui_surface_resize;
    _ = zpui_demo_draw_frame;
}

export fn zpui_demo_draw_frame(surface_handle: ?*surface.Surface, drawable: mtl.runtime.Id) c_int {
    const unwrapped_surface = surface_handle orelse return @intFromEnum(surface.Status.invalid_surface);

    var packet: render.RenderPacket = undefined;
    solid_quads.buildPacket(&packet, .{
        @floatCast(unwrapped_surface.drawable_size.width),
        @floatCast(unwrapped_surface.drawable_size.height),
    }) catch return @intFromEnum(surface.Status.frame_encoding_failed);

    unwrapped_surface.drawPacket(&packet, drawable) catch |err| {
        return @intFromEnum(surface.Status.fromError(err));
    };
    return @intFromEnum(surface.Status.ok);
}

pub fn runHelloWindow() Error!void {
    if (builtin.os.tag != .macos) return Error.UnsupportedPlatform;

    return switch (zpui_run_macos_hello_window()) {
        0 => {},
        2 => Error.MetalUnavailable,
        else => Error.CocoaStartupFailed,
    };
}
