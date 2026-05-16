const std = @import("std");

const render = @import("render.zig");
const text = @import("text.zig");
const ui = @import("ui.zig");

pub const Error = render.SceneBuildError || ui.layout.LayoutError || error{
    HitCapacityExceeded,
} || text.Error;

pub const InputSnapshot = struct {
    cursor: ?[2]f32 = null,
    buttons: u32 = 0,
    mods: u32 = 0,
};

pub const Begin = struct {
    size: [2]f32,
    scale: f32 = 1.0,
    clear_color: render.ClearColor = .{ 0.0, 0.0, 0.0, 1.0 },
    input: InputSnapshot = .{},
    font: ?*const text.Font = null,
};

pub const Storage = struct {
    scene: render.SceneStorage = undefined,
    layout_results: [render.max_quads]ui.layout.LayoutResult = undefined,
    hit_items: [render.max_quads]ui.hit.HitItem = undefined,
    glyphs: [text.max_frame_glyphs]text.GlyphInstance = undefined,
    hit_state: ui.hit.HitState = .{},
};

pub const Frame = struct {
    storage: *Storage,
    size: [2]f32,
    scale: f32,
    input: InputSnapshot,
    font: ?*const text.Font,
    scene: render.SceneBuilder,
    hit_count: u32,
    glyph_count: u32,

    pub fn begin(storage: *Storage, options: Begin) Frame {
        return .{
            .storage = storage,
            .size = options.size,
            .scale = options.scale,
            .input = options.input,
            .font = options.font,
            .scene = render.SceneBuilder.begin(&storage.scene, options.size, options.clear_color),
            .hit_count = 0,
            .glyph_count = 0,
        };
    }

    pub fn pushDrawableClip(frame: *Frame) Error!u32 {
        return frame.scene.pushDrawableClip();
    }

    pub fn pushClip(frame: *Frame, clip: render.ClipRect) Error!u32 {
        return frame.scene.pushClip(clip);
    }

    pub fn beginBatch(frame: *Frame, clip_index: u32) Error!void {
        try frame.scene.beginBatch(clip_index);
    }

    pub fn pushQuad(frame: *Frame, rect: render.Rect, color: render.Color, clip_index: u32) Error!void {
        try frame.scene.pushQuad(rect, color, clip_index);
    }

    pub fn pushFill(frame: *Frame, rect: ui.layout.Rect, color: ui.style.Color, clip_index: u32) Error!void {
        try frame.pushQuad(renderRect(rect), renderColor(color), clip_index);
    }

    pub fn pack(frame: *Frame, spec: ui.layout.Pack, items: []const ui.layout.LayoutItem) Error![]const ui.layout.LayoutResult {
        if (items.len > frame.storage.layout_results.len) return ui.layout.LayoutError.OutputTooSmall;
        _ = try ui.layout.pack(spec, items, frame.storage.layout_results[0..items.len]);
        return frame.storage.layout_results[0..items.len];
    }

    pub fn splitEdge(_: *Frame, spec: ui.layout.Split) Error!ui.layout.SplitResult {
        return ui.layout.splitEdge(spec);
    }

    pub fn pushHit(frame: *Frame, item: ui.hit.HitItem) Error!void {
        if (frame.hit_count >= render.max_quads) return Error.HitCapacityExceeded;

        frame.storage.hit_items[@intCast(frame.hit_count)] = item;
        frame.hit_count += 1;
    }

    pub fn hitItems(frame: *const Frame) []const ui.hit.HitItem {
        return frame.storage.hit_items[0..@intCast(frame.hit_count)];
    }

    pub fn hitState(frame: *Frame) *ui.hit.HitState {
        return &frame.storage.hit_state;
    }

    pub fn resolveHot(frame: *Frame) ui.hit.HitId {
        const cursor = frame.input.cursor orelse {
            frame.storage.hit_state.hot = ui.hit.none;
            return ui.hit.none;
        };
        const point = ui.layout.Point.init(cursor[0], cursor[1]);
        const id = ui.hit.hitTest(point, frame.hitItems());
        frame.storage.hit_state.hot = id;
        return id;
    }

    pub fn pushText(frame: *Frame, origin: ui.layout.Point, bytes: []const u8, color: ui.style.Color) Error!text.PushResult {
        const font = frame.font orelse return text.Error.NoFont;
        const used: usize = @intCast(frame.glyph_count);
        const result = try text.pushAscii(
            font,
            frame.storage.glyphs[used..],
            origin,
            bytes,
            color,
        );
        frame.glyph_count += result.glyph_count;
        return result;
    }

    pub fn glyphs(frame: *const Frame) []const text.GlyphInstance {
        return frame.storage.glyphs[0..@intCast(frame.glyph_count)];
    }

    pub fn endBatch(frame: *Frame) Error!void {
        try frame.scene.endBatch();
    }

    pub fn finish(frame: *Frame) Error!render.Scene {
        var scene = try frame.scene.finish();
        scene.glyphs = frame.glyphs();
        scene.font = frame.font;
        return scene;
    }
};

fn renderRect(rect: ui.layout.Rect) render.Rect {
    return .{
        .x = rect.x,
        .y = rect.y,
        .width = rect.width,
        .height = rect.height,
    };
}

fn renderColor(color: ui.style.Color) render.Color {
    return .{ color.r, color.g, color.b, color.a };
}

test "frame owns caller-provided scene storage for one scene" {
    var storage: Storage = .{};
    var frame = Frame.begin(&storage, .{
        .size = .{ 640.0, 480.0 },
        .scale = 2.0,
        .input = .{ .cursor = .{ 12.0, 18.0 }, .buttons = 1 },
    });

    const clip = try frame.pushDrawableClip();
    try frame.beginBatch(clip);
    try frame.pushQuad(.{
        .x = 8.0,
        .y = 10.0,
        .width = 24.0,
        .height = 18.0,
    }, .{ 1.0, 1.0, 1.0, 1.0 }, clip);
    const scene = try frame.finish();

    try std.testing.expectEqual([2]f32{ 640.0, 480.0 }, frame.size);
    try std.testing.expectEqual(@as(f32, 2.0), frame.scale);
    try std.testing.expectEqual(@as(?[2]f32, .{ 12.0, 18.0 }), frame.input.cursor);
    try std.testing.expectEqual(@as(usize, 1), scene.clips.len);
    try std.testing.expectEqual(@as(usize, 1), scene.quads.len);
    try std.testing.expectEqual(@as(usize, 1), scene.batches.len);
}

test "frame preserves scene builder errors" {
    var storage: Storage = .{};
    var frame = Frame.begin(&storage, .{ .size = .{ 320.0, 200.0 } });
    const clip = try frame.pushDrawableClip();

    try std.testing.expectError(Error.NoOpenBatch, frame.pushQuad(.{
        .x = 0.0,
        .y = 0.0,
        .width = 1.0,
        .height = 1.0,
    }, .{ 1.0, 1.0, 1.0, 1.0 }, clip));
}

test "frame owns layout scratch and reports capacity errors" {
    var storage: Storage = .{};
    var frame = Frame.begin(&storage, .{ .size = .{ 64.0, 64.0 } });
    const items = [_]ui.layout.LayoutItem{
        ui.layout.LayoutItem.fixed(ui.layout.Size.init(12.0, 8.0)),
        ui.layout.LayoutItem.fixed(ui.layout.Size.init(10.0, 8.0)),
    };

    const results = try frame.pack(.{
        .bounds = ui.layout.Rect.init(4.0, 6.0, 40.0, 20.0),
        .gap = 2.0,
    }, items[0..]);

    try std.testing.expectEqual(@as(usize, items.len), results.len);
    try std.testing.expectEqual(ui.layout.Rect.init(4.0, 6.0, 12.0, 8.0), results[0].rect);
    try std.testing.expectEqual(ui.layout.Rect.init(18.0, 6.0, 10.0, 8.0), results[1].rect);

    var too_many: [render.max_quads + 1]ui.layout.LayoutItem = undefined;
    @memset(&too_many, ui.layout.LayoutItem.fixed(ui.layout.Size.init(1.0, 1.0)));
    try std.testing.expectError(ui.layout.LayoutError.OutputTooSmall, frame.pack(.{
        .bounds = ui.layout.Rect.init(0.0, 0.0, 1.0, 1.0),
    }, too_many[0..]));
}

test "frame resolves hot id through frame-owned hit stream" {
    var storage: Storage = .{};
    storage.hit_state = .{ .hot = 99, .active = 7, .focus = 8 };

    var frame = Frame.begin(&storage, .{
        .size = .{ 100.0, 100.0 },
        .input = .{ .cursor = .{ 16.0, 16.0 } },
    });

    try frame.pushHit(ui.hit.HitItem.init(1, ui.layout.Rect.init(0.0, 0.0, 30.0, 30.0)));
    try frame.pushHit(ui.hit.HitItem.init(2, ui.layout.Rect.init(10.0, 10.0, 30.0, 30.0)));

    try std.testing.expectEqual(@as(ui.hit.HitId, 2), frame.resolveHot());
    try std.testing.expectEqual(@as(ui.hit.HitId, 2), frame.hitState().hot);
    try std.testing.expectEqual(@as(ui.hit.HitId, 7), frame.hitState().active);
    try std.testing.expectEqual(@as(ui.hit.HitId, 8), frame.hitState().focus);

    var next = Frame.begin(&storage, .{ .size = .{ 100.0, 100.0 } });
    try std.testing.expectEqual(ui.hit.none, next.resolveHot());
    try std.testing.expectEqual(@as(ui.hit.HitId, 7), next.hitState().active);
    try std.testing.expectEqual(@as(ui.hit.HitId, 8), next.hitState().focus);
}

test "frame rejects hit stream overflow" {
    var storage: Storage = .{};
    var frame = Frame.begin(&storage, .{ .size = .{ 100.0, 100.0 } });
    const item = ui.hit.HitItem.init(1, ui.layout.Rect.init(0.0, 0.0, 1.0, 1.0));

    for (0..render.max_quads) |_| {
        try frame.pushHit(item);
    }
    try std.testing.expectError(Error.HitCapacityExceeded, frame.pushHit(item));
}

test "frame push fill converts style color into scene quads" {
    var storage: Storage = .{};
    var frame = Frame.begin(&storage, .{ .size = .{ 64.0, 64.0 } });
    const clip = try frame.pushDrawableClip();

    try frame.beginBatch(clip);
    try frame.pushFill(
        ui.layout.Rect.init(3.0, 4.0, 12.0, 14.0),
        ui.style.Color.rgba(0.1, 0.2, 0.3, 0.4),
        clip,
    );
    const scene = try frame.finish();

    try std.testing.expectEqual(render.Rect{ .x = 3.0, .y = 4.0, .width = 12.0, .height = 14.0 }, scene.quads[0].rect);
    try std.testing.expectEqual(render.Color{ 0.1, 0.2, 0.3, 0.4 }, scene.quads[0].color);
}

test "frame pushes text into a caller-owned glyph stream" {
    var font: text.Font = .{};
    font.glyphs['z'] = .{
        .codepoint = 'z',
        .atlas_width = 5,
        .atlas_height = 7,
        .advance = 6.0,
        .flags = text.glyph_present | text.glyph_visible,
    };

    var storage: Storage = .{};
    var frame = Frame.begin(&storage, .{
        .size = .{ 100.0, 100.0 },
        .font = &font,
    });

    const result = try frame.pushText(ui.layout.Point.init(12.0, 18.0), "zz", ui.style.Color.rgb(0.8, 0.8, 0.8));
    const scene = try frame.finish();

    try std.testing.expectEqual(@as(u32, 2), result.glyph_count);
    try std.testing.expectEqual(@as(usize, 2), frame.glyphs().len);
    try std.testing.expectEqual(@as(usize, 2), scene.glyphs.len);
    try std.testing.expectEqual(@as(?*const text.Font, &font), scene.font);
    try std.testing.expectEqual(ui.layout.Rect.init(12.0, 18.0, 5.0, 7.0), scene.glyphs[0].rect);
    try std.testing.expectEqual(ui.layout.Rect.init(18.0, 18.0, 5.0, 7.0), scene.glyphs[1].rect);
}

test "frame push text requires an explicit font" {
    var storage: Storage = .{};
    var frame = Frame.begin(&storage, .{ .size = .{ 100.0, 100.0 } });

    try std.testing.expectError(text.Error.NoFont, frame.pushText(.{}, "z", .{}));
}
