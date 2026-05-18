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

pub const WindowBackground = enum(u32) {
    solid = 0, // should be "opaque" but it's a Zig keyword
    transparent = 1,
    blurred = 2,
};

pub const WindowAppearance = enum(u32) {
    system = 0,
    aqua = 1,
    dark_aqua = 2,
    vibrant_light = 3,
    vibrant_dark = 4,
};

pub const WindowToolbarStyle = enum(u32) {
    automatic = 0,
    expanded = 1,
    preference = 2,
    unified = 3,
    unified_compact = 4,
};

pub const WindowTitlebarSeparatorStyle = enum(u32) {
    automatic = 0,
    none = 1,
    line = 2,
    shadow = 3,
};

pub const WindowChrome = struct {
    titled: bool = true,
    closable: bool = true,
    miniaturizable: bool = true,
    resizable: bool = true,
    full_size_content: bool = false,
    titlebar_transparent: bool = false,
    title_visible: bool = true,
    movable: bool = true,
    movable_by_background: bool = false,
    has_shadow: bool = true,
    traffic_light_position: ?[2]f64 = null,
    background: WindowBackground = .solid,
    appearance: WindowAppearance = .system,
    toolbar_style: WindowToolbarStyle = .automatic,
    titlebar_separator_style: WindowTitlebarSeparatorStyle = .automatic,

    pub fn customTitlebar(traffic_light_position: ?[2]f64) WindowChrome {
        return .{
            .full_size_content = true,
            .titlebar_transparent = true,
            .title_visible = false,
            .movable_by_background = true,
            .titlebar_separator_style = .none,
            .traffic_light_position = traffic_light_position,
        };
    }

    fn raw(chrome: WindowChrome) RawWindowChrome {
        var flags: u32 = 0;
        if (chrome.titled) flags |= raw_window_titled;
        if (chrome.closable) flags |= raw_window_closable;
        if (chrome.miniaturizable) flags |= raw_window_miniaturizable;
        if (chrome.resizable) flags |= raw_window_resizable;
        if (chrome.full_size_content or chrome.titlebar_transparent) flags |= raw_window_full_size_content;
        if (chrome.titlebar_transparent) flags |= raw_window_titlebar_transparent;
        if (chrome.title_visible) flags |= raw_window_title_visible;
        if (chrome.movable) flags |= raw_window_movable;
        if (chrome.movable_by_background) flags |= raw_window_movable_by_background;
        if (chrome.has_shadow) flags |= raw_window_has_shadow;

        var traffic_light_x: f64 = 0.0;
        var traffic_light_y: f64 = 0.0;
        if (chrome.traffic_light_position) |position| {
            flags |= raw_window_traffic_light_position;
            traffic_light_x = position[0];
            traffic_light_y = position[1];
        }

        return .{
            .flags = flags,
            .background = @intFromEnum(chrome.background),
            .toolbar_style = @intFromEnum(chrome.toolbar_style),
            .titlebar_separator_style = @intFromEnum(chrome.titlebar_separator_style),
            .appearance = @intFromEnum(chrome.appearance),
            .traffic_light_x = traffic_light_x,
            .traffic_light_y = traffic_light_y,
        };
    }

    fn valid(chrome: WindowChrome) bool {
        if (!chrome.titled and (chrome.full_size_content or chrome.titlebar_transparent or chrome.traffic_light_position != null)) return false;
        if (chrome.traffic_light_position) |position| {
            if (position[0] < 0.0 or position[1] < 0.0) return false;
            if (!std.math.isFinite(position[0]) or !std.math.isFinite(position[1])) return false;
        }
        return true;
    }
};

pub const WindowOptions = struct {
    title: [:0]const u8 = "ZPUI",
    size_points: [2]f64 = .{ 960.0, 600.0 },
    chrome: WindowChrome = .{},
    draw: DrawFn = drawClear,
    user_data: ?*anyopaque = null,
};

const raw_window_titled: u32 = 1 << 0;
const raw_window_closable: u32 = 1 << 1;
const raw_window_miniaturizable: u32 = 1 << 2;
const raw_window_resizable: u32 = 1 << 3;
const raw_window_full_size_content: u32 = 1 << 4;
const raw_window_titlebar_transparent: u32 = 1 << 5;
const raw_window_title_visible: u32 = 1 << 6;
const raw_window_movable: u32 = 1 << 7;
const raw_window_movable_by_background: u32 = 1 << 8;
const raw_window_has_shadow: u32 = 1 << 9;
const raw_window_traffic_light_position: u32 = 1 << 10;

const RawWindowChrome = extern struct {
    flags: u32 = 0,
    background: u32 = 0,
    toolbar_style: u32 = 0,
    titlebar_separator_style: u32 = 0,
    appearance: u32 = 0,
    reserved: u32 = 0,
    traffic_light_x: f64 = 0.0,
    traffic_light_y: f64 = 0.0,
};

comptime {
    std.debug.assert(@sizeOf(RawWindowChrome) == 40);
    std.debug.assert(@offsetOf(RawWindowChrome, "flags") == 0);
    std.debug.assert(@offsetOf(RawWindowChrome, "traffic_light_x") == 24);
    std.debug.assert(@offsetOf(RawWindowChrome, "traffic_light_y") == 32);
}

extern fn zpui_macos_init_window(title: [*:0]const u8, width: f64, height: f64, chrome: RawWindowChrome) c_int;
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
    keys: [frame.max_key_events]frame.KeyEvent = @splat(.{}),
    text: [frame.max_text_events]frame.TextInputEvent = @splat(.{}),
    mouse: [frame.max_mouse_events]frame.MouseEvent = @splat(.{}),
    scroll: [frame.max_scroll_events]frame.ScrollEvent = @splat(.{}),
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
    pub const RenderMetrics = surface.RenderMetrics;

    fn native(ctx: *DrawContext) *NativeDrawContext {
        return @ptrCast(@alignCast(ctx));
    }

    pub fn userData(ctx: *DrawContext, comptime T: type) ?*T {
        const ptr = ctx.native().user_data orelse return null;
        return @ptrCast(@alignCast(ptr));
    }

    pub fn defaultFont(ctx: *DrawContext) text.FontHandle {
        return ctx.native().surface.defaultFont();
    }

    pub fn loadSystemFont(ctx: *DrawContext, name: [:0]const u8, options: text.FontLoadOptions) surface.Error!text.FontHandle {
        return ctx.native().surface.loadSystemFont(name, options);
    }

    pub fn loadFontFile(ctx: *DrawContext, path: [:0]const u8, options: text.FontLoadOptions) surface.Error!text.FontHandle {
        return ctx.native().surface.loadFontFile(path, options);
    }

    pub fn loadFontBytes(ctx: *DrawContext, bytes: []const u8, options: text.FontLoadOptions) surface.Error!text.FontHandle {
        return ctx.native().surface.loadFontBytes(bytes, options);
    }

    pub fn fontInfo(ctx: *DrawContext, handle: text.FontHandle) surface.Error!text.FontInfo {
        return ctx.native().surface.fontInfo(handle);
    }

    pub fn shapeLine(ctx: *DrawContext, storage: *text.ShapedLineStorage, runs: []const text.TextRun) surface.Error!text.ShapedLine {
        return ctx.native().surface.shapeLine(storage, runs);
    }

    pub fn prepareTextLine(ctx: *DrawContext, storage: *text.PreparedLineStorage, shaped: text.ShapedLine, runs: []const text.TextRun) surface.Error!text.PreparedLine {
        return ctx.native().surface.prepareTextLine(storage, shaped, runs);
    }

    pub fn beginTextFrame(ctx: *DrawContext, cache: anytype) void {
        _ = ctx;
        cache.beginFrame();
    }

    pub fn layoutLineCached(ctx: *DrawContext, cache: anytype, runs: []const text.TextRun) surface.Error!text.ShapedLine {
        return ctx.layoutLineCachedKey(cache, try text.lineCacheKey(runs), runs);
    }

    pub fn layoutLineCachedKey(ctx: *DrawContext, cache: anytype, key: text.LineCacheKey, runs: []const text.TextRun) surface.Error!text.ShapedLine {
        if (try cache.lookup(key)) |cached| return cached;

        const shaped = try ctx.native().surface.shapeLine(&cache.scratch, runs);
        return cache.store(key, shaped);
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
        native_ctx.surface.beginMetricsFrame();
        const input_snapshot = options.input orelse native_ctx.input_storage.read();
        const scale: f32 = @floatCast(@max(native_ctx.surface.scale, 1.0));
        return frame.Frame.begin(&native_ctx.surface.frame_storage, .{
            .frame_size_points = .{
                @as(f32, @floatCast(native_ctx.surface.drawable_size_pixels.width)) / scale,
                @as(f32, @floatCast(native_ctx.surface.drawable_size_pixels.height)) / scale,
            },
            .scale = scale,
            .clear_color = options.clear_color,
            .input = input_snapshot,
        });
    }

    pub fn renderMetrics(ctx: *DrawContext) RenderMetrics {
        return ctx.native().surface.renderMetrics();
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
    _ = surface.zpui_surface_create_with_options;
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
        error.InvalidBounds,
        error.InvalidGap,
        error.InvalidConstraints,
        error.InvalidSize,
        error.NumericOverflow,
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
    if (options.title.len == 0 or
        options.size_points[0] <= 0.0 or
        options.size_points[1] <= 0.0 or
        !std.math.isFinite(options.size_points[0]) or
        !std.math.isFinite(options.size_points[1]) or
        !options.chrome.valid())
    {
        return Error.InvalidWindowOptions;
    }

    active_draw = options.draw;
    active_user_data = options.user_data;
    defer {
        active_draw = drawClear;
        active_user_data = null;
    }

    return switch (zpui_macos_init_window(options.title.ptr, options.size_points[0], options.size_points[1], options.chrome.raw())) {
        0 => {},
        2 => Error.MetalUnavailable,
        else => Error.CocoaStartupFailed,
    };
}

fn drawClear(ctx: *DrawContext) DrawError!void {
    var f = ctx.beginFrame(.{});
    const out = try f.finish();
    try ctx.drawScene(&out);
}

test "macos window chrome packs into stable Objective C ABI data" {
    const chrome = WindowChrome.customTitlebar(.{ 12.0, 10.0 });
    const raw = chrome.raw();

    try std.testing.expect(chrome.valid());
    try std.testing.expect((raw.flags & raw_window_titled) != 0);
    try std.testing.expect((raw.flags & raw_window_full_size_content) != 0);
    try std.testing.expect((raw.flags & raw_window_titlebar_transparent) != 0);
    try std.testing.expect((raw.flags & raw_window_title_visible) == 0);
    try std.testing.expect((raw.flags & raw_window_movable_by_background) != 0);
    try std.testing.expect((raw.flags & raw_window_traffic_light_position) != 0);
    try std.testing.expectEqual(@as(f64, 12.0), raw.traffic_light_x);
    try std.testing.expectEqual(@as(f64, 10.0), raw.traffic_light_y);
}

test "macos window chrome rejects impossible titlebar combinations" {
    try std.testing.expect(!(WindowChrome{ .titled = false, .titlebar_transparent = true }).valid());
    try std.testing.expect(!(WindowChrome{ .traffic_light_position = .{ -1.0, 0.0 } }).valid());
    try std.testing.expect(!(WindowChrome{ .traffic_light_position = .{ std.math.inf(f64), 0.0 } }).valid());
}

test "draw error status covers layout errors without error-cast traps" {
    try std.testing.expectEqual(surface.Status.frame_encoding_failed, drawErrorStatus(error.InvalidBounds));
    try std.testing.expectEqual(surface.Status.frame_encoding_failed, drawErrorStatus(error.InvalidGap));
    try std.testing.expectEqual(surface.Status.frame_encoding_failed, drawErrorStatus(error.InvalidConstraints));
    try std.testing.expectEqual(surface.Status.frame_encoding_failed, drawErrorStatus(error.InvalidSize));
    try std.testing.expectEqual(surface.Status.frame_encoding_failed, drawErrorStatus(error.NumericOverflow));
}
