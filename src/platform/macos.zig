const std = @import("std");
const builtin = @import("builtin");
const mtl = @import("zmtl4");
const frame = @import("../frame.zig");
const mask = @import("../mask.zig");
const macos_text = @import("macos_text.zig");
const scene = @import("../scene.zig");
const surface = @import("../surface.zig");
const text = @import("../text.zig");

pub const Error = error{
    UnsupportedPlatform,
    MetalUnavailable,
    CocoaStartupFailed,
    InvalidWindowOptions,
};

pub const DrawError = frame.Error || surface.Error;
pub const DrawFn = *const fn (*DrawContext) DrawError!void;

pub const FrameOptions = struct {
    clear_color: scene.ClearColor = .{ 0.0, 0.0, 0.0, 1.0 },
    input: ?frame.InputSnapshot = null,
};

pub const WindowOptions = struct {
    title: [:0]const u8 = "ZPUI",
    size: [2]f64 = .{ 960.0, 600.0 },
    draw: DrawFn = drawClear,
    user_data: ?*anyopaque = null,
};

extern fn zpui_macos_init_window(title: [*:0]const u8, width: f64, height: f64) c_int;
extern fn zpui_macos_request_redraw() void;
extern fn zpui_macos_input_snapshot(out: *RawInputSnapshot) void;

const RawInputSnapshot = extern struct {
    has_cursor: u32 = 0,
    buttons: u32 = 0,
    mods: u32 = 0,
    window: u32 = 0,
    cursor_x: f32 = 0.0,
    cursor_y: f32 = 0.0,
    key_count: u32 = 0,
    text_count: u32 = 0,
    mouse_count: u32 = 0,
    scroll_count: u32 = 0,
    keys: [frame.max_key_events]frame.KeyEvent = [_]frame.KeyEvent{.{}} ** frame.max_key_events,
    text: [frame.max_text_events]frame.TextInputEvent = [_]frame.TextInputEvent{.{}} ** frame.max_text_events,
    mouse: [frame.max_mouse_events]frame.MouseEvent = [_]frame.MouseEvent{.{}} ** frame.max_mouse_events,
    scroll: [frame.max_scroll_events]frame.ScrollEvent = [_]frame.ScrollEvent{.{}} ** frame.max_scroll_events,
};

comptime {
    std.debug.assert(@sizeOf(RawInputSnapshot) == 6696);
    std.debug.assert(@offsetOf(RawInputSnapshot, "has_cursor") == 0);
    std.debug.assert(@offsetOf(RawInputSnapshot, "cursor_x") == 16);
    std.debug.assert(@offsetOf(RawInputSnapshot, "key_count") == 24);
    std.debug.assert(@offsetOf(RawInputSnapshot, "keys") == 40);
    std.debug.assert(@offsetOf(RawInputSnapshot, "text") == 2088);
    std.debug.assert(@offsetOf(RawInputSnapshot, "mouse") == 3624);
    std.debug.assert(@offsetOf(RawInputSnapshot, "scroll") == 5672);
}

const InputStorage = struct {
    raw: RawInputSnapshot = .{},
    loaded: bool = false,

    fn read(storage: *InputStorage) frame.InputSnapshot {
        if (!storage.loaded) {
            zpui_macos_input_snapshot(&storage.raw);
            storage.loaded = true;
        }
        const key_count: usize = @intCast(@min(storage.raw.key_count, frame.max_key_events));
        const text_count: usize = @intCast(@min(storage.raw.text_count, frame.max_text_events));
        const mouse_count: usize = @intCast(@min(storage.raw.mouse_count, frame.max_mouse_events));
        const scroll_count: usize = @intCast(@min(storage.raw.scroll_count, frame.max_scroll_events));
        return .{
            .cursor = if (storage.raw.has_cursor != 0) .{ storage.raw.cursor_x, storage.raw.cursor_y } else null,
            .buttons = storage.raw.buttons,
            .mods = storage.raw.mods,
            .keys = storage.raw.keys[0..key_count],
            .text = storage.raw.text[0..text_count],
            .mouse = storage.raw.mouse[0..mouse_count],
            .scroll = storage.raw.scroll[0..scroll_count],
            .window = storage.raw.window,
        };
    }
};

const NativeDrawContext = struct {
    surface: *surface.Surface,
    drawable: mtl.runtime.Id,
    user_data: ?*anyopaque,
    input_storage: InputStorage = .{},
};

pub const DrawContext = opaque {
    fn native(ctx: *DrawContext) *NativeDrawContext {
        return @ptrCast(@alignCast(ctx));
    }

    pub fn userData(ctx: *DrawContext, comptime T: type) ?*T {
        const ptr = ctx.native().user_data orelse return null;
        return @ptrCast(@alignCast(ptr));
    }

    pub fn setFont(ctx: *DrawContext, options: text.FontOptions) surface.Error!void {
        const native_ctx = ctx.native();
        try native_ctx.surface.setFont(options);
    }

    pub fn setFontSlot(ctx: *DrawContext, slot: u32, options: text.FontOptions) surface.Error!void {
        const native_ctx = ctx.native();
        try native_ctx.surface.setFontSlot(slot, options);
    }

    pub fn resolvedFontName(ctx: *DrawContext) []const u8 {
        return ctx.native().surface.resolvedFontName();
    }

    pub fn resolvedFontNameSlot(ctx: *DrawContext, slot: u32) surface.Error![]const u8 {
        return ctx.native().surface.resolvedFontNameSlot(slot);
    }

    pub fn maskAtlas(ctx: *DrawContext) *const mask.AtlasStorage {
        return ctx.native().surface.maskAtlas();
    }

    pub fn maskAtlasRect(ctx: *DrawContext, id: u32) surface.Error!mask.AtlasRect {
        return ctx.native().surface.maskAtlasRect(id);
    }

    pub fn setMaskAtlas(ctx: *DrawContext, atlas: *const mask.AtlasStorage) surface.Error!void {
        try ctx.native().surface.setMaskAtlas(atlas);
    }

    pub fn input(ctx: *DrawContext) frame.InputSnapshot {
        return ctx.native().input_storage.read();
    }

    pub fn requestRedraw(_: *DrawContext) void {
        zpui_macos_request_redraw();
    }

    pub fn beginFrame(ctx: *DrawContext, options: FrameOptions) frame.Frame {
        const native_ctx = ctx.native();
        const input_snapshot = options.input orelse native_ctx.input_storage.read();
        const scale: f32 = @floatCast(@max(native_ctx.surface.scale, 1.0));
        return frame.Frame.begin(&native_ctx.surface.frame_storage, .{
            .size = .{
                @as(f32, @floatCast(native_ctx.surface.drawable_size.width)) / scale,
                @as(f32, @floatCast(native_ctx.surface.drawable_size.height)) / scale,
            },
            .scale = scale,
            .clear_color = options.clear_color,
            .input = input_snapshot,
            .font = &native_ctx.surface.fonts()[0],
            .fonts = native_ctx.surface.fonts(),
        });
    }

    pub fn drawScene(ctx: *DrawContext, frame_scene: *const scene.Scene) surface.Error!void {
        const native_ctx = ctx.native();
        try native_ctx.surface.drawScene(frame_scene, native_ctx.drawable);
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
        .input_storage = .{},
    };
    const draw_ctx: *DrawContext = @ptrCast(@alignCast(&native_ctx));
    active_draw(draw_ctx) catch |err| return @intFromEnum(drawErrorStatus(err));
    return @intFromEnum(surface.Status.ok);
}

fn drawErrorStatus(err: DrawError) surface.Status {
    return switch (err) {
        error.HitCapacityExceeded,
        error.TextBatchCapacityExceeded,
        error.MaskCapacityExceeded,
        error.MaskBatchCapacityExceeded,
        error.InvalidGeometry,
        error.InvalidClip,
        error.InvalidClipIndex,
        error.QuadCapacityExceeded,
        error.EmptyBatch,
        error.BatchCapacityExceeded,
        error.ClipCapacityExceeded,
        error.BatchAlreadyOpen,
        error.NoOpenBatch,
        error.BatchClipMismatch,
        error.OutputTooSmall,
        error.NoFont,
        error.GlyphCapacityExceeded,
        error.MissingGlyph,
        error.UnsupportedCodepoint,
        error.InvalidAtlas,
        => .frame_encoding_failed,
        else => surface.Status.fromError(@errorCast(err)),
    };
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

pub fn registerFontFile(path: [:0]const u8) macos_text.Error!void {
    try macos_text.registerFontFile(path);
}

pub fn registerFontBytes(bytes: []const u8) macos_text.Error!void {
    try macos_text.registerFontBytes(bytes);
}

fn drawClear(ctx: *DrawContext) DrawError!void {
    var f = ctx.beginFrame(.{});
    const out = try f.finish();
    try ctx.drawScene(&out);
}
