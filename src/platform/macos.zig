const builtin = @import("builtin");
const mtl = @import("zmtl4");
const frame = @import("../frame.zig");
const render = @import("../render.zig");
const surface = @import("../surface.zig");

pub const Error = error{
    UnsupportedPlatform,
    MetalUnavailable,
    CocoaStartupFailed,
    InvalidWindowOptions,
};

pub const DrawError = frame.Error || surface.Error;
pub const DrawFn = *const fn (*DrawContext) DrawError!void;

pub const FrameOptions = struct {
    clear_color: render.ClearColor = .{ 0.0, 0.0, 0.0, 1.0 },
    input: frame.InputSnapshot = .{},
};

pub const WindowOptions = struct {
    title: [:0]const u8 = "ZPUI",
    size: [2]f64 = .{ 960.0, 600.0 },
    draw: DrawFn = drawClear,
    user_data: ?*anyopaque = null,
};

extern fn zpui_macos_init_window(title: [*:0]const u8, width: f64, height: f64) c_int;

const NativeDrawContext = struct {
    surface: *surface.Surface,
    drawable: mtl.runtime.Id,
    user_data: ?*anyopaque,
};

pub const DrawContext = opaque {
    fn native(ctx: *DrawContext) *NativeDrawContext {
        return @ptrCast(@alignCast(ctx));
    }

    pub fn userData(ctx: *DrawContext, comptime T: type) ?*T {
        const ptr = ctx.native().user_data orelse return null;
        return @ptrCast(@alignCast(ptr));
    }

    pub fn beginFrame(ctx: *DrawContext, options: FrameOptions) frame.Frame {
        const native_ctx = ctx.native();
        return frame.Frame.begin(&native_ctx.surface.frame_storage, .{
            .size = .{
                @floatCast(native_ctx.surface.drawable_size.width),
                @floatCast(native_ctx.surface.drawable_size.height),
            },
            .scale = @floatCast(native_ctx.surface.scale),
            .clear_color = options.clear_color,
            .input = options.input,
            .font = &native_ctx.surface.text_font,
        });
    }

    pub fn drawScene(ctx: *DrawContext, scene: *const render.Scene) surface.Error!void {
        const native_ctx = ctx.native();
        try native_ctx.surface.drawScene(scene, native_ctx.drawable);
    }
};

var active_draw: DrawFn = drawClear;
var active_user_data: ?*anyopaque = null;

comptime {
    _ = surface.zpui_surface_create;
    _ = surface.zpui_surface_destroy;
    _ = surface.zpui_surface_layer;
    _ = surface.zpui_surface_resize;
    _ = zpui_macos_draw_frame;
}

export fn zpui_macos_draw_frame(surface_handle: ?*surface.Surface, drawable: mtl.runtime.Id) c_int {
    const unwrapped_surface = surface_handle orelse return @intFromEnum(surface.Status.invalid_surface);

    var native_ctx: NativeDrawContext = .{
        .surface = unwrapped_surface,
        .drawable = drawable,
        .user_data = active_user_data,
    };
    const draw_ctx: *DrawContext = @ptrCast(@alignCast(&native_ctx));
    active_draw(draw_ctx) catch return @intFromEnum(surface.Status.frame_encoding_failed);
    return @intFromEnum(surface.Status.ok);
}

pub fn initWindow(options: WindowOptions) Error!void {
    if (builtin.os.tag != .macos) return Error.UnsupportedPlatform;
    if (options.title.len == 0 or options.size[0] <= 0.0 or options.size[1] <= 0.0) {
        return Error.InvalidWindowOptions;
    }

    active_draw = options.draw;
    active_user_data = options.user_data;
    defer {
        active_draw = drawClear;
        active_user_data = null;
    }

    return switch (zpui_macos_init_window(options.title.ptr, options.size[0], options.size[1])) {
        0 => {},
        2 => Error.MetalUnavailable,
        else => Error.CocoaStartupFailed,
    };
}

fn drawClear(ctx: *DrawContext) DrawError!void {
    var f = ctx.beginFrame(.{});
    const scene = try f.finish();
    try ctx.drawScene(&scene);
}
