const builtin = @import("builtin");
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
    _ = surface.zpui_surface_mtl4_command_queue;
    _ = surface.zpui_surface_mtl4_command_buffer;
    _ = surface.zpui_surface_next_mtl4_command_allocator;
    _ = surface.zpui_surface_signal_frame_completion;
    _ = surface.zpui_surface_argument_table;
    _ = surface.zpui_surface_resize;
    _ = zpui_demo_prepare_frame;
}

export fn zpui_demo_prepare_frame(surface_handle: ?*surface.Surface, prepared: *surface.PreparedFrame) c_int {
    prepared.* = surface.emptyPreparedFrame();
    const unwrapped_surface = surface_handle orelse return @intFromEnum(surface.Status.invalid_surface);

    var packet: render.RenderPacket = undefined;
    solid_quads.buildPacket(&packet, .{
        @floatCast(unwrapped_surface.drawable_size.width),
        @floatCast(unwrapped_surface.drawable_size.height),
    });

    unwrapped_surface.preparePacket(&packet, prepared) catch |err| {
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
