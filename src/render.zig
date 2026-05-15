const std = @import("std");

pub const max_quads = 128;
pub const max_batches = 1;
pub const max_clips = 1;
pub const vertices_per_quad = 6;
pub const max_draw_vertices = max_quads * vertices_per_quad;

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

pub const Quad = extern struct {
    rect: Rect,
    color: [4]f32,
    clip_index: u32,
    reserved: [3]u32 = .{ 0, 0, 0 },
};

pub const Batch = extern struct {
    vertex_start: u32,
    vertex_count: u32,
    clip_index: u32,
    reserved: u32 = 0,
};

pub const RenderPacket = extern struct {
    clear_color: [4]f64,
    drawable_size: [2]f32,
    quad_count: u32,
    batch_count: u32,
    clip_count: u32,
    reserved: u32 = 0,
    quads: [max_quads]Quad,
    batches: [max_batches]Batch,
    clips: [max_clips]ClipRect,
};

pub const GpuFrameData = extern struct {
    drawable_size: [2]f32,
    quad_count: u32,
    reserved: u32 = 0,
    quads: [max_quads]Quad,
};

comptime {
    std.debug.assert(@sizeOf(Rect) == 16);
    std.debug.assert(@sizeOf(ClipRect) == 16);
    std.debug.assert(@sizeOf(Quad) == 48);
    std.debug.assert(@sizeOf(Batch) == 16);
    std.debug.assert(@sizeOf(RenderPacket) == renderPacketByteLen());
    std.debug.assert(@offsetOf(RenderPacket, "clear_color") == 0);
    std.debug.assert(@offsetOf(RenderPacket, "drawable_size") == 32);
    std.debug.assert(@offsetOf(RenderPacket, "quads") == 56);
    std.debug.assert(@offsetOf(RenderPacket, "batches") == batchOffset());
    std.debug.assert(@offsetOf(RenderPacket, "clips") == clipOffset());
    std.debug.assert(@sizeOf(GpuFrameData) == gpuFrameDataByteLen(max_quads));
    std.debug.assert(@offsetOf(GpuFrameData, "drawable_size") == 0);
    std.debug.assert(@offsetOf(GpuFrameData, "quad_count") == 8);
    std.debug.assert(@offsetOf(GpuFrameData, "quads") == 16);
}

pub const PacketBuildError = error{
    InvalidGeometry,
    InvalidClipIndex,
    QuadCapacityExceeded,
    EmptyBatch,
    BatchCapacityExceeded,
};

pub const CompileError = error{
    InvalidClipIndex,
    InvalidBatch,
    QuadCapacityExceeded,
};

pub const CompileResult = struct {
    draw_vertex_count: u32,
    quad_count: u32,
};

pub fn resetPacket(packet: *RenderPacket, drawable_size: [2]f32, clear_color: [4]f64) void {
    packet.* = std.mem.zeroes(RenderPacket);
    packet.clear_color = clear_color;
    packet.drawable_size = drawable_size;
}

pub fn setDrawableClip(packet: *RenderPacket) void {
    packet.clip_count = 1;
    packet.clips[0] = drawableClip(packet.drawable_size);
}

pub fn appendSolidQuad(packet: *RenderPacket, rect: Rect, color: [4]f32, clip_index: u32) PacketBuildError!void {
    if (rect.width <= 0 or rect.height <= 0) return PacketBuildError.InvalidGeometry;
    if (packet.quad_count >= max_quads) return PacketBuildError.QuadCapacityExceeded;
    if (clip_index >= max_clips) return PacketBuildError.InvalidClipIndex;

    packet.quads[@intCast(packet.quad_count)] = .{
        .rect = rect,
        .color = color,
        .clip_index = clip_index,
    };
    packet.quad_count += 1;
}

pub fn finalizeSingleBatch(packet: *RenderPacket, clip_index: u32) PacketBuildError!void {
    if (packet.quad_count == 0) return PacketBuildError.EmptyBatch;
    if (packet.batch_count >= max_batches) return PacketBuildError.BatchCapacityExceeded;
    if (clip_index >= packet.clip_count) return PacketBuildError.InvalidClipIndex;

    packet.batch_count = 1;
    packet.batches[0] = .{
        .vertex_start = 0,
        .vertex_count = packet.quad_count * vertices_per_quad,
        .clip_index = clip_index,
    };
}

pub fn compilePacket(packet: *const RenderPacket, frame_data: *GpuFrameData) CompileError!CompileResult {
    if (packet.quad_count > max_quads or
        packet.batch_count > max_batches or
        packet.clip_count > max_clips) return CompileError.QuadCapacityExceeded;

    const quad_count: usize = @intCast(packet.quad_count);
    const max_vertex_count = packet.quad_count * vertices_per_quad;
    for (packet.quads[0..quad_count]) |quad| {
        if (quad.clip_index >= packet.clip_count) return CompileError.InvalidClipIndex;
    }

    var draw_vertex_count: u32 = 0;
    const batch_count: usize = @intCast(packet.batch_count);
    for (packet.batches[0..batch_count]) |batch| {
        if (batch.clip_index >= packet.clip_count) return CompileError.InvalidClipIndex;
        if (batch.vertex_count == 0 or batch.vertex_count % vertices_per_quad != 0) return CompileError.InvalidBatch;
        if (batch.vertex_start > max_vertex_count or batch.vertex_count > max_vertex_count - batch.vertex_start) return CompileError.InvalidBatch;
        draw_vertex_count += batch.vertex_count;
    }

    frame_data.drawable_size = packet.drawable_size;
    frame_data.quad_count = packet.quad_count;
    frame_data.reserved = 0;
    @memcpy(frame_data.quads[0..quad_count], packet.quads[0..quad_count]);

    return .{
        .draw_vertex_count = draw_vertex_count,
        .quad_count = packet.quad_count,
    };
}

pub fn gpuFrameDataByteLen(quad_count: u32) usize {
    return @offsetOf(GpuFrameData, "quads") + @as(usize, @intCast(quad_count)) * @sizeOf(Quad);
}

pub fn renderPacketByteLen() usize {
    return clipOffset() + @sizeOf(ClipRect) * max_clips;
}

fn batchOffset() usize {
    return @offsetOf(RenderPacket, "quads") + @sizeOf(Quad) * max_quads;
}

fn clipOffset() usize {
    return batchOffset() + @sizeOf(Batch) * max_batches;
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

test "render packet and GPU frame layouts stay stable" {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Rect));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(ClipRect));
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(Quad));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Batch));
    try std.testing.expectEqual(gpuFrameDataByteLen(max_quads), @sizeOf(GpuFrameData));

    try std.testing.expectEqual(renderPacketByteLen(), @sizeOf(RenderPacket));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(RenderPacket, "clear_color"));
    try std.testing.expectEqual(@as(usize, 32), @offsetOf(RenderPacket, "drawable_size"));
    try std.testing.expectEqual(@as(usize, 56), @offsetOf(RenderPacket, "quads"));
    try std.testing.expectEqual(batchOffset(), @offsetOf(RenderPacket, "batches"));
    try std.testing.expectEqual(clipOffset(), @offsetOf(RenderPacket, "clips"));

    try std.testing.expectEqual(@as(usize, 0), @offsetOf(GpuFrameData, "drawable_size"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(GpuFrameData, "quad_count"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(GpuFrameData, "quads"));
    try std.testing.expectEqual(@as(usize, 16), gpuFrameDataByteLen(0));
    try std.testing.expectEqual(@as(usize, 64), gpuFrameDataByteLen(1));
    try std.testing.expectEqual(@sizeOf(GpuFrameData), gpuFrameDataByteLen(max_quads));
}

test "solid quad compiler emits compact GPU frame data" {
    var packet: RenderPacket = undefined;
    resetPacket(&packet, .{ 100.0, 50.0 }, .{ 0.035, 0.045, 0.06, 1.0 });
    setDrawableClip(&packet);
    try appendSolidQuad(&packet, .{
        .x = 10.0,
        .y = 5.0,
        .width = 20.0,
        .height = 10.0,
    }, .{ 0.25, 0.72, 1.0, 1.0 }, 0);
    try finalizeSingleBatch(&packet, 0);

    try std.testing.expectEqual(@as(u32, 6), packet.batches[0].vertex_count);
    try std.testing.expectEqual(@as(u32, 100), packet.clips[0].width);
    try std.testing.expectEqual(@as(u32, 50), packet.clips[0].height);

    var frame_data: GpuFrameData = undefined;
    const result = try compilePacket(&packet, &frame_data);

    try std.testing.expectEqual(@as(u32, 6), result.draw_vertex_count);
    try std.testing.expectEqual(@as(u32, 1), result.quad_count);
    try std.testing.expectEqual([2]f32{ 100.0, 50.0 }, frame_data.drawable_size);
    try std.testing.expectEqual(@as(u32, 1), frame_data.quad_count);
    try std.testing.expectEqual(packet.quads[0], frame_data.quads[0]);
}

test "render packet builders reject invalid geometry and capacity overflow" {
    var packet: RenderPacket = undefined;
    resetPacket(&packet, .{ 640.0, 480.0 }, .{ 0, 0, 0, 1 });
    setDrawableClip(&packet);

    try std.testing.expectError(PacketBuildError.InvalidGeometry, appendSolidQuad(&packet, .{
        .x = 0,
        .y = 0,
        .width = 0,
        .height = 10,
    }, .{ 1, 1, 1, 1 }, 0));
    try std.testing.expectError(PacketBuildError.InvalidClipIndex, appendSolidQuad(&packet, .{
        .x = 0,
        .y = 0,
        .width = 10,
        .height = 10,
    }, .{ 1, 1, 1, 1 }, max_clips));

    for (0..max_quads) |i| {
        try appendSolidQuad(&packet, .{
            .x = @floatFromInt(i * 8),
            .y = 0,
            .width = 4,
            .height = 4,
        }, .{ 1, 1, 1, 1 }, 0);
    }
    try std.testing.expectError(PacketBuildError.QuadCapacityExceeded, appendSolidQuad(&packet, .{
        .x = 0,
        .y = 0,
        .width = 4,
        .height = 4,
    }, .{ 1, 1, 1, 1 }, 0));
    try finalizeSingleBatch(&packet, 0);
    try std.testing.expectEqual(@as(u32, max_draw_vertices), packet.batches[0].vertex_count);
}

test "render compiler rejects malformed packets" {
    var packet: RenderPacket = undefined;
    resetPacket(&packet, .{ 640.0, 480.0 }, .{ 0, 0, 0, 1 });
    setDrawableClip(&packet);
    packet.quad_count = 1;
    packet.quads[0] = .{
        .rect = .{ .x = 0, .y = 0, .width = 16, .height = 16 },
        .color = .{ 1, 1, 1, 1 },
        .clip_index = 1,
    };

    var frame_data: GpuFrameData = undefined;
    try std.testing.expectError(CompileError.InvalidClipIndex, compilePacket(&packet, &frame_data));

    packet.quad_count = max_quads + 1;
    packet.quads[0].clip_index = 0;
    try std.testing.expectError(CompileError.QuadCapacityExceeded, compilePacket(&packet, &frame_data));

    resetPacket(&packet, .{ 640.0, 480.0 }, .{ 0, 0, 0, 1 });
    setDrawableClip(&packet);
    try appendSolidQuad(&packet, .{
        .x = 0,
        .y = 0,
        .width = 16,
        .height = 16,
    }, .{ 1, 1, 1, 1 }, 0);
    packet.batch_count = 1;
    packet.batches[0] = .{
        .vertex_start = 0,
        .vertex_count = 0,
        .clip_index = 0,
    };
    try std.testing.expectError(CompileError.InvalidBatch, compilePacket(&packet, &frame_data));

    packet.batches[0].vertex_count = vertices_per_quad;
    packet.batches[0].clip_index = max_clips;
    try std.testing.expectError(CompileError.InvalidClipIndex, compilePacket(&packet, &frame_data));
}
