const std = @import("std");
const text = @import("text.zig");

pub const max_quads = 128;
pub const max_batches = 32;
pub const max_clips = 32;
pub const vertices_per_quad = 6;
pub const max_draw_vertices = max_quads * vertices_per_quad;

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

pub const Quad = struct {
    rect: Rect,
    color: Color,
    clip_index: u32,
};

pub const GpuQuad = extern struct {
    rect: Rect,
    color: Color,
};

pub const Batch = extern struct {
    vertex_start: u32,
    vertex_count: u32,
    clip_index: u32,
    reserved: u32 = 0,
};

pub const Scene = struct {
    clear_color: ClearColor,
    drawable_size: [2]f32,
    quads: []const Quad,
    batches: []const Batch,
    clips: []const ClipRect,
    glyphs: []const text.GlyphInstance,
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

comptime {
    std.debug.assert(@sizeOf(Rect) == 16);
    std.debug.assert(@sizeOf(ClipRect) == 16);
    std.debug.assert(@sizeOf(GpuQuad) == 32);
    std.debug.assert(@sizeOf(Batch) == 16);
    std.debug.assert(@sizeOf(FrameData) == frameDataByteLen(max_quads));
    std.debug.assert(@offsetOf(FrameData, "drawable_size") == 0);
    std.debug.assert(@offsetOf(FrameData, "quad_count") == 8);
    std.debug.assert(@offsetOf(FrameData, "quads") == 16);
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
    BatchClipMismatch,
};

pub const CompileResult = struct {
    draw_vertex_count: u32,
    quad_count: u32,
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
        if (builder.batch_open) return SceneBuildError.BatchAlreadyOpen;
        if (clip_index >= builder.clip_count) return SceneBuildError.InvalidClipIndex;
        if (builder.batch_count >= max_batches) return SceneBuildError.BatchCapacityExceeded;

        builder.open_batch_start = builder.quad_count;
        builder.open_batch_clip = clip_index;
        builder.batch_open = true;
    }

    pub fn pushQuad(builder: *SceneBuilder, rect: Rect, color: Color, clip_index: u32) SceneBuildError!void {
        if (!builder.batch_open) return SceneBuildError.NoOpenBatch;
        if (rect.width <= 0 or rect.height <= 0) return SceneBuildError.InvalidGeometry;
        if (clip_index >= builder.clip_count) return SceneBuildError.InvalidClipIndex;
        if (clip_index != builder.open_batch_clip) return SceneBuildError.BatchClipMismatch;
        if (builder.quad_count >= max_quads) return SceneBuildError.QuadCapacityExceeded;

        builder.storage.quads[@intCast(builder.quad_count)] = .{
            .rect = rect,
            .color = color,
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
            .color = quad.color,
        };
    }

    return .{
        .draw_vertex_count = draw_vertex_count,
        .quad_count = @intCast(scene.quads.len),
        .batch_count = @intCast(scene.batches.len),
    };
}

pub fn frameDataByteLen(quad_count: u32) usize {
    return @offsetOf(FrameData, "quads") + @as(usize, @intCast(quad_count)) * @sizeOf(GpuQuad);
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
    if (value <= 0) return 0;
    const capped = @min(value, @as(f32, @floatFromInt(std.math.maxInt(u32))));
    return @intFromFloat(capped);
}

test "scene and GPU frame layouts stay stable" {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Rect));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(ClipRect));
    try std.testing.expectEqual(@as(usize, 36), @sizeOf(Quad));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(GpuQuad));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Batch));
    try std.testing.expectEqual(frameDataByteLen(max_quads), @sizeOf(FrameData));

    try std.testing.expectEqual(@as(usize, 0), @offsetOf(FrameData, "drawable_size"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(FrameData, "quad_count"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(FrameData, "quads"));
    try std.testing.expectEqual(@as(usize, 16), frameDataByteLen(0));
    try std.testing.expectEqual(@as(usize, 48), frameDataByteLen(1));
    try std.testing.expectEqual(@sizeOf(FrameData), frameDataByteLen(max_quads));
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
    try std.testing.expectEqual(scene.quads[0].color, frame_data.quads[0].color);
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
        .color = .{ 1, 1, 1, 1 },
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
