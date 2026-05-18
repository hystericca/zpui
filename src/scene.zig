const std = @import("std");
const mask = @import("mask.zig");
const text = @import("text.zig");

pub const max_quads = 2048;
pub const max_batches = 1024;
pub const max_text_batches = 1024;
pub const max_masks = 1024;
pub const max_mask_batches = 1024;
pub const max_draw_commands = max_batches + max_text_batches + max_mask_batches;
pub const max_clips = 256;
pub const vertices_per_quad = 6;
pub const vertices_per_glyph = 6;
pub const vertices_per_mask = 6;
pub const max_draw_vertices = max_quads * vertices_per_quad;
pub const max_text_vertices = text.max_frame_glyphs * vertices_per_glyph;
pub const max_mask_vertices = max_masks * vertices_per_mask;

pub const layer_background: u32 = 0;
pub const layer_surface: u32 = 100;
pub const layer_content: u32 = 200;
pub const layer_foreground: u32 = 300;
pub const layer_overlay: u32 = 400;

pub const Color = [4]f32;
pub const ClearColor = [4]f64;

pub const Rect = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const ClipRect = extern struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
};

pub const Radius = extern struct {
    top_left: f32 = 0.0,
    top_right: f32 = 0.0,
    bottom_right: f32 = 0.0,
    bottom_left: f32 = 0.0,
};

pub const QuadStyle = struct {
    fill_color: Color = transparent,
    border_color: Color = transparent,
    radius: Radius = .{},
    border_width: f32 = 0.0,
};

pub const Quad = struct {
    rect: Rect,
    fill_color: Color,
    border_color: Color,
    radius: Radius,
    border_width: f32,
    clip_index: u32,
};

pub const GpuQuad = extern struct {
    rect: Rect,
    fill_color: Color,
    border_color: Color,
    radius: Radius,
    border_width: f32,
    // Keep GPU-shared padding as scalars. Metal vector3 types have 16-byte
    // alignment, which does not match a packed host [3]f32 tail.
    reserved: [3]f32 = .{ 0.0, 0.0, 0.0 },
};

pub const Batch = extern struct {
    vertex_start: u32,
    vertex_count: u32,
    clip_index: u32,
    layer: u32 = layer_background,
    order: u32 = 0,
};

pub const TextBatch = extern struct {
    vertex_start: u32,
    vertex_count: u32,
    clip_index: u32,
    layer: u32 = layer_content,
    order: u32 = 0,
};

pub const MaskBatch = extern struct {
    vertex_start: u32,
    vertex_count: u32,
    clip_index: u32,
    layer: u32 = layer_content,
    order: u32 = 0,
};

pub const DrawKind = enum(u8) {
    quad,
    mask,
    text,
};

pub const DrawCommand = extern struct {
    vertex_start: u32,
    vertex_count: u32,
    clip_index: u32,
    layer: u32,
    order: u32,
    kind: DrawKind,
    reserved: [3]u8 = .{ 0, 0, 0 },
};

pub const Scene = struct {
    clear_color: ClearColor,
    drawable_size: [2]f32,
    quads: []const Quad,
    batches: []const Batch,
    clips: []const ClipRect,
    glyphs: []const text.GlyphInstance,
    text_batches: []const TextBatch,
    masks: []const mask.Instance,
    mask_batches: []const MaskBatch,
    font: ?*const text.Font,
};

pub const SceneStorage = struct {
    quads: [max_quads]Quad = undefined,
    batches: [max_batches]Batch = undefined,
    clips: [max_clips]ClipRect = undefined,
};

pub const FrameData = extern struct {
    drawable_size: [2]f32,
    quad_count: u32,
    reserved: u32 = 0,
    quads: [max_quads]GpuQuad,
};

pub const TextFrameData = extern struct {
    drawable_size: [2]f32,
    glyph_count: u32,
    reserved: u32 = 0,
    glyphs: [text.max_frame_glyphs]text.GlyphInstance,
};

pub const MaskFrameData = extern struct {
    drawable_size: [2]f32,
    mask_count: u32,
    reserved: u32 = 0,
    masks: [max_masks]mask.Instance,
};

pub const transparent: Color = .{ 0.0, 0.0, 0.0, 0.0 };

comptime {
    std.debug.assert(@sizeOf(Rect) == 16);
    std.debug.assert(@sizeOf(ClipRect) == 16);
    std.debug.assert(@sizeOf(Radius) == 16);
    std.debug.assert(@sizeOf(GpuQuad) == 80);
    std.debug.assert(@sizeOf(Batch) == 20);
    std.debug.assert(@sizeOf(TextBatch) == 20);
    std.debug.assert(@sizeOf(MaskBatch) == 20);
    std.debug.assert(@sizeOf(DrawCommand) == 24);
    std.debug.assert(@sizeOf(FrameData) == frameDataByteLen(max_quads));
    std.debug.assert(@sizeOf(TextFrameData) == textFrameDataByteLen(text.max_frame_glyphs));
    std.debug.assert(@sizeOf(MaskFrameData) == maskFrameDataByteLen(max_masks));
    std.debug.assert(text.max_font_slots == 4);
    std.debug.assert(@offsetOf(FrameData, "drawable_size") == 0);
    std.debug.assert(@offsetOf(FrameData, "quad_count") == 8);
    std.debug.assert(@offsetOf(FrameData, "quads") == 16);
    std.debug.assert(@offsetOf(TextFrameData, "drawable_size") == 0);
    std.debug.assert(@offsetOf(TextFrameData, "glyph_count") == 8);
    std.debug.assert(@offsetOf(TextFrameData, "glyphs") == 16);
    std.debug.assert(@offsetOf(MaskFrameData, "drawable_size") == 0);
    std.debug.assert(@offsetOf(MaskFrameData, "mask_count") == 8);
    std.debug.assert(@offsetOf(MaskFrameData, "masks") == 16);
}

pub const SceneBuildError = error{
    InvalidGeometry,
    InvalidClip,
    InvalidClipIndex,
    QuadCapacityExceeded,
    EmptyBatch,
    BatchCapacityExceeded,
    ClipCapacityExceeded,
    BatchAlreadyOpen,
    NoOpenBatch,
    BatchClipMismatch,
};

pub const CompileError = error{
    InvalidClipIndex,
    InvalidBatch,
    QuadCapacityExceeded,
    BatchCapacityExceeded,
    ClipCapacityExceeded,
    GlyphCapacityExceeded,
    InvalidGlyph,
    TextBatchCapacityExceeded,
    InvalidTextBatch,
    MaskCapacityExceeded,
    MaskBatchCapacityExceeded,
    InvalidMaskBatch,
    InvalidMask,
    BatchClipMismatch,
};

pub const CompileResult = struct {
    draw_vertex_count: u32,
    quad_count: u32,
    batch_count: u32,
};

pub const TextCompileResult = struct {
    draw_vertex_count: u32,
    glyph_count: u32,
    batch_count: u32,
};

pub const MaskCompileResult = struct {
    draw_vertex_count: u32,
    mask_count: u32,
    batch_count: u32,
};

pub const SceneBuilder = struct {
    storage: *SceneStorage,
    drawable_size: [2]f32,
    clear_color: ClearColor,
    quad_count: u32 = 0,
    batch_count: u32 = 0,
    clip_count: u32 = 0,
    open_batch_start: u32 = 0,
    open_batch_clip: u32 = 0,
    open_batch_layer: u32 = layer_background,
    batch_open: bool = false,

    pub fn begin(storage: *SceneStorage, drawable_size: [2]f32, clear_color: ClearColor) SceneBuilder {
        return .{
            .storage = storage,
            .drawable_size = drawable_size,
            .clear_color = clear_color,
        };
    }

    pub fn pushDrawableClip(builder: *SceneBuilder) SceneBuildError!u32 {
        return builder.pushClip(drawableClip(builder.drawable_size));
    }

    pub fn pushClip(builder: *SceneBuilder, clip: ClipRect) SceneBuildError!u32 {
        if (clip.width == 0 or clip.height == 0) return SceneBuildError.InvalidClip;
        if (builder.clip_count >= max_clips) return SceneBuildError.ClipCapacityExceeded;

        const index = builder.clip_count;
        builder.storage.clips[@intCast(index)] = clip;
        builder.clip_count += 1;
        return index;
    }

    pub fn beginBatch(builder: *SceneBuilder, clip_index: u32) SceneBuildError!void {
        try builder.beginLayerBatch(clip_index, layer_background);
    }

    pub fn beginLayerBatch(builder: *SceneBuilder, clip_index: u32, layer: u32) SceneBuildError!void {
        if (builder.batch_open) return SceneBuildError.BatchAlreadyOpen;
        if (clip_index >= builder.clip_count) return SceneBuildError.InvalidClipIndex;
        if (builder.batch_count >= max_batches) return SceneBuildError.BatchCapacityExceeded;

        builder.open_batch_start = builder.quad_count;
        builder.open_batch_clip = clip_index;
        builder.open_batch_layer = layer;
        builder.batch_open = true;
    }

    pub fn pushQuad(builder: *SceneBuilder, rect: Rect, color: Color, clip_index: u32) SceneBuildError!void {
        try builder.pushStyledQuad(rect, .{ .fill_color = color }, clip_index);
    }

    pub fn pushStyledQuad(builder: *SceneBuilder, rect: Rect, style: QuadStyle, clip_index: u32) SceneBuildError!void {
        if (!builder.batch_open) return SceneBuildError.NoOpenBatch;
        if (!validRect(rect) or !validQuadStyle(style)) return SceneBuildError.InvalidGeometry;
        if (clip_index >= builder.clip_count) return SceneBuildError.InvalidClipIndex;
        if (clip_index != builder.open_batch_clip) return SceneBuildError.BatchClipMismatch;
        if (builder.quad_count >= max_quads) return SceneBuildError.QuadCapacityExceeded;

        builder.storage.quads[@intCast(builder.quad_count)] = .{
            .rect = rect,
            .fill_color = style.fill_color,
            .border_color = style.border_color,
            .radius = style.radius,
            .border_width = style.border_width,
            .clip_index = clip_index,
        };
        builder.quad_count += 1;
    }

    pub fn endBatch(builder: *SceneBuilder) SceneBuildError!void {
        if (!builder.batch_open) return SceneBuildError.NoOpenBatch;

        const quad_count = builder.quad_count - builder.open_batch_start;
        if (quad_count == 0) return SceneBuildError.EmptyBatch;

        builder.storage.batches[@intCast(builder.batch_count)] = .{
            .vertex_start = builder.open_batch_start * vertices_per_quad,
            .vertex_count = quad_count * vertices_per_quad,
            .clip_index = builder.open_batch_clip,
            .layer = builder.open_batch_layer,
            .order = builder.batch_count,
        };
        builder.batch_count += 1;
        builder.batch_open = false;
    }

    pub fn finish(builder: *SceneBuilder) SceneBuildError!Scene {
        if (builder.batch_open) try builder.endBatch();
        const quad_count: usize = @intCast(builder.quad_count);
        const batch_count: usize = @intCast(builder.batch_count);
        const clip_count: usize = @intCast(builder.clip_count);
        return .{
            .clear_color = builder.clear_color,
            .drawable_size = builder.drawable_size,
            .quads = builder.storage.quads[0..quad_count],
            .batches = builder.storage.batches[0..batch_count],
            .clips = builder.storage.clips[0..clip_count],
            .glyphs = &.{},
            .text_batches = &.{},
            .masks = &.{},
            .mask_batches = &.{},
            .font = null,
        };
    }
};

pub fn compileScene(scene: *const Scene, frame_data: *FrameData) CompileError!CompileResult {
    if (scene.quads.len > max_quads) return CompileError.QuadCapacityExceeded;
    if (scene.batches.len > max_batches) return CompileError.BatchCapacityExceeded;
    if (scene.clips.len > max_clips) return CompileError.ClipCapacityExceeded;

    for (scene.quads) |quad| {
        const clip_index: usize = @intCast(quad.clip_index);
        if (clip_index >= scene.clips.len) return CompileError.InvalidClipIndex;
    }

    const max_vertex_count: u32 = @intCast(scene.quads.len * vertices_per_quad);
    var draw_vertex_count: u32 = 0;
    var next_vertex_start: u32 = 0;
    for (scene.batches) |batch| {
        const clip_index: usize = @intCast(batch.clip_index);
        if (clip_index >= scene.clips.len) return CompileError.InvalidClipIndex;
        if (batch.vertex_count == 0 or batch.vertex_count % vertices_per_quad != 0) return CompileError.InvalidBatch;
        if (batch.vertex_start % vertices_per_quad != 0) return CompileError.InvalidBatch;
        if (batch.vertex_start != next_vertex_start) return CompileError.InvalidBatch;
        if (batch.vertex_start > max_vertex_count or batch.vertex_count > max_vertex_count - batch.vertex_start) return CompileError.InvalidBatch;
        const first_quad: usize = @intCast(batch.vertex_start / vertices_per_quad);
        const batch_quad_count: usize = @intCast(batch.vertex_count / vertices_per_quad);
        for (scene.quads[first_quad .. first_quad + batch_quad_count]) |quad| {
            if (quad.clip_index != batch.clip_index) return CompileError.BatchClipMismatch;
        }
        draw_vertex_count += batch.vertex_count;
        next_vertex_start += batch.vertex_count;
    }
    if (next_vertex_start != max_vertex_count) return CompileError.InvalidBatch;

    frame_data.drawable_size = scene.drawable_size;
    frame_data.quad_count = @intCast(scene.quads.len);
    frame_data.reserved = 0;
    for (scene.quads, 0..) |quad, i| {
        frame_data.quads[i] = .{
            .rect = quad.rect,
            .fill_color = quad.fill_color,
            .border_color = quad.border_color,
            .radius = quad.radius,
            .border_width = quad.border_width,
        };
    }

    return .{
        .draw_vertex_count = draw_vertex_count,
        .quad_count = @intCast(scene.quads.len),
        .batch_count = @intCast(scene.batches.len),
    };
}

pub fn compileText(scene: *const Scene, frame_data: *TextFrameData) CompileError!TextCompileResult {
    if (scene.glyphs.len > text.max_frame_glyphs) return CompileError.GlyphCapacityExceeded;
    if (scene.text_batches.len > max_text_batches) return CompileError.TextBatchCapacityExceeded;

    frame_data.drawable_size = scene.drawable_size;
    frame_data.glyph_count = @intCast(scene.glyphs.len);
    frame_data.reserved = 0;
    for (scene.glyphs, 0..) |glyph, i| {
        if (!validGlyph(glyph)) return CompileError.InvalidGlyph;
        frame_data.glyphs[i] = glyph;
    }

    const max_vertex_count: u32 = @intCast(scene.glyphs.len * vertices_per_glyph);
    var draw_vertex_count: u32 = 0;
    var next_vertex_start: u32 = 0;
    for (scene.text_batches) |batch| {
        const clip_index: usize = @intCast(batch.clip_index);
        if (clip_index >= scene.clips.len) return CompileError.InvalidClipIndex;
        if (batch.vertex_count == 0 or batch.vertex_count % vertices_per_glyph != 0) return CompileError.InvalidTextBatch;
        if (batch.vertex_start % vertices_per_glyph != 0) return CompileError.InvalidTextBatch;
        if (batch.vertex_start != next_vertex_start) return CompileError.InvalidTextBatch;
        if (batch.vertex_start > max_vertex_count or batch.vertex_count > max_vertex_count - batch.vertex_start) return CompileError.InvalidTextBatch;
        draw_vertex_count += batch.vertex_count;
        next_vertex_start += batch.vertex_count;
    }
    if (next_vertex_start != max_vertex_count) return CompileError.InvalidTextBatch;

    return .{
        .draw_vertex_count = draw_vertex_count,
        .glyph_count = @intCast(scene.glyphs.len),
        .batch_count = @intCast(scene.text_batches.len),
    };
}

pub fn compileMasks(scene: *const Scene, frame_data: *MaskFrameData) CompileError!MaskCompileResult {
    if (scene.masks.len > max_masks) return CompileError.MaskCapacityExceeded;
    if (scene.mask_batches.len > max_mask_batches) return CompileError.MaskBatchCapacityExceeded;

    frame_data.drawable_size = scene.drawable_size;
    frame_data.mask_count = @intCast(scene.masks.len);
    frame_data.reserved = 0;
    for (scene.masks, 0..) |instance, i| {
        if (!validMask(instance)) return CompileError.InvalidMask;
        frame_data.masks[i] = instance;
    }

    const max_vertex_count: u32 = @intCast(scene.masks.len * vertices_per_mask);
    var draw_vertex_count: u32 = 0;
    var next_vertex_start: u32 = 0;
    for (scene.mask_batches) |batch| {
        const clip_index: usize = @intCast(batch.clip_index);
        if (clip_index >= scene.clips.len) return CompileError.InvalidClipIndex;
        if (batch.vertex_count == 0 or batch.vertex_count % vertices_per_mask != 0) return CompileError.InvalidMaskBatch;
        if (batch.vertex_start % vertices_per_mask != 0) return CompileError.InvalidMaskBatch;
        if (batch.vertex_start != next_vertex_start) return CompileError.InvalidMaskBatch;
        if (batch.vertex_start > max_vertex_count or batch.vertex_count > max_vertex_count - batch.vertex_start) return CompileError.InvalidMaskBatch;
        draw_vertex_count += batch.vertex_count;
        next_vertex_start += batch.vertex_count;
    }
    if (next_vertex_start != max_vertex_count) return CompileError.InvalidMaskBatch;

    return .{
        .draw_vertex_count = draw_vertex_count,
        .mask_count = @intCast(scene.masks.len),
        .batch_count = @intCast(scene.mask_batches.len),
    };
}

pub fn frameDataByteLen(quad_count: u32) usize {
    return @offsetOf(FrameData, "quads") + @as(usize, @intCast(quad_count)) * @sizeOf(GpuQuad);
}

pub fn textFrameDataByteLen(glyph_count: u32) usize {
    return @offsetOf(TextFrameData, "glyphs") + @as(usize, @intCast(glyph_count)) * @sizeOf(text.GlyphInstance);
}

pub fn maskFrameDataByteLen(mask_count: u32) usize {
    return @offsetOf(MaskFrameData, "masks") + @as(usize, @intCast(mask_count)) * @sizeOf(mask.Instance);
}

fn drawableClip(drawable_size: [2]f32) ClipRect {
    return .{
        .x = 0,
        .y = 0,
        .width = positiveU32(drawable_size[0]),
        .height = positiveU32(drawable_size[1]),
    };
}

fn positiveU32(value: f32) u32 {
    if (value <= 0.0 or !std.math.isFinite(value)) return 0;
    return floorU32(value);
}

fn floorU32(value: f32) u32 {
    const max_exact_u32_f32: f32 = 4_294_967_040.0;
    if (value >= max_exact_u32_f32) return std.math.maxInt(u32);
    return @intFromFloat(@floor(value));
}

fn validRect(rect: Rect) bool {
    return rect.width > 0.0 and rect.height > 0.0 and
        std.math.isFinite(rect.x) and
        std.math.isFinite(rect.y) and
        std.math.isFinite(rect.width) and
        std.math.isFinite(rect.height);
}

fn validQuadStyle(style: QuadStyle) bool {
    return style.border_width >= 0.0 and
        std.math.isFinite(style.border_width) and
        validRadius(style.radius) and
        validColor(style.fill_color) and
        validColor(style.border_color);
}

fn validRadius(radius: Radius) bool {
    return radius.top_left >= 0.0 and
        radius.top_right >= 0.0 and
        radius.bottom_right >= 0.0 and
        radius.bottom_left >= 0.0 and
        std.math.isFinite(radius.top_left) and
        std.math.isFinite(radius.top_right) and
        std.math.isFinite(radius.bottom_right) and
        std.math.isFinite(radius.bottom_left);
}

fn validColor(color: Color) bool {
    for (color) |component| {
        if (!std.math.isFinite(component)) return false;
    }
    return true;
}

fn validGlyph(glyph: text.GlyphInstance) bool {
    return glyph.font_slot < text.max_font_slots and
        validLayoutRect(glyph.rect) and
        validAtlasRect(glyph.atlas_rect) and
        validStyleColor(glyph.color);
}

fn validLayoutRect(rect: anytype) bool {
    return rect.width > 0.0 and
        rect.height > 0.0 and
        std.math.isFinite(rect.x) and
        std.math.isFinite(rect.y) and
        std.math.isFinite(rect.width) and
        std.math.isFinite(rect.height);
}

fn validAtlasRect(rect: anytype) bool {
    const epsilon = 0.0001;
    return rect.x >= 0.0 and
        rect.y >= 0.0 and
        rect.width > 0.0 and
        rect.height > 0.0 and
        rect.x + rect.width <= 1.0 + epsilon and
        rect.y + rect.height <= 1.0 + epsilon and
        std.math.isFinite(rect.x) and
        std.math.isFinite(rect.y) and
        std.math.isFinite(rect.width) and
        std.math.isFinite(rect.height);
}

fn validStyleColor(color: anytype) bool {
    return std.math.isFinite(color.r) and
        std.math.isFinite(color.g) and
        std.math.isFinite(color.b) and
        std.math.isFinite(color.a);
}

fn validMask(instance: mask.Instance) bool {
    return validLayoutRect(instance.rect) and
        validAtlasRect(instance.atlas_rect) and
        validStyleColor(instance.color);
}

test "scene and GPU frame layouts stay stable" {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Rect));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(ClipRect));
    try std.testing.expectEqual(@as(usize, 72), @sizeOf(Quad));
    try std.testing.expectEqual(@as(usize, 80), @sizeOf(GpuQuad));
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(Batch));
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(TextBatch));
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(MaskBatch));
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(DrawCommand));
    try std.testing.expectEqual(frameDataByteLen(max_quads), @sizeOf(FrameData));
    try std.testing.expectEqual(textFrameDataByteLen(text.max_frame_glyphs), @sizeOf(TextFrameData));
    try std.testing.expectEqual(maskFrameDataByteLen(max_masks), @sizeOf(MaskFrameData));

    try std.testing.expectEqual(@as(usize, 0), @offsetOf(FrameData, "drawable_size"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(FrameData, "quad_count"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(FrameData, "quads"));
    try std.testing.expectEqual(@as(usize, 16), frameDataByteLen(0));
    try std.testing.expectEqual(@as(usize, 96), frameDataByteLen(1));
    try std.testing.expectEqual(@sizeOf(FrameData), frameDataByteLen(max_quads));

    try std.testing.expectEqual(@as(usize, 0), @offsetOf(TextFrameData, "drawable_size"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(TextFrameData, "glyph_count"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(TextFrameData, "glyphs"));
    try std.testing.expectEqual(@as(usize, 16), textFrameDataByteLen(0));
    try std.testing.expectEqual(@as(usize, 80), textFrameDataByteLen(1));
    try std.testing.expectEqual(@sizeOf(TextFrameData), textFrameDataByteLen(text.max_frame_glyphs));

    try std.testing.expectEqual(@as(usize, 0), @offsetOf(MaskFrameData, "drawable_size"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(MaskFrameData, "mask_count"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(MaskFrameData, "masks"));
    try std.testing.expectEqual(@as(usize, 16), maskFrameDataByteLen(0));
    try std.testing.expectEqual(@as(usize, 64), maskFrameDataByteLen(1));
    try std.testing.expectEqual(@sizeOf(MaskFrameData), maskFrameDataByteLen(max_masks));
}

test "scene builder records multiple batches and clips" {
    var storage: SceneStorage = undefined;
    var builder = SceneBuilder.begin(&storage, .{ 100.0, 50.0 }, .{ 0, 0, 0, 1 });
    const full_clip = try builder.pushDrawableClip();
    const small_clip = try builder.pushClip(.{ .x = 10, .y = 10, .width = 20, .height = 20 });

    try builder.beginBatch(full_clip);
    try builder.pushQuad(.{ .x = 0, .y = 0, .width = 10, .height = 10 }, .{ 1, 1, 1, 1 }, full_clip);
    try builder.endBatch();

    try builder.beginBatch(small_clip);
    try builder.pushQuad(.{ .x = 10, .y = 10, .width = 5, .height = 5 }, .{ 0, 1, 0, 1 }, small_clip);
    const scene = try builder.finish();

    try std.testing.expectEqual(@as(usize, 2), scene.clips.len);
    try std.testing.expectEqual(@as(usize, 2), scene.quads.len);
    try std.testing.expectEqual(@as(usize, 2), scene.batches.len);
    try std.testing.expectEqual(@as(u32, 0), scene.batches[0].vertex_start);
    try std.testing.expectEqual(@as(u32, 6), scene.batches[1].vertex_start);
}

test "scene batches carry explicit layers and stream order" {
    var storage: SceneStorage = undefined;
    var builder = SceneBuilder.begin(&storage, .{ 100.0, 50.0 }, .{ 0, 0, 0, 1 });
    const clip = try builder.pushDrawableClip();

    try builder.beginLayerBatch(clip, layer_foreground);
    try builder.pushQuad(.{ .x = 0, .y = 0, .width = 10, .height = 10 }, .{ 1, 1, 1, 1 }, clip);
    const scene = try builder.finish();

    try std.testing.expectEqual(@as(usize, 1), scene.batches.len);
    try std.testing.expectEqual(layer_foreground, scene.batches[0].layer);
    try std.testing.expectEqual(@as(u32, 0), scene.batches[0].order);
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(Batch));
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(TextBatch));
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(MaskBatch));
}

test "scene compiler emits compact GPU frame data" {
    var storage: SceneStorage = undefined;
    var builder = SceneBuilder.begin(&storage, .{ 100.0, 50.0 }, .{ 0.035, 0.045, 0.06, 1.0 });
    const clip = try builder.pushDrawableClip();
    try builder.beginBatch(clip);
    try builder.pushQuad(.{
        .x = 10.0,
        .y = 5.0,
        .width = 20.0,
        .height = 10.0,
    }, .{ 0.25, 0.72, 1.0, 1.0 }, clip);
    const scene = try builder.finish();

    var frame_data: FrameData = undefined;
    const result = try compileScene(&scene, &frame_data);

    try std.testing.expectEqual(@as(u32, 6), result.draw_vertex_count);
    try std.testing.expectEqual(@as(u32, 1), result.quad_count);
    try std.testing.expectEqual(@as(u32, 1), result.batch_count);
    try std.testing.expectEqual([2]f32{ 100.0, 50.0 }, frame_data.drawable_size);
    try std.testing.expectEqual(@as(u32, 1), frame_data.quad_count);
    try std.testing.expectEqual(scene.quads[0].rect, frame_data.quads[0].rect);
    try std.testing.expectEqual(scene.quads[0].fill_color, frame_data.quads[0].fill_color);
    try std.testing.expectEqual(scene.quads[0].border_color, frame_data.quads[0].border_color);
    try std.testing.expectEqual(scene.quads[0].radius, frame_data.quads[0].radius);
    try std.testing.expectEqual(scene.quads[0].border_width, frame_data.quads[0].border_width);
}

test "styled quads carry fill border and radius into GPU data" {
    var storage: SceneStorage = undefined;
    var builder = SceneBuilder.begin(&storage, .{ 200.0, 100.0 }, .{ 0, 0, 0, 1 });
    const clip = try builder.pushDrawableClip();

    try builder.beginLayerBatch(clip, layer_surface);
    try builder.pushStyledQuad(.{
        .x = 8.0,
        .y = 9.0,
        .width = 64.0,
        .height = 32.0,
    }, .{
        .fill_color = .{ 0.1, 0.2, 0.3, 0.75 },
        .border_color = .{ 0.8, 0.9, 1.0, 0.5 },
        .radius = .{ .top_left = 4.0, .top_right = 5.0, .bottom_right = 6.0, .bottom_left = 7.0 },
        .border_width = 1.0,
    }, clip);
    const scene = try builder.finish();

    var frame_data: FrameData = undefined;
    _ = try compileScene(&scene, &frame_data);

    try std.testing.expectEqual(layer_surface, scene.batches[0].layer);
    try std.testing.expectEqual(Radius{ .top_left = 4.0, .top_right = 5.0, .bottom_right = 6.0, .bottom_left = 7.0 }, frame_data.quads[0].radius);
    try std.testing.expectEqual(@as(f32, 1.0), frame_data.quads[0].border_width);
    try std.testing.expectEqual(Color{ 0.1, 0.2, 0.3, 0.75 }, frame_data.quads[0].fill_color);
    try std.testing.expectEqual(Color{ 0.8, 0.9, 1.0, 0.5 }, frame_data.quads[0].border_color);
}

test "text compiler emits compact glyph frame data" {
    var glyphs = [_]text.GlyphInstance{.{
        .rect = .{ .x = 10.0, .y = 12.0, .width = 7.0, .height = 9.0 },
        .atlas_rect = .{ .x = 0.125, .y = 0.25, .width = 0.03125, .height = 0.0625 },
        .color = .{ .r = 0.7, .g = 0.8, .b = 0.9, .a = 1.0 },
    }};
    var scene: Scene = .{
        .clear_color = .{ 0, 0, 0, 1 },
        .drawable_size = .{ 640.0, 480.0 },
        .quads = &.{},
        .batches = &.{},
        .clips = &.{.{ .x = 0, .y = 0, .width = 640, .height = 480 }},
        .glyphs = glyphs[0..],
        .text_batches = &.{.{
            .vertex_start = 0,
            .vertex_count = vertices_per_glyph,
            .clip_index = 0,
        }},
        .masks = &.{},
        .mask_batches = &.{},
        .font = null,
    };

    var frame_data: TextFrameData = undefined;
    const result = try compileText(&scene, &frame_data);

    try std.testing.expectEqual(@as(u32, vertices_per_glyph), result.draw_vertex_count);
    try std.testing.expectEqual(@as(u32, 1), result.glyph_count);
    try std.testing.expectEqual(@as(u32, 1), result.batch_count);
    try std.testing.expectEqual([2]f32{ 640.0, 480.0 }, frame_data.drawable_size);
    try std.testing.expectEqual(@as(u32, 1), frame_data.glyph_count);
    try std.testing.expectEqual(glyphs[0], frame_data.glyphs[0]);
    try std.testing.expectEqual(@as(usize, 80), textFrameDataByteLen(result.glyph_count));

    scene.glyphs = &.{};
    scene.text_batches = &.{};
    const empty = try compileText(&scene, &frame_data);
    try std.testing.expectEqual(@as(u32, 0), empty.draw_vertex_count);
    try std.testing.expectEqual(@as(u32, 0), empty.glyph_count);
    try std.testing.expectEqual(@as(u32, 0), empty.batch_count);
}

test "text compiler rejects malformed text batches" {
    var glyphs = [_]text.GlyphInstance{.{
        .rect = .{ .x = 0.0, .y = 0.0, .width = 1.0, .height = 1.0 },
        .atlas_rect = .{ .x = 0.0, .y = 0.0, .width = 1.0, .height = 1.0 },
        .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
    }};
    var clips = [_]ClipRect{.{ .x = 0, .y = 0, .width = 640, .height = 480 }};
    var batches = [_]TextBatch{.{ .vertex_start = 0, .vertex_count = 0, .clip_index = 0 }};
    var scene: Scene = .{
        .clear_color = .{ 0, 0, 0, 1 },
        .drawable_size = .{ 640.0, 480.0 },
        .quads = &.{},
        .batches = &.{},
        .clips = clips[0..],
        .glyphs = glyphs[0..],
        .text_batches = batches[0..],
        .masks = &.{},
        .mask_batches = &.{},
        .font = null,
    };

    var frame_data: TextFrameData = undefined;
    try std.testing.expectError(CompileError.InvalidTextBatch, compileText(&scene, &frame_data));

    batches[0].vertex_count = vertices_per_glyph;
    batches[0].clip_index = 1;
    try std.testing.expectError(CompileError.InvalidClipIndex, compileText(&scene, &frame_data));
}

test "text compiler rejects malformed glyph payloads" {
    var glyphs = [_]text.GlyphInstance{.{
        .rect = .{ .x = 0.0, .y = 0.0, .width = 1.0, .height = 1.0 },
        .atlas_rect = .{ .x = 0.0, .y = 0.0, .width = 0.25, .height = 0.25 },
        .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
    }};
    var batches = [_]TextBatch{.{ .vertex_start = 0, .vertex_count = vertices_per_glyph, .clip_index = 0 }};
    var scene: Scene = .{
        .clear_color = .{ 0, 0, 0, 1 },
        .drawable_size = .{ 640.0, 480.0 },
        .quads = &.{},
        .batches = &.{},
        .clips = &.{.{ .x = 0, .y = 0, .width = 640, .height = 480 }},
        .glyphs = glyphs[0..],
        .text_batches = batches[0..],
        .masks = &.{},
        .mask_batches = &.{},
        .font = null,
    };
    var frame_data: TextFrameData = undefined;

    glyphs[0].rect.width = -1.0;
    try std.testing.expectError(CompileError.InvalidGlyph, compileText(&scene, &frame_data));

    glyphs[0].rect.width = 1.0;
    glyphs[0].rect.height = 0.0;
    try std.testing.expectError(CompileError.InvalidGlyph, compileText(&scene, &frame_data));

    glyphs[0].rect.height = 1.0;
    glyphs[0].rect.x = std.math.nan(f32);
    try std.testing.expectError(CompileError.InvalidGlyph, compileText(&scene, &frame_data));

    glyphs[0].rect.x = 0.0;
    glyphs[0].atlas_rect.x = 0.9;
    glyphs[0].atlas_rect.width = 0.2;
    try std.testing.expectError(CompileError.InvalidGlyph, compileText(&scene, &frame_data));

    glyphs[0].atlas_rect.x = 0.0;
    glyphs[0].atlas_rect.width = 0.25;
    glyphs[0].color.r = std.math.nan(f32);
    try std.testing.expectError(CompileError.InvalidGlyph, compileText(&scene, &frame_data));

    glyphs[0].color.r = 1.0;
    glyphs[0].font_slot = text.max_font_slots;
    try std.testing.expectError(CompileError.InvalidGlyph, compileText(&scene, &frame_data));
}

test "mask compiler emits compact mask frame data" {
    var masks = [_]mask.Instance{.{
        .rect = .{ .x = 4.0, .y = 5.0, .width = 16.0, .height = 16.0 },
        .atlas_rect = mask.rectFromPixels(1, 1, 16, 16),
        .color = .{ .r = 0.8, .g = 0.84, .b = 0.9, .a = 1.0 },
    }};
    var scene: Scene = .{
        .clear_color = .{ 0, 0, 0, 1 },
        .drawable_size = .{ 640.0, 480.0 },
        .quads = &.{},
        .batches = &.{},
        .clips = &.{.{ .x = 0, .y = 0, .width = 640, .height = 480 }},
        .glyphs = &.{},
        .text_batches = &.{},
        .masks = masks[0..],
        .mask_batches = &.{.{
            .vertex_start = 0,
            .vertex_count = vertices_per_mask,
            .clip_index = 0,
            .layer = layer_overlay,
        }},
        .font = null,
    };

    var frame_data: MaskFrameData = undefined;
    const result = try compileMasks(&scene, &frame_data);

    try std.testing.expectEqual(@as(u32, vertices_per_mask), result.draw_vertex_count);
    try std.testing.expectEqual(@as(u32, 1), result.mask_count);
    try std.testing.expectEqual(@as(u32, 1), result.batch_count);
    try std.testing.expectEqual([2]f32{ 640.0, 480.0 }, frame_data.drawable_size);
    try std.testing.expectEqual(@as(u32, 1), frame_data.mask_count);
    try std.testing.expectEqual(masks[0], frame_data.masks[0]);
    try std.testing.expectEqual(@as(usize, 64), maskFrameDataByteLen(result.mask_count));

    scene.masks = &.{};
    scene.mask_batches = &.{};
    const empty = try compileMasks(&scene, &frame_data);
    try std.testing.expectEqual(@as(u32, 0), empty.draw_vertex_count);
    try std.testing.expectEqual(@as(u32, 0), empty.mask_count);
    try std.testing.expectEqual(@as(u32, 0), empty.batch_count);
}

test "mask compiler rejects malformed mask batches" {
    var masks = [_]mask.Instance{.{
        .rect = .{ .x = 0.0, .y = 0.0, .width = 1.0, .height = 1.0 },
        .atlas_rect = .{ .x = 0.0, .y = 0.0, .width = 1.0, .height = 1.0 },
        .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
    }};
    var clips = [_]ClipRect{.{ .x = 0, .y = 0, .width = 640, .height = 480 }};
    var batches = [_]MaskBatch{.{ .vertex_start = 0, .vertex_count = 0, .clip_index = 0 }};
    var scene: Scene = .{
        .clear_color = .{ 0, 0, 0, 1 },
        .drawable_size = .{ 640.0, 480.0 },
        .quads = &.{},
        .batches = &.{},
        .clips = clips[0..],
        .glyphs = &.{},
        .text_batches = &.{},
        .masks = masks[0..],
        .mask_batches = batches[0..],
        .font = null,
    };

    var frame_data: MaskFrameData = undefined;
    try std.testing.expectError(CompileError.InvalidMaskBatch, compileMasks(&scene, &frame_data));

    batches[0].vertex_count = vertices_per_mask;
    batches[0].clip_index = 1;
    try std.testing.expectError(CompileError.InvalidClipIndex, compileMasks(&scene, &frame_data));
}

test "mask compiler rejects malformed mask payloads" {
    var masks = [_]mask.Instance{.{
        .rect = .{ .x = 0.0, .y = 0.0, .width = 1.0, .height = 1.0 },
        .atlas_rect = .{ .x = 0.0, .y = 0.0, .width = 0.25, .height = 0.25 },
        .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
    }};
    var scene: Scene = .{
        .clear_color = .{ 0, 0, 0, 1 },
        .drawable_size = .{ 640.0, 480.0 },
        .quads = &.{},
        .batches = &.{},
        .clips = &.{.{ .x = 0, .y = 0, .width = 640, .height = 480 }},
        .glyphs = &.{},
        .text_batches = &.{},
        .masks = masks[0..],
        .mask_batches = &.{.{ .vertex_start = 0, .vertex_count = vertices_per_mask, .clip_index = 0 }},
        .font = null,
    };
    var frame_data: MaskFrameData = undefined;

    masks[0].rect.width = -1.0;
    try std.testing.expectError(CompileError.InvalidMask, compileMasks(&scene, &frame_data));

    masks[0].rect.width = 1.0;
    masks[0].atlas_rect.y = 0.9;
    masks[0].atlas_rect.height = 0.2;
    try std.testing.expectError(CompileError.InvalidMask, compileMasks(&scene, &frame_data));

    masks[0].atlas_rect.y = 0.0;
    masks[0].atlas_rect.height = 0.25;
    masks[0].color.a = std.math.nan(f32);
    try std.testing.expectError(CompileError.InvalidMask, compileMasks(&scene, &frame_data));
}

test "scene builder rejects invalid geometry and capacity overflow" {
    var storage: SceneStorage = undefined;
    var builder = SceneBuilder.begin(&storage, .{ 640.0, 480.0 }, .{ 0, 0, 0, 1 });
    const clip = try builder.pushDrawableClip();

    try std.testing.expectError(SceneBuildError.NoOpenBatch, builder.pushQuad(.{
        .x = 0,
        .y = 0,
        .width = 10,
        .height = 10,
    }, .{ 1, 1, 1, 1 }, clip));

    try builder.beginBatch(clip);
    try std.testing.expectError(SceneBuildError.InvalidGeometry, builder.pushQuad(.{
        .x = 0,
        .y = 0,
        .width = 0,
        .height = 10,
    }, .{ 1, 1, 1, 1 }, clip));
    try std.testing.expectError(SceneBuildError.InvalidClipIndex, builder.pushQuad(.{
        .x = 0,
        .y = 0,
        .width = 10,
        .height = 10,
    }, .{ 1, 1, 1, 1 }, max_clips));
    const other_clip = try builder.pushClip(.{ .x = 8, .y = 8, .width = 16, .height = 16 });
    try std.testing.expectError(SceneBuildError.BatchClipMismatch, builder.pushQuad(.{
        .x = 0,
        .y = 0,
        .width = 10,
        .height = 10,
    }, .{ 1, 1, 1, 1 }, other_clip));

    for (0..max_quads) |i| {
        try builder.pushQuad(.{
            .x = @floatFromInt(i * 8),
            .y = 0,
            .width = 4,
            .height = 4,
        }, .{ 1, 1, 1, 1 }, clip);
    }
    try std.testing.expectError(SceneBuildError.QuadCapacityExceeded, builder.pushQuad(.{
        .x = 0,
        .y = 0,
        .width = 4,
        .height = 4,
    }, .{ 1, 1, 1, 1 }, clip));
}

test "scene compiler rejects malformed scenes" {
    var quads = [_]Quad{.{
        .rect = .{ .x = 0, .y = 0, .width = 16, .height = 16 },
        .fill_color = .{ 1, 1, 1, 1 },
        .border_color = transparent,
        .radius = .{},
        .border_width = 0,
        .clip_index = 1,
    }};
    var clips = [_]ClipRect{.{ .x = 0, .y = 0, .width = 640, .height = 480 }};
    var batches = [_]Batch{.{ .vertex_start = 0, .vertex_count = vertices_per_quad, .clip_index = 0 }};
    var scene: Scene = .{
        .clear_color = .{ 0, 0, 0, 1 },
        .drawable_size = .{ 640.0, 480.0 },
        .quads = quads[0..],
        .batches = batches[0..],
        .clips = clips[0..],
        .glyphs = &.{},
        .text_batches = &.{},
        .masks = &.{},
        .mask_batches = &.{},
        .font = null,
    };

    var frame_data: FrameData = undefined;
    try std.testing.expectError(CompileError.InvalidClipIndex, compileScene(&scene, &frame_data));

    quads[0].clip_index = 0;
    batches[0].vertex_count = 0;
    try std.testing.expectError(CompileError.InvalidBatch, compileScene(&scene, &frame_data));

    var two_clips = [_]ClipRect{
        .{ .x = 0, .y = 0, .width = 640, .height = 480 },
        .{ .x = 16, .y = 16, .width = 32, .height = 32 },
    };
    scene.clips = two_clips[0..];
    batches[0].vertex_count = vertices_per_quad;
    quads[0].clip_index = 1;
    batches[0].clip_index = 0;
    try std.testing.expectError(CompileError.BatchClipMismatch, compileScene(&scene, &frame_data));

    quads[0].clip_index = 0;
    batches[0].clip_index = max_clips;
    try std.testing.expectError(CompileError.InvalidClipIndex, compileScene(&scene, &frame_data));
}
