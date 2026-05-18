const std = @import("std");

const masking = @import("mask.zig");
const scene = @import("scene.zig");
const text = @import("text.zig");
const ui = @import("ui.zig");

const PreparedLine = text.PreparedLine;

pub const Error = scene.SceneBuildError || ui.layout.LayoutError || error{
    HitCapacityExceeded,
    TextBatchCapacityExceeded,
    MaskCapacityExceeded,
    MaskBatchCapacityExceeded,
} || text.Error;

pub const max_key_events = 64;
pub const max_text_events = 64;
pub const max_mouse_events = 64;
pub const max_scroll_events = 32;

pub const mod_shift: u32 = 1 << 0;
pub const mod_control: u32 = 1 << 1;
pub const mod_option: u32 = 1 << 2;
pub const mod_command: u32 = 1 << 3;
pub const mod_caps_lock: u32 = 1 << 4;

pub const button_left: u32 = 1 << 0;
pub const button_right: u32 = 1 << 1;
pub const button_other: u32 = 1 << 2;

pub const key_down: u32 = 1;
pub const key_up: u32 = 2;
pub const key_modifiers_changed: u32 = 3;

pub const key_repeat: u32 = 1 << 0;

pub const mouse_move: u32 = 1;
pub const mouse_down: u32 = 2;
pub const mouse_up: u32 = 3;
pub const mouse_drag: u32 = 4;

pub const window_focused: u32 = 1 << 0;
pub const window_blurred: u32 = 1 << 1;
pub const window_resized: u32 = 1 << 2;

pub const KeyEvent = extern struct {
    kind: u32 = 0,
    key_code: u32 = 0,
    logical: u32 = 0,
    mods: u32 = 0,
    flags: u32 = 0,
    timestamp: f64 = 0.0,
};

pub const TextInputEvent = extern struct {
    bytes: [8]u8 = @splat(0),
    len: u32 = 0,
    mods: u32 = 0,
    timestamp: f64 = 0.0,
};

pub const MouseEvent = extern struct {
    kind: u32 = 0,
    button: u32 = 0,
    click_count: u32 = 0,
    mods: u32 = 0,
    x: f32 = 0.0,
    y: f32 = 0.0,
    timestamp: f64 = 0.0,
};

pub const ScrollEvent = extern struct {
    dx: f32 = 0.0,
    dy: f32 = 0.0,
    precise_dx: f32 = 0.0,
    precise_dy: f32 = 0.0,
    mods: u32 = 0,
    timestamp: f64 = 0.0,
};

pub const InputSnapshot = struct {
    cursor: ?[2]f32 = null,
    buttons: u32 = 0,
    mods: u32 = 0,
    keys: []const KeyEvent = &.{},
    text: []const TextInputEvent = &.{},
    mouse: []const MouseEvent = &.{},
    scroll: []const ScrollEvent = &.{},
    window: u32 = 0,
};

pub const FrameBegin = struct {
    frame_size_points: [2]f32,
    scale: f32 = 1.0,
    clear_color: scene.ClearColor = .{ 0.0, 0.0, 0.0, 1.0 },
    input: InputSnapshot = .{},
    font: ?*const text.Font = null,
    fonts: []const text.Font = &.{},
};

pub const DrawOptions = struct {
    clip: u32,
    layer: u32 = scene.layer_content,
};

/// Draw commands for one clip and layer
pub const Draw = struct {
    frame: *Frame,
    clip: u32,
    layer: u32,

    pub fn fill(draw: *Draw, bounds: ui.layout.Rect, color: ui.style.Color) Error!void {
        try draw.frame.pushFillDraw(bounds, color, draw.clip, draw.layer);
    }

    pub fn rect(draw: *Draw, bounds: ui.layout.Rect, style: ui.style.Style) Error!void {
        try draw.frame.pushStyledRectDraw(bounds, style, draw.clip, draw.layer);
    }

    pub fn border(draw: *Draw, bounds: ui.layout.Rect, width: f32, color: ui.style.Color) Error!void {
        try draw.rect(bounds, .{
            .border = ui.style.Border.solid(width, color),
        });
    }

    pub fn rule(draw: *Draw, edge: ui.layout.Edge, bounds: ui.layout.Rect, width: f32, color: ui.style.Color) Error!void {
        try draw.fill(ruleRect(edge, bounds, width), color);
    }

    pub fn textLine(draw: *Draw, origin: ui.layout.Point, line: PreparedLine) Error!void {
        try draw.frame.flushQuads();
        try draw.frame.pushPreparedTextLine(origin, line, draw.clip, draw.layer);
    }

    pub fn mask(draw: *Draw, bounds: ui.layout.Rect, atlas_rect: masking.AtlasRect, color: ui.style.Color) Error!void {
        try draw.frame.pushMask(bounds, atlas_rect, color, draw.clip, draw.layer);
    }

    pub fn hit(draw: *Draw, id: ui.hit.HitId, bounds: ui.layout.Rect) Error!void {
        try draw.frame.pushHit(ui.hit.HitItem.clipped(id, bounds, try draw.frame.clipRect(draw.clip)));
    }
};

pub const Limits = scene.Limits;
pub const default_limits = scene.default_limits;

pub fn FrameStorage(comptime limits: Limits) type {
    comptime limits.assertValid();
    return struct {
        pub const storage_limits = limits;

        scene: scene.SceneStorage(limits) = undefined,
        layout_results: [limits.quads]ui.layout.LayoutResult = undefined,
        hit_items: [limits.quads]ui.hit.HitItem = undefined,
        glyphs: [limits.glyphs]text.GlyphInstance = undefined,
        text_batches: [limits.text_batches]scene.TextBatch = undefined,
        masks: [limits.masks]masking.Instance = undefined,
        mask_batches: [limits.mask_batches]scene.MaskBatch = undefined,
        hit_state: ui.hit.HitState = .{},
    };
}

pub const DefaultFrameStorage = FrameStorage(default_limits);

const StorageView = struct {
    layout_results: []ui.layout.LayoutResult,
    hit_items: []ui.hit.HitItem,
    glyphs: []text.GlyphInstance,
    text_batches: []scene.TextBatch,
    masks: []masking.Instance,
    mask_batches: []scene.MaskBatch,
    hit_state: *ui.hit.HitState,
};

/// Builds one point-space frame from caller storage
/// No heap here; scale is copied from Surface
/// Draw order comes from stream writes
pub const Frame = struct {
    pub const Begin = FrameBegin;

    storage: StorageView,
    frame_size_points: [2]f32,
    /// Copied from the surface at frame begin
    /// Used for helpers like hairline() and snapping
    scale: f32,
    input: InputSnapshot,
    font: ?*const text.Font,
    fonts: []const text.Font,
    scene: scene.SceneBuilder,
    hit_count: u32,
    glyph_count: u32,
    text_batch_count: u32,
    mask_count: u32,
    mask_batch_count: u32,
    draw_order: u32,

    pub fn begin(storage: anytype, options: Begin) Frame {
        return .{
            .storage = frameStorageView(storage),
            .frame_size_points = options.frame_size_points,
            .scale = options.scale,
            .input = options.input,
            .font = options.font,
            .fonts = options.fonts,
            .scene = scene.SceneBuilder.begin(&storage.scene, options.frame_size_points, options.clear_color),
            .hit_count = 0,
            .glyph_count = 0,
            .text_batch_count = 0,
            .mask_count = 0,
            .mask_batch_count = 0,
            .draw_order = 0,
        };
    }

    pub fn root(frame: *const Frame) ui.layout.Rect {
        return ui.layout.Rect.init(0.0, 0.0, frame.frame_size_points[0], frame.frame_size_points[1]);
    }

    pub fn clip(frame: *Frame, rect: ui.layout.Rect) Error!u32 {
        const clipped = rect.intersect(frame.root());
        return frame.pushClip(try clipRectFromPoints(clipped));
    }

    pub fn clipRect(frame: *const Frame, clip_index: u32) Error!ui.layout.Rect {
        if (clip_index >= frame.scene.clip_count) return scene.SceneBuildError.InvalidClipIndex;
        const rect = frame.scene.storage.clips[@intCast(clip_index)];
        return ui.layout.Rect.init(
            @floatFromInt(rect.x),
            @floatFromInt(rect.y),
            @floatFromInt(rect.width),
            @floatFromInt(rect.height),
        );
    }

    pub fn cut(frame: *Frame, bounds: ui.layout.Rect, edge: ui.layout.Edge, size: f32) Error!ui.layout.SplitResult {
        return frame.splitEdge(.{
            .bounds = bounds,
            .edge = edge,
            .size = size,
        });
    }

    pub fn draw(frame: *Frame, options: DrawOptions) Draw {
        return .{
            .frame = frame,
            .clip = options.clip,
            .layer = options.layer,
        };
    }

    pub fn pushFrameClip(frame: *Frame) Error!u32 {
        return frame.scene.pushFrameClip();
    }

    pub fn pushClip(frame: *Frame, clip_rect: scene.ClipRect) Error!u32 {
        return frame.scene.pushClip(clip_rect);
    }

    pub fn beginBatch(frame: *Frame, clip_index: u32) Error!void {
        try frame.scene.beginBatch(clip_index);
    }

    pub fn beginLayerBatch(frame: *Frame, clip_index: u32, layer: u32) Error!void {
        try frame.scene.beginLayerBatch(clip_index, layer);
    }

    pub fn pushQuad(frame: *Frame, rect: scene.Rect, color: scene.Color, clip_index: u32) Error!void {
        try frame.scene.pushQuad(rect, color, clip_index);
    }

    fn pushFill(frame: *Frame, rect: ui.layout.Rect, color: ui.style.Color, clip_index: u32) Error!void {
        try frame.pushQuad(sceneRectFromPoints(rect), renderColor(color), clip_index);
    }

    fn pushFillLayer(frame: *Frame, rect: ui.layout.Rect, color: ui.style.Color, clip_index: u32, layer: u32) Error!void {
        try frame.flushQuads();
        try frame.beginLayerBatch(clip_index, layer);
        try frame.pushFill(rect, color, clip_index);
        try frame.endBatch();
    }

    fn pushStyledRect(frame: *Frame, rect: ui.layout.Rect, style: ui.style.Style, clip_index: u32) Error!void {
        try frame.scene.pushStyledQuad(sceneRectFromPoints(rect), renderQuadStyle(style), clip_index);
    }

    fn pushStyledRectLayer(frame: *Frame, rect: ui.layout.Rect, style: ui.style.Style, clip_index: u32, layer: u32) Error!void {
        try frame.flushQuads();
        try frame.beginLayerBatch(clip_index, layer);
        try frame.pushStyledRect(rect, style, clip_index);
        try frame.endBatch();
    }

    fn pushFillDraw(frame: *Frame, rect: ui.layout.Rect, color: ui.style.Color, clip_index: u32, layer: u32) Error!void {
        try frame.ensureQuadBatch(clip_index, layer);
        try frame.pushFill(rect, color, clip_index);
    }

    fn pushStyledRectDraw(frame: *Frame, rect: ui.layout.Rect, style: ui.style.Style, clip_index: u32, layer: u32) Error!void {
        try frame.ensureQuadBatch(clip_index, layer);
        try frame.pushStyledRect(rect, style, clip_index);
    }

    fn ensureQuadBatch(frame: *Frame, clip_index: u32, layer: u32) Error!void {
        if (frame.scene.batch_open) {
            if (frame.scene.open_batch_clip == clip_index and frame.scene.open_batch_layer == layer) return;
            try frame.endBatch();
        }
        try frame.beginLayerBatch(clip_index, layer);
    }

    fn flushQuads(frame: *Frame) Error!void {
        if (frame.scene.batch_open) try frame.endBatch();
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
        if (atCapacity(frame.hit_count, frame.storage.hit_items.len)) return Error.HitCapacityExceeded;

        frame.storage.hit_items[@intCast(frame.hit_count)] = item;
        frame.hit_count += 1;
    }

    pub fn hitItems(frame: *const Frame) []const ui.hit.HitItem {
        return frame.storage.hit_items[0..@intCast(frame.hit_count)];
    }

    pub fn hitState(frame: *Frame) *ui.hit.HitState {
        return frame.storage.hit_state;
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

    pub fn measureText(frame: *const Frame, bytes: []const u8) Error!text.MeasureResult {
        const font = frame.font orelse return text.Error.NoFont;
        return text.measureAscii(font, bytes);
    }

    pub fn measureTextRuns(frame: *const Frame, runs: []const text.AsciiRun) Error!text.MeasureResult {
        return text.measureAsciiRunsWithFontSet(frame.fontSet(), runs);
    }

    pub fn textMetrics(frame: *const Frame) Error!text.TextMetrics {
        const font = frame.font orelse return text.Error.NoFont;
        return text.textMetrics(font);
    }

    pub fn textMetricsSlot(frame: *const Frame, slot: u32) Error!text.TextMetrics {
        return text.textMetrics(try frame.fontSet().get(slot));
    }

    pub fn placeTextInRow(frame: *const Frame, row: ui.layout.Rect) Error!text.RowTextPlacement {
        return text.placeTextInRow(try frame.textMetrics(), row.y, row.height);
    }

    pub fn physicalPixel(frame: *const Frame) f32 {
        return 1.0 / @max(frame.scale, 1.0);
    }

    pub fn hairline(frame: *const Frame) f32 {
        return frame.physicalPixel();
    }

    pub fn snap(frame: *const Frame, value: f32) f32 {
        const scale = @max(frame.scale, 1.0);
        return @round(value * scale) / scale;
    }

    pub fn snapRect(frame: *const Frame, rect: ui.layout.Rect) ui.layout.Rect {
        const x0 = frame.snap(rect.x);
        const y0 = frame.snap(rect.y);
        const x1 = frame.snap(rect.x + rect.width);
        const y1 = frame.snap(rect.y + rect.height);
        return ui.layout.Rect.init(x0, y0, @max(x1 - x0, 0.0), @max(y1 - y0, 0.0));
    }

    fn pushText(frame: *Frame, origin: ui.layout.Point, bytes: []const u8, color: ui.style.Color, clip_index: u32) Error!text.PushResult {
        return frame.pushTextLayer(origin, bytes, color, clip_index, scene.layer_content);
    }

    fn pushTextLayer(frame: *Frame, origin: ui.layout.Point, bytes: []const u8, color: ui.style.Color, clip_index: u32, layer: u32) Error!text.PushResult {
        const runs = [_]text.AsciiRun{.{ .bytes = bytes, .color = color }};
        return frame.pushTextRuns(origin, runs[0..], clip_index, layer);
    }

    fn pushTextRuns(frame: *Frame, origin: ui.layout.Point, runs: []const text.AsciiRun, clip_index: u32, layer: u32) Error!text.PushResult {
        if (frame.fonts.len == 0 and frame.font == null) return text.Error.NoFont;
        if (clip_index >= frame.scene.clip_count) return scene.SceneBuildError.InvalidClipIndex;
        try frame.flushQuads();
        const used: usize = @intCast(frame.glyph_count);
        const result = try text.pushAsciiRunsWithFontSet(
            frame.fontSet(),
            frame.storage.glyphs[used..],
            origin,
            runs,
        );
        if (result.glyph_count != 0) {
            if (atCapacity(frame.text_batch_count, frame.storage.text_batches.len)) return Error.TextBatchCapacityExceeded;
            frame.storage.text_batches[@intCast(frame.text_batch_count)] = .{
                .vertex_start = frame.glyph_count * scene.vertices_per_glyph,
                .vertex_count = result.glyph_count * scene.vertices_per_glyph,
                .clip_index = clip_index,
                .layer = layer,
                .order = frame.nextOrder(),
            };
            frame.text_batch_count += 1;
        }
        frame.glyph_count += result.glyph_count;
        return result;
    }

    fn pushPreparedTextLine(frame: *Frame, origin: ui.layout.Point, line: text.PreparedLine, clip_index: u32, layer: u32) Error!void {
        if (clip_index >= frame.scene.clip_count) return scene.SceneBuildError.InvalidClipIndex;
        if (line.glyphs.len == 0) return;
        try frame.flushQuads();

        const used: usize = @intCast(frame.glyph_count);
        if (line.glyphs.len > frame.storage.glyphs.len - used) return text.Error.GlyphCapacityExceeded;

        for (line.glyphs, 0..) |glyph, index| {
            var instance = glyph.instance;
            instance.rect.x += origin.x;
            instance.rect.y += origin.y;
            frame.storage.glyphs[used + index] = instance;
        }

        try frame.appendTextBatch(@intCast(line.glyphs.len), clip_index, layer);
    }

    fn appendTextBatch(frame: *Frame, glyph_count: u32, clip_index: u32, layer: u32) Error!void {
        if (atCapacity(frame.text_batch_count, frame.storage.text_batches.len)) return Error.TextBatchCapacityExceeded;
        const batch_index: usize = @intCast(frame.text_batch_count);
        frame.storage.text_batches[batch_index] = .{
            .vertex_start = frame.glyph_count * scene.vertices_per_glyph,
            .vertex_count = glyph_count * scene.vertices_per_glyph,
            .clip_index = clip_index,
            .layer = layer,
            .order = frame.nextOrder(),
        };
        frame.glyph_count += glyph_count;
        frame.text_batch_count += 1;
    }

    fn fontSet(frame: *const Frame) text.FontSet {
        return .{
            .fonts = frame.fonts,
            .fallback = frame.font,
        };
    }

    fn pushMask(frame: *Frame, rect: ui.layout.Rect, atlas_rect: masking.AtlasRect, color: ui.style.Color, clip_index: u32, layer: u32) Error!void {
        if (clip_index >= frame.scene.clip_count) return scene.SceneBuildError.InvalidClipIndex;
        if (rect.width <= 0.0 or rect.height <= 0.0) return scene.SceneBuildError.InvalidGeometry;
        if (atCapacity(frame.mask_count, frame.storage.masks.len)) return Error.MaskCapacityExceeded;
        try frame.flushQuads();

        const index: usize = @intCast(frame.mask_count);
        frame.storage.masks[index] = .{
            .rect = rect,
            .atlas_rect = atlas_rect,
            .color = color,
        };
        if (frame.mask_batch_count != 0) {
            const last_index: usize = @intCast(frame.mask_batch_count - 1);
            const last = &frame.storage.mask_batches[last_index];
            const adjacent = frame.draw_order != 0 and last.order == frame.draw_order - 1;
            if (last.clip_index == clip_index and last.layer == layer and adjacent) {
                last.vertex_count += scene.vertices_per_mask;
                frame.mask_count += 1;
                return;
            }
        }

        if (atCapacity(frame.mask_batch_count, frame.storage.mask_batches.len)) return Error.MaskBatchCapacityExceeded;
        frame.storage.mask_batches[@intCast(frame.mask_batch_count)] = .{
            .vertex_start = frame.mask_count * scene.vertices_per_mask,
            .vertex_count = scene.vertices_per_mask,
            .clip_index = clip_index,
            .layer = layer,
            .order = frame.nextOrder(),
        };
        frame.mask_count += 1;
        frame.mask_batch_count += 1;
    }

    pub fn glyphs(frame: *const Frame) []const text.GlyphInstance {
        return frame.storage.glyphs[0..@intCast(frame.glyph_count)];
    }

    pub fn textBatches(frame: *const Frame) []const scene.TextBatch {
        return frame.storage.text_batches[0..@intCast(frame.text_batch_count)];
    }

    pub fn masks(frame: *const Frame) []const masking.Instance {
        return frame.storage.masks[0..@intCast(frame.mask_count)];
    }

    pub fn maskBatches(frame: *const Frame) []const scene.MaskBatch {
        return frame.storage.mask_batches[0..@intCast(frame.mask_batch_count)];
    }

    pub fn endBatch(frame: *Frame) Error!void {
        try frame.scene.endBatch();
        if (frame.scene.batch_count != 0) {
            frame.scene.storage.batches[@intCast(frame.scene.batch_count - 1)].order = frame.nextOrder();
        }
    }

    pub fn finish(frame: *Frame) Error!scene.Scene {
        if (frame.scene.batch_open) try frame.endBatch();
        var out = try frame.scene.finish();
        out.glyphs = frame.glyphs();
        out.text_batches = frame.textBatches();
        out.masks = frame.masks();
        out.mask_batches = frame.maskBatches();
        return out;
    }

    fn nextOrder(frame: *Frame) u32 {
        const order = frame.draw_order;
        std.debug.assert(frame.draw_order < frame.drawCommandLimit());
        frame.draw_order += 1;
        return order;
    }

    fn drawCommandLimit(frame: *const Frame) u32 {
        return @intCast(frame.scene.storage.batches.len + frame.storage.text_batches.len + frame.storage.mask_batches.len);
    }
};

fn sceneRectFromPoints(rect: ui.layout.Rect) scene.Rect {
    return .{
        .x = rect.x,
        .y = rect.y,
        .width = rect.width,
        .height = rect.height,
    };
}

fn clipRectFromPoints(rect: ui.layout.Rect) scene.SceneBuildError!scene.ClipRect {
    if (!validRect(rect)) return scene.SceneBuildError.InvalidClip;

    // Floor the min edge and ceil the max edge so fractional layouts don't
    // lose edge pixels
    const x0 = @floor(rect.x);
    const y0 = @floor(rect.y);
    const x1 = @ceil(rect.x + rect.width);
    const y1 = @ceil(rect.y + rect.height);
    if (x1 <= x0 or y1 <= y0) return scene.SceneBuildError.InvalidClip;

    return .{
        .x = try clipCoord(x0),
        .y = try clipCoord(y0),
        .width = try clipCoord(x1 - x0),
        .height = try clipCoord(y1 - y0),
    };
}

fn frameStorageView(storage: anytype) StorageView {
    comptime @TypeOf(storage.*).storage_limits.assertValid();
    return .{
        .layout_results = storage.layout_results[0..],
        .hit_items = storage.hit_items[0..],
        .glyphs = storage.glyphs[0..],
        .text_batches = storage.text_batches[0..],
        .masks = storage.masks[0..],
        .mask_batches = storage.mask_batches[0..],
        .hit_state = &storage.hit_state,
    };
}

fn atCapacity(count: u32, len: usize) bool {
    return @as(usize, @intCast(count)) >= len;
}

fn renderColor(color: ui.style.Color) scene.Color {
    return .{ color.r, color.g, color.b, color.a };
}

fn renderQuadStyle(style: ui.style.Style) scene.QuadStyle {
    var fill = renderColor(style.fill);
    var border = renderColor(style.border.color);
    fill[3] *= style.opacity;
    border[3] *= style.opacity;
    return .{
        .fill_color = fill,
        .border_color = border,
        .radius = renderRadius(style.radius),
        .border_width = style.border.width,
    };
}

fn renderRadius(radius: ui.style.Radius) scene.Radius {
    return .{
        .top_left = radius.top_left,
        .top_right = radius.top_right,
        .bottom_right = radius.bottom_right,
        .bottom_left = radius.bottom_left,
    };
}

fn ruleRect(edge: ui.layout.Edge, rect: ui.layout.Rect, width: f32) ui.layout.Rect {
    const line_width = @max(width, 0.0);
    return switch (edge) {
        .left => ui.layout.Rect.init(rect.x, rect.y, line_width, rect.height),
        .top => ui.layout.Rect.init(rect.x, rect.y, rect.width, line_width),
        .right => ui.layout.Rect.init(rect.x + @max(rect.width - line_width, 0.0), rect.y, line_width, rect.height),
        .bottom => ui.layout.Rect.init(rect.x, rect.y + @max(rect.height - line_width, 0.0), rect.width, line_width),
    };
}

fn validRect(rect: ui.layout.Rect) bool {
    return rect.x >= 0.0 and
        rect.y >= 0.0 and
        rect.width > 0.0 and
        rect.height > 0.0 and
        std.math.isFinite(rect.x) and
        std.math.isFinite(rect.y) and
        std.math.isFinite(rect.width) and
        std.math.isFinite(rect.height);
}

fn clipCoord(value: f32) scene.SceneBuildError!u32 {
    const max_exact_u32_f32: f32 = 4_294_967_040.0;
    if (value < 0.0 or !std.math.isFinite(value)) return scene.SceneBuildError.InvalidClip;
    if (value >= max_exact_u32_f32) return std.math.maxInt(u32);
    return @intFromFloat(value);
}

test "frame uses caller-provided scene storage for one scene" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{
        .frame_size_points = .{ 640.0, 480.0 },
        .scale = 2.0,
        .input = .{ .cursor = .{ 12.0, 18.0 }, .buttons = 1 },
    });

    const clip = try frame.pushFrameClip();
    try frame.beginBatch(clip);
    try frame.pushQuad(.{
        .x = 8.0,
        .y = 10.0,
        .width = 24.0,
        .height = 18.0,
    }, .{ 1.0, 1.0, 1.0, 1.0 }, clip);
    const out = try frame.finish();

    try std.testing.expectEqual([2]f32{ 640.0, 480.0 }, frame.frame_size_points);
    try std.testing.expectEqual(@as(f32, 2.0), frame.scale);
    try std.testing.expectEqual(@as(?[2]f32, .{ 12.0, 18.0 }), frame.input.cursor);
    try std.testing.expectEqual(@as(usize, 1), out.clips.len);
    try std.testing.expectEqual(@as(usize, 1), out.quads.len);
    try std.testing.expectEqual(@as(usize, 1), out.batches.len);
}

test "input events stay plain frame data" {
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(KeyEvent));
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(TextInputEvent));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(MouseEvent));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(ScrollEvent));
    try std.testing.expectEqual(@as(usize, 8), @alignOf(KeyEvent));
    try std.testing.expectEqual(@as(usize, 8), @alignOf(TextInputEvent));
    try std.testing.expectEqual(@as(usize, 8), @alignOf(MouseEvent));
    try std.testing.expectEqual(@as(usize, 8), @alignOf(ScrollEvent));
}

test "frame preserves scene builder errors" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 320.0, 200.0 } });
    const clip = try frame.pushFrameClip();

    try std.testing.expectError(Error.NoOpenBatch, frame.pushQuad(.{
        .x = 0.0,
        .y = 0.0,
        .width = 1.0,
        .height = 1.0,
    }, .{ 1.0, 1.0, 1.0, 1.0 }, clip));
}

test "frame keeps layout scratch and reports capacity errors" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 64.0, 64.0 } });
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

    var too_many: [scene.max_quads + 1]ui.layout.LayoutItem = undefined;
    @memset(&too_many, ui.layout.LayoutItem.fixed(ui.layout.Size.init(1.0, 1.0)));
    try std.testing.expectError(ui.layout.LayoutError.OutputTooSmall, frame.pack(.{
        .bounds = ui.layout.Rect.init(0.0, 0.0, 1.0, 1.0),
    }, too_many[0..]));
}

test "frame direct API cuts roots clips and coalesces adjacent rects" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 100.0, 80.0 } });

    const root = frame.root();
    const clip = try frame.clip(root);
    const title = try frame.cut(root, .top, 20.0);
    var draw = frame.draw(.{ .clip = clip, .layer = scene.layer_surface });

    try draw.fill(title.head, ui.style.Color.rgb(0.1, 0.1, 0.1));
    try draw.rect(title.tail, .{
        .fill = ui.style.Color.rgb(0.2, 0.2, 0.2),
        .border = ui.style.Border.solid(1.0, ui.style.Color.rgb(0.8, 0.8, 0.8)),
    });
    const out = try frame.finish();

    try std.testing.expectEqual(ui.layout.Rect.init(0.0, 0.0, 100.0, 80.0), root);
    try std.testing.expectEqual(ui.layout.Rect.init(0.0, 0.0, 100.0, 20.0), title.head);
    try std.testing.expectEqual(ui.layout.Rect.init(0.0, 20.0, 100.0, 60.0), title.tail);
    try std.testing.expectEqual(@as(usize, 2), out.quads.len);
    try std.testing.expectEqual(@as(usize, 1), out.batches.len);
    try std.testing.expectEqual(@as(u32, scene.vertices_per_quad * 2), out.batches[0].vertex_count);
    try std.testing.expectEqual(scene.layer_surface, out.batches[0].layer);
}

test "frame resolves hot id through hit stream" {
    var storage: DefaultFrameStorage = .{};
    storage.hit_state = .{ .hot = 99, .active = 7, .focus = 8 };

    var frame = Frame.begin(&storage, .{
        .frame_size_points = .{ 100.0, 100.0 },
        .input = .{ .cursor = .{ 16.0, 16.0 } },
    });

    try frame.pushHit(ui.hit.HitItem.init(1, ui.layout.Rect.init(0.0, 0.0, 30.0, 30.0)));
    try frame.pushHit(ui.hit.HitItem.init(2, ui.layout.Rect.init(10.0, 10.0, 30.0, 30.0)));

    try std.testing.expectEqual(@as(ui.hit.HitId, 2), frame.resolveHot());
    try std.testing.expectEqual(@as(ui.hit.HitId, 2), frame.hitState().hot);
    try std.testing.expectEqual(@as(ui.hit.HitId, 7), frame.hitState().active);
    try std.testing.expectEqual(@as(ui.hit.HitId, 8), frame.hitState().focus);

    var next = Frame.begin(&storage, .{ .frame_size_points = .{ 100.0, 100.0 } });
    try std.testing.expectEqual(ui.hit.none, next.resolveHot());
    try std.testing.expectEqual(@as(ui.hit.HitId, 7), next.hitState().active);
    try std.testing.expectEqual(@as(ui.hit.HitId, 8), next.hitState().focus);
}

test "frame rejects hit stream overflow" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 100.0, 100.0 } });
    const item = ui.hit.HitItem.init(1, ui.layout.Rect.init(0.0, 0.0, 1.0, 1.0));

    for (0..scene.max_quads) |_| {
        try frame.pushHit(item);
    }
    try std.testing.expectError(Error.HitCapacityExceeded, frame.pushHit(item));
}

test "custom frame storage limits bound frame streams" {
    const limits: Limits = .{
        .quads = 2,
        .batches = 2,
        .clips = 2,
        .glyphs = 2,
        .text_batches = 1,
        .masks = 1,
        .mask_batches = 1,
    };
    var storage: FrameStorage(limits) = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 100.0, 100.0 } });
    const clip = try frame.pushFrameClip();
    var draw = frame.draw(.{ .clip = clip });

    const items = [_]ui.layout.LayoutItem{
        ui.layout.LayoutItem.fixed(ui.layout.Size.init(1.0, 1.0)),
        ui.layout.LayoutItem.fixed(ui.layout.Size.init(1.0, 1.0)),
        ui.layout.LayoutItem.fixed(ui.layout.Size.init(1.0, 1.0)),
    };
    try std.testing.expectError(ui.layout.LayoutError.OutputTooSmall, frame.pack(.{
        .bounds = ui.layout.Rect.init(0.0, 0.0, 10.0, 10.0),
    }, items[0..]));

    const hit = ui.hit.HitItem.init(1, ui.layout.Rect.init(0.0, 0.0, 1.0, 1.0));
    try frame.pushHit(hit);
    try frame.pushHit(hit);
    try std.testing.expectError(Error.HitCapacityExceeded, frame.pushHit(hit));

    const atlas_rect = masking.rectFromPixels(1, 1, 1, 1);
    try draw.mask(ui.layout.Rect.init(0.0, 0.0, 1.0, 1.0), atlas_rect, .{});
    try std.testing.expectError(Error.MaskCapacityExceeded, draw.mask(ui.layout.Rect.init(2.0, 0.0, 1.0, 1.0), atlas_rect, .{}));
}

test "draw hit writes a clipped hit item" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 100.0, 100.0 } });
    const clip = try frame.clip(ui.layout.Rect.init(10.0, 10.0, 20.0, 20.0));
    var draw = frame.draw(.{ .clip = clip });

    try draw.hit(42, ui.layout.Rect.init(0.0, 0.0, 40.0, 40.0));
    const items = frame.hitItems();

    try std.testing.expectEqual(@as(usize, 1), items.len);
    try std.testing.expectEqual(@as(ui.hit.HitId, 42), items[0].id);
    try std.testing.expectEqual(ui.hit.default_flags | ui.hit.flag_clip, items[0].flags);
    try std.testing.expectEqual(ui.layout.Rect.init(10.0, 10.0, 20.0, 20.0), items[0].clip);
}

test "fill helper converts style color into scene quads" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 64.0, 64.0 } });
    const clip = try frame.pushFrameClip();

    try frame.beginBatch(clip);
    try frame.pushFill(
        ui.layout.Rect.init(3.0, 4.0, 12.0, 14.0),
        ui.style.Color.rgba(0.1, 0.2, 0.3, 0.4),
        clip,
    );
    const out = try frame.finish();

    try std.testing.expectEqual(scene.Rect{ .x = 3.0, .y = 4.0, .width = 12.0, .height = 14.0 }, out.quads[0].rect);
    try std.testing.expectEqual(scene.Color{ 0.1, 0.2, 0.3, 0.4 }, out.quads[0].fill_color);
    try std.testing.expectEqual(scene.transparent, out.quads[0].border_color);
    try std.testing.expectEqual(@as(f32, 0.0), out.quads[0].border_width);
}

test "styled rect helper resolves style into render quad data" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 64.0, 64.0 } });
    const clip = try frame.pushFrameClip();

    try frame.pushStyledRectLayer(
        ui.layout.Rect.init(3.0, 4.0, 12.0, 14.0),
        .{
            .fill = ui.style.Color.rgba(0.1, 0.2, 0.3, 0.8),
            .radius = ui.style.Radius.all(4.0),
            .border = ui.style.Border.solid(1.0, ui.style.Color.rgba(0.6, 0.7, 0.8, 0.6)),
            .opacity = 0.5,
        },
        clip,
        scene.layer_surface,
    );
    const out = try frame.finish();

    try std.testing.expectEqual(scene.layer_surface, out.batches[0].layer);
    try std.testing.expectEqual(scene.Color{ 0.1, 0.2, 0.3, 0.4 }, out.quads[0].fill_color);
    try std.testing.expectEqual(scene.Color{ 0.6, 0.7, 0.8, 0.3 }, out.quads[0].border_color);
    try std.testing.expectEqual(scene.Radius{ .top_left = 4.0, .top_right = 4.0, .bottom_right = 4.0, .bottom_left = 4.0 }, out.quads[0].radius);
    try std.testing.expectEqual(@as(f32, 1.0), out.quads[0].border_width);
}

test "frame pushes text into caller glyph stream" {
    var font: text.Font = .{};
    font.glyphs['z'] = .{
        .codepoint = 'z',
        .atlas_width = 5,
        .atlas_height = 7,
        .advance = 6.0,
        .flags = text.glyph_present | text.glyph_visible,
    };

    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{
        .frame_size_points = .{ 100.0, 100.0 },
        .font = &font,
    });

    const clip = try frame.pushFrameClip();
    const measured = try frame.measureText("zz");
    const result = try frame.pushText(ui.layout.Point.init(12.0, 18.0), "zz", ui.style.Color.rgb(0.8, 0.8, 0.8), clip);
    const out = try frame.finish();

    try std.testing.expectEqual(@as(f32, 12.0), measured.advance);
    try std.testing.expectEqual(@as(u32, 2), measured.glyph_count);
    try std.testing.expectEqual(@as(u32, 2), result.glyph_count);
    try std.testing.expectEqual(@as(usize, 2), frame.glyphs().len);
    try std.testing.expectEqual(@as(usize, 1), frame.textBatches().len);
    try std.testing.expectEqual(scene.layer_content, frame.textBatches()[0].layer);
    try std.testing.expectEqual(@as(usize, 2), out.glyphs.len);
    try std.testing.expectEqual(@as(usize, 1), out.text_batches.len);
    try std.testing.expectEqual(ui.layout.Rect.init(12.0, 18.0, 5.0, 7.0), out.glyphs[0].rect);
    try std.testing.expectEqual(ui.layout.Rect.init(18.0, 18.0, 5.0, 7.0), out.glyphs[1].rect);

    var invalid_clip_frame = Frame.begin(&storage, .{
        .frame_size_points = .{ 100.0, 100.0 },
        .font = &font,
    });
    try std.testing.expectError(scene.SceneBuildError.InvalidClipIndex, invalid_clip_frame.pushText(.{}, "z", .{}, 0));
}

test "frame direct API preserves order when text splits rect batches" {
    var font: text.Font = .{};
    font.glyphs['z'] = .{
        .codepoint = 'z',
        .atlas_width = 5,
        .atlas_height = 7,
        .advance = 6.0,
        .flags = text.glyph_present | text.glyph_visible,
    };

    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{
        .frame_size_points = .{ 100.0, 80.0 },
        .font = &font,
    });
    const clip = try frame.clip(frame.root());
    var draw = frame.draw(.{ .clip = clip, .layer = scene.layer_content });

    try draw.fill(ui.layout.Rect.init(0.0, 0.0, 20.0, 20.0), ui.style.Color.rgb(0.1, 0.1, 0.1));
    _ = try frame.pushTextLayer(ui.layout.Point.init(4.0, 4.0), "z", ui.style.Color.rgb(0.8, 0.8, 0.8), clip, scene.layer_content);
    try draw.fill(ui.layout.Rect.init(0.0, 24.0, 20.0, 20.0), ui.style.Color.rgb(0.2, 0.2, 0.2));
    const out = try frame.finish();

    try std.testing.expectEqual(@as(usize, 2), out.batches.len);
    try std.testing.expectEqual(@as(usize, 1), out.text_batches.len);
    try std.testing.expectEqual(@as(u32, 0), out.batches[0].order);
    try std.testing.expectEqual(@as(u32, 1), out.text_batches[0].order);
    try std.testing.expectEqual(@as(u32, 2), out.batches[1].order);
}

test "frame pushes prepared text lines without font lookup" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 100.0, 80.0 } });
    const clip = try frame.clip(frame.root());
    var line_storage: text.PreparedLineStorage = undefined;
    line_storage.glyphs[0] = .{
        .instance = .{
            .rect = ui.layout.Rect.init(1.0, 2.0, 5.0, 7.0),
            .atlas_rect = .{ .x = 0.1, .y = 0.1, .width = 0.1, .height = 0.1 },
            .color = ui.style.Color.rgb(0.8, 0.9, 1.0),
            .atlas_page = 2,
        },
        .byte_index = 0,
    };
    const line: text.PreparedLine = .{
        .advance = 6.0,
        .line_height = 12.0,
        .baseline_offset = 9.0,
        .bytes_len = 1,
        .glyphs = line_storage.glyphs[0..1],
    };

    try frame.pushPreparedTextLine(ui.layout.Point.init(10.0, 20.0), line, clip, scene.layer_content);
    const out = try frame.finish();

    try std.testing.expectEqual(@as(usize, 1), out.glyphs.len);
    try std.testing.expectEqual(ui.layout.Rect.init(11.0, 22.0, 5.0, 7.0), out.glyphs[0].rect);
    try std.testing.expectEqual(@as(u32, 2), out.glyphs[0].atlas_page);
    try std.testing.expectEqual(@as(usize, 1), out.text_batches.len);
}

test "draw textLine preserves prepared glyph colors" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 100.0, 80.0 } });
    const clip = try frame.clip(frame.root());
    var draw = frame.draw(.{ .clip = clip, .layer = scene.layer_content });

    var line_storage: text.PreparedLineStorage = undefined;
    line_storage.glyphs[0] = .{
        .instance = .{
            .rect = ui.layout.Rect.init(0.0, 0.0, 5.0, 7.0),
            .color = ui.style.Color.rgb(1.0, 0.0, 0.0),
        },
        .byte_index = 0,
    };
    line_storage.glyphs[1] = .{
        .instance = .{
            .rect = ui.layout.Rect.init(6.0, 0.0, 5.0, 7.0),
            .color = ui.style.Color.rgb(0.0, 1.0, 0.0),
        },
        .byte_index = 1,
    };
    const line: text.PreparedLine = .{
        .advance = 11.0,
        .line_height = 12.0,
        .bytes_len = 2,
        .glyphs = line_storage.glyphs[0..2],
    };

    try draw.textLine(.{}, line);
    const out = try frame.finish();

    try std.testing.expectEqual(@as(usize, 2), out.glyphs.len);
    try std.testing.expectEqual(ui.style.Color.rgb(1.0, 0.0, 0.0), out.glyphs[0].color);
    try std.testing.expectEqual(ui.style.Color.rgb(0.0, 1.0, 0.0), out.glyphs[1].color);
}

test "frame text runs emit one batch with per glyph colors" {
    var font: text.Font = .{};
    font.metrics = .{
        .atlas_width = text.atlas_width,
        .atlas_height = text.atlas_height,
    };
    font.glyphs['a'] = .{
        .codepoint = 'a',
        .atlas_width = 4,
        .atlas_height = 6,
        .advance = 5.0,
        .flags = text.glyph_present | text.glyph_visible,
    };
    font.glyphs['b'] = .{
        .codepoint = 'b',
        .atlas_x = 8,
        .atlas_width = 4,
        .atlas_height = 6,
        .advance = 5.0,
        .flags = text.glyph_present | text.glyph_visible,
    };

    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{
        .frame_size_points = .{ 100.0, 100.0 },
        .font = &font,
    });
    const clip = try frame.pushFrameClip();
    const runs = [_]text.AsciiRun{
        .{ .bytes = "a", .color = ui.style.Color.rgb(1.0, 0.0, 0.0) },
        .{ .bytes = "b", .color = ui.style.Color.rgb(0.0, 1.0, 0.0) },
    };

    const result = try frame.pushTextRuns(ui.layout.Point.init(10.0, 20.0), runs[0..], clip, scene.layer_content);
    const out = try frame.finish();

    try std.testing.expectEqual(@as(u32, 2), result.glyph_count);
    try std.testing.expectEqual(@as(usize, 1), out.text_batches.len);
    try std.testing.expectEqual(@as(u32, scene.vertices_per_glyph * 2), out.text_batches[0].vertex_count);
    try std.testing.expectEqual(ui.style.Color.rgb(1.0, 0.0, 0.0), out.glyphs[0].color);
    try std.testing.expectEqual(ui.style.Color.rgb(0.0, 1.0, 0.0), out.glyphs[1].color);
}

test "frame text runs can select fixed font slots" {
    var fonts = [_]text.Font{ .{}, .{} };
    fonts[0].metrics = .{ .line_height = 12.0, .atlas_width = text.atlas_width, .atlas_height = text.atlas_height };
    fonts[0].glyphs['a'] = .{
        .codepoint = 'a',
        .atlas_width = 4,
        .atlas_height = 6,
        .advance = 5.0,
        .flags = text.glyph_present | text.glyph_visible,
    };
    fonts[1].metrics = .{ .line_height = 18.0, .atlas_width = text.atlas_width, .atlas_height = text.atlas_height };
    fonts[1].glyphs['b'] = .{
        .codepoint = 'b',
        .atlas_width = 8,
        .atlas_height = 10,
        .advance = 9.0,
        .flags = text.glyph_present | text.glyph_visible,
    };

    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{
        .frame_size_points = .{ 100.0, 100.0 },
        .font = &fonts[0],
        .fonts = fonts[0..],
    });
    const clip = try frame.pushFrameClip();
    const runs = [_]text.AsciiRun{
        .{ .bytes = "a", .color = ui.style.Color.rgb(1.0, 1.0, 1.0), .font_slot = 0 },
        .{ .bytes = "b", .color = ui.style.Color.rgb(0.8, 0.8, 0.8), .font_slot = 1 },
    };

    const measured = try frame.measureTextRuns(runs[0..]);
    _ = try frame.pushTextRuns(.{}, runs[0..], clip, scene.layer_content);
    const out = try frame.finish();

    try std.testing.expectEqual(@as(f32, 14.0), measured.advance);
    try std.testing.expectEqual(@as(f32, 18.0), measured.height);
    try std.testing.expectEqual(@as(u32, 0), out.glyphs[0].atlas_page);
    try std.testing.expectEqual(@as(u32, 1), out.glyphs[1].atlas_page);
    try std.testing.expectEqual(ui.layout.Rect.init(5.0, 0.0, 8.0, 10.0), out.glyphs[1].rect);
}

test "frame exposes logical text placement and physical pixel snapping" {
    var font: text.Font = .{};
    font.metrics = .{
        .ascent = 11.0,
        .descent = 4.0,
        .leading = 1.0,
        .line_height = 16.0,
    };
    font.glyphs['M'] = .{
        .codepoint = 'M',
        .advance = 8.0,
        .flags = text.glyph_present | text.glyph_visible,
    };

    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{
        .frame_size_points = .{ 100.0, 100.0 },
        .scale = 2.0,
        .font = &font,
    });
    const placement = try frame.placeTextInRow(ui.layout.Rect.init(0.0, 10.0, 100.0, 28.0));
    const snapped = frame.snapRect(ui.layout.Rect.init(0.2, 0.3, 9.6, 10.4));

    try std.testing.expectEqual(@as(f32, 0.5), frame.physicalPixel());
    try std.testing.expectEqual(@as(f32, 0.5), frame.hairline());
    try std.testing.expectEqual(@as(f32, 16.0), placement.origin_y);
    try std.testing.expectEqual(@as(f32, 27.0), placement.baseline_y);
    try std.testing.expectEqual(ui.layout.Rect.init(0.0, 0.5, 10.0, 10.0), snapped);
}

test "draw writes layer selection into each stream" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{
        .frame_size_points = .{ 100.0, 100.0 },
    });
    const clip = try frame.pushFrameClip();
    var foreground = frame.draw(.{ .clip = clip, .layer = scene.layer_foreground });
    var overlay = frame.draw(.{ .clip = clip, .layer = scene.layer_overlay });
    var surface = frame.draw(.{ .clip = clip, .layer = scene.layer_surface });

    var line_storage: text.PreparedLineStorage = undefined;
    line_storage.glyphs[0] = .{
        .instance = .{
            .rect = ui.layout.Rect.init(0.0, 0.0, 7.0, 9.0),
            .atlas_rect = .{ .x = 0.1, .y = 0.1, .width = 0.1, .height = 0.1 },
            .color = .{},
        },
        .byte_index = 0,
    };
    const line: text.PreparedLine = .{
        .advance = 7.0,
        .line_height = 10.0,
        .glyphs = line_storage.glyphs[0..1],
        .bytes_len = 1,
    };
    try foreground.fill(ui.layout.Rect.init(0.0, 0.0, 10.0, 10.0), .{});
    try overlay.textLine(.{}, line);
    try surface.mask(ui.layout.Rect.init(16.0, 0.0, 16.0, 16.0), masking.rectFromPixels(1, 1, 16, 16), .{});
    const out = try frame.finish();

    try std.testing.expectEqual(scene.layer_foreground, out.batches[0].layer);
    try std.testing.expectEqual(scene.layer_overlay, out.text_batches[0].layer);
    try std.testing.expectEqual(scene.layer_surface, out.mask_batches[0].layer);
}

test "frame layered helpers flush open draw batches" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 100.0, 100.0 } });
    const clip = try frame.pushFrameClip();
    var draw = frame.draw(.{ .clip = clip, .layer = scene.layer_content });

    try draw.fill(ui.layout.Rect.init(0.0, 0.0, 10.0, 10.0), ui.style.Color.rgb(1.0, 1.0, 1.0));
    try frame.pushFillLayer(ui.layout.Rect.init(12.0, 0.0, 10.0, 10.0), .{}, clip, scene.layer_foreground);
    try frame.pushStyledRectLayer(ui.layout.Rect.init(24.0, 0.0, 10.0, 10.0), .{}, clip, scene.layer_overlay);
    const out = try frame.finish();

    try std.testing.expectEqual(@as(usize, 3), out.batches.len);
    try std.testing.expectEqual(scene.layer_content, out.batches[0].layer);
    try std.testing.expectEqual(scene.layer_foreground, out.batches[1].layer);
    try std.testing.expectEqual(scene.layer_overlay, out.batches[2].layer);
    try std.testing.expectEqual(@as(u32, 0), out.batches[0].order);
    try std.testing.expectEqual(@as(u32, 1), out.batches[1].order);
    try std.testing.expectEqual(@as(u32, 2), out.batches[2].order);
}

test "draw pushes masks into the frame mask stream" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 100.0, 100.0 } });
    const clip = try frame.pushFrameClip();
    var draw = frame.draw(.{ .clip = clip, .layer = scene.layer_overlay });

    const first_mask = masking.rectFromPixels(1, 1, 16, 16);
    const second_mask = masking.rectFromPixels(19, 1, 16, 16);
    try draw.mask(ui.layout.Rect.init(4.0, 5.0, 16.0, 16.0), first_mask, ui.style.Color.rgb(0.7, 0.8, 0.9));
    try draw.mask(ui.layout.Rect.init(22.0, 5.0, 16.0, 16.0), second_mask, ui.style.Color.rgb(0.9, 0.8, 0.7));
    const out = try frame.finish();

    try std.testing.expectEqual(@as(usize, 2), out.masks.len);
    try std.testing.expectEqual(@as(usize, 1), out.mask_batches.len);
    try std.testing.expectEqual(@as(u32, scene.vertices_per_mask * 2), out.mask_batches[0].vertex_count);
    try std.testing.expectEqual(first_mask, out.masks[0].atlas_rect);
    try std.testing.expectEqual(second_mask, out.masks[1].atlas_rect);
}

test "frame does not merge masks across intervening draw commands" {
    var font: text.Font = .{};
    font.glyphs['z'] = .{
        .codepoint = 'z',
        .atlas_width = 4,
        .atlas_height = 6,
        .advance = 5.0,
        .flags = text.glyph_present | text.glyph_visible,
    };

    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{
        .frame_size_points = .{ 100.0, 100.0 },
        .font = &font,
    });
    const clip = try frame.pushFrameClip();
    var draw = frame.draw(.{ .clip = clip, .layer = scene.layer_content });
    const atlas_rect = masking.rectFromPixels(1, 1, 16, 16);

    try draw.mask(ui.layout.Rect.init(0.0, 0.0, 16.0, 16.0), atlas_rect, .{});
    _ = try frame.pushTextLayer(ui.layout.Point.init(20.0, 0.0), "z", .{}, clip, scene.layer_content);
    try draw.mask(ui.layout.Rect.init(32.0, 0.0, 16.0, 16.0), atlas_rect, .{});
    const out = try frame.finish();

    try std.testing.expectEqual(@as(usize, 2), out.mask_batches.len);
    try std.testing.expectEqual(@as(u32, 0), out.mask_batches[0].order);
    try std.testing.expectEqual(@as(u32, 1), out.text_batches[0].order);
    try std.testing.expectEqual(@as(u32, 2), out.mask_batches[1].order);
}

test "frame rejects mask stream overflow explicitly" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 100.0, 100.0 } });
    const clip = try frame.pushFrameClip();
    var draw = frame.draw(.{ .clip = clip, .layer = scene.layer_overlay });
    const atlas_rect = masking.rectFromPixels(1, 1, 1, 1);

    for (0..scene.max_masks) |i| {
        try draw.mask(
            ui.layout.Rect.init(@floatFromInt(i), 0.0, 1.0, 1.0),
            atlas_rect,
            .{},
        );
    }
    try std.testing.expectError(Error.MaskCapacityExceeded, draw.mask(ui.layout.Rect.init(0.0, 0.0, 1.0, 1.0), atlas_rect, .{}));
}

test "frame push text requires an explicit font" {
    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{ .frame_size_points = .{ 100.0, 100.0 } });

    try std.testing.expectError(text.Error.NoFont, frame.measureText("z"));
    try std.testing.expectError(text.Error.NoFont, frame.pushText(.{}, "z", .{}, 0));
}

test "frame rejects text batch overflow" {
    var font: text.Font = .{};
    font.glyphs['z'] = .{
        .codepoint = 'z',
        .atlas_width = 1,
        .atlas_height = 1,
        .advance = 1.0,
        .flags = text.glyph_present | text.glyph_visible,
    };

    var storage: DefaultFrameStorage = .{};
    var frame = Frame.begin(&storage, .{
        .frame_size_points = .{ 100.0, 100.0 },
        .font = &font,
    });
    const clip = try frame.pushFrameClip();

    for (0..scene.max_text_batches) |_| {
        _ = try frame.pushText(.{}, "z", .{}, clip);
    }
    try std.testing.expectError(Error.TextBatchCapacityExceeded, frame.pushText(.{}, "z", .{}, clip));
}
