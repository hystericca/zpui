const std = @import("std");

pub const max_quads = 8;
pub const max_batches = 1;
pub const max_clips = 1;
pub const vertices_per_quad = 6;
pub const max_vertices = max_quads * vertices_per_quad;

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

pub const Vertex = extern struct {
    position: [4]f32,
    color: [4]f32,
};

pub const CompileError = error{
    InvalidClipIndex,
    VertexCapacityExceeded,
};

pub const CompileResult = struct {
    vertex_count: u32,
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

pub fn appendSolidQuad(packet: *RenderPacket, rect: Rect, color: [4]f32, clip_index: u32) bool {
    if (packet.quad_count >= max_quads or rect.width <= 0 or rect.height <= 0) return false;
    if (clip_index >= max_clips) return false;

    packet.quads[@intCast(packet.quad_count)] = .{
        .rect = rect,
        .color = color,
        .clip_index = clip_index,
    };
    packet.quad_count += 1;
    return true;
}

pub fn finalizeSingleBatch(packet: *RenderPacket, clip_index: u32) bool {
    if (packet.quad_count == 0 or packet.batch_count >= max_batches or clip_index >= packet.clip_count) return false;

    packet.batch_count = 1;
    packet.batches[0] = .{
        .vertex_start = 0,
        .vertex_count = packet.quad_count * vertices_per_quad,
        .clip_index = clip_index,
    };
    return true;
}

pub fn compilePacket(packet: *const RenderPacket, vertices: *[max_vertices]Vertex) CompileError!CompileResult {
    var vertex_count: usize = 0;
    if (packet.quad_count > max_quads or
        packet.batch_count > max_batches or
        packet.clip_count > max_clips) return CompileError.VertexCapacityExceeded;

    const quad_count: usize = @intCast(packet.quad_count);
    const drawable_width = packet.drawable_size[0];
    const drawable_height = packet.drawable_size[1];

    for (packet.quads[0..quad_count]) |quad| {
        if (quad.clip_index >= packet.clip_count) return CompileError.InvalidClipIndex;
        if (vertex_count + vertices_per_quad > vertices.len) return CompileError.VertexCapacityExceeded;

        writeQuadVertices(
            vertices,
            vertex_count,
            quad.rect,
            quad.color,
            drawable_width,
            drawable_height,
        );
        vertex_count += vertices_per_quad;
    }

    return .{ .vertex_count = @intCast(vertex_count) };
}

fn writeQuadVertices(
    vertices: *[max_vertices]Vertex,
    start: usize,
    rect: Rect,
    color: [4]f32,
    drawable_width: f32,
    drawable_height: f32,
) void {
    const x0 = toClipX(rect.x, drawable_width);
    const x1 = toClipX(rect.x + rect.width, drawable_width);
    const y0 = toClipY(rect.y, drawable_height);
    const y1 = toClipY(rect.y + rect.height, drawable_height);

    vertices[start + 0] = vertex(x0, y0, color);
    vertices[start + 1] = vertex(x0, y1, color);
    vertices[start + 2] = vertex(x1, y0, color);
    vertices[start + 3] = vertex(x1, y0, color);
    vertices[start + 4] = vertex(x0, y1, color);
    vertices[start + 5] = vertex(x1, y1, color);
}

fn vertex(x: f32, y: f32, color: [4]f32) Vertex {
    return .{
        .position = .{ x, y, 0.0, 1.0 },
        .color = color,
    };
}

fn toClipX(x: f32, drawable_width: f32) f32 {
    if (drawable_width <= 0) return 0;
    return x / drawable_width * 2.0 - 1.0;
}

fn toClipY(y: f32, drawable_height: f32) f32 {
    if (drawable_height <= 0) return 0;
    return 1.0 - y / drawable_height * 2.0;
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

test "render packet layout is C ABI friendly" {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Rect));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(ClipRect));
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(Quad));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Batch));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(Vertex));

    try std.testing.expectEqual(@as(usize, 472), @sizeOf(RenderPacket));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(RenderPacket, "clear_color"));
    try std.testing.expectEqual(@as(usize, 32), @offsetOf(RenderPacket, "drawable_size"));
    try std.testing.expectEqual(@as(usize, 56), @offsetOf(RenderPacket, "quads"));
    try std.testing.expectEqual(@as(usize, 440), @offsetOf(RenderPacket, "batches"));
    try std.testing.expectEqual(@as(usize, 456), @offsetOf(RenderPacket, "clips"));
}

test "solid quad compiler emits two triangles in clip space" {
    var packet: RenderPacket = undefined;
    resetPacket(&packet, .{ 100.0, 50.0 }, .{ 0.035, 0.045, 0.06, 1.0 });
    setDrawableClip(&packet);
    try std.testing.expect(appendSolidQuad(&packet, .{
        .x = 10.0,
        .y = 5.0,
        .width = 20.0,
        .height = 10.0,
    }, .{ 0.25, 0.72, 1.0, 1.0 }, 0));
    try std.testing.expect(finalizeSingleBatch(&packet, 0));

    try std.testing.expectEqual(@as(u32, 6), packet.batches[0].vertex_count);
    try std.testing.expectEqual(@as(u32, 100), packet.clips[0].width);
    try std.testing.expectEqual(@as(u32, 50), packet.clips[0].height);

    var vertices: [max_vertices]Vertex = undefined;
    const result = try compilePacket(&packet, &vertices);

    try std.testing.expectEqual(@as(u32, 6), result.vertex_count);
    try expectVertex(vertices[0], -0.8, 0.8, .{ 0.25, 0.72, 1.0, 1.0 });
    try expectVertex(vertices[1], -0.8, 0.4, .{ 0.25, 0.72, 1.0, 1.0 });
    try expectVertex(vertices[2], -0.4, 0.8, .{ 0.25, 0.72, 1.0, 1.0 });
    try expectVertex(vertices[3], -0.4, 0.8, .{ 0.25, 0.72, 1.0, 1.0 });
    try expectVertex(vertices[4], -0.8, 0.4, .{ 0.25, 0.72, 1.0, 1.0 });
    try expectVertex(vertices[5], -0.4, 0.4, .{ 0.25, 0.72, 1.0, 1.0 });
}

test "render packet builders reject invalid geometry and capacity overflow" {
    var packet: RenderPacket = undefined;
    resetPacket(&packet, .{ 640.0, 480.0 }, .{ 0, 0, 0, 1 });
    setDrawableClip(&packet);

    try std.testing.expect(!appendSolidQuad(&packet, .{
        .x = 0,
        .y = 0,
        .width = 0,
        .height = 10,
    }, .{ 1, 1, 1, 1 }, 0));
    try std.testing.expect(!appendSolidQuad(&packet, .{
        .x = 0,
        .y = 0,
        .width = 10,
        .height = 10,
    }, .{ 1, 1, 1, 1 }, max_clips));

    for (0..max_quads) |i| {
        try std.testing.expect(appendSolidQuad(&packet, .{
            .x = @floatFromInt(i * 8),
            .y = 0,
            .width = 4,
            .height = 4,
        }, .{ 1, 1, 1, 1 }, 0));
    }
    try std.testing.expect(!appendSolidQuad(&packet, .{
        .x = 0,
        .y = 0,
        .width = 4,
        .height = 4,
    }, .{ 1, 1, 1, 1 }, 0));
    try std.testing.expect(finalizeSingleBatch(&packet, 0));
    try std.testing.expectEqual(@as(u32, max_vertices), packet.batches[0].vertex_count);
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

    var vertices: [max_vertices]Vertex = undefined;
    try std.testing.expectError(CompileError.InvalidClipIndex, compilePacket(&packet, &vertices));

    packet.quad_count = max_quads + 1;
    packet.quads[0].clip_index = 0;
    try std.testing.expectError(CompileError.VertexCapacityExceeded, compilePacket(&packet, &vertices));
}

fn expectVertex(actual: Vertex, expected_x: f32, expected_y: f32, expected_color: [4]f32) !void {
    try std.testing.expectApproxEqAbs(expected_x, actual.position[0], 0.001);
    try std.testing.expectApproxEqAbs(expected_y, actual.position[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), actual.position[2], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), actual.position[3], 0.001);
    try std.testing.expectEqual(expected_color, actual.color);
}
