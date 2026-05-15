const std = @import("std");

pub const max_vertices = 3;

pub const Vertex = extern struct {
    position: [4]f32,
    color: [4]f32,
};

pub const Frame = extern struct {
    clear_color: [4]f64,
    vertex_count: u32,
    reserved: [3]u32 = .{ 0, 0, 0 },
    vertices: [max_vertices]Vertex,
};

pub fn buildFrame(frame: *Frame) void {
    frame.* = .{
        .clear_color = .{ 0.035, 0.045, 0.06, 1.0 },
        .vertex_count = max_vertices,
        .vertices = .{
            .{
                .position = .{ 0.0, 0.72, 0.0, 1.0 },
                .color = .{ 0.40, 0.80, 1.00, 1.0 },
            },
            .{
                .position = .{ -0.72, -0.58, 0.0, 1.0 },
                .color = .{ 1.00, 0.35, 0.26, 1.0 },
            },
            .{
                .position = .{ 0.72, -0.58, 0.0, 1.0 },
                .color = .{ 0.75, 1.00, 0.42, 1.0 },
            },
        },
    };
}

test "frame command layout is C ABI friendly" {
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(Vertex));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(Vertex, "position"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(Vertex, "color"));

    try std.testing.expectEqual(@as(usize, 144), @sizeOf(Frame));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(Frame, "clear_color"));
    try std.testing.expectEqual(@as(usize, 32), @offsetOf(Frame, "vertex_count"));
    try std.testing.expectEqual(@as(usize, 48), @offsetOf(Frame, "vertices"));

    var frame: Frame = undefined;
    buildFrame(&frame);

    try std.testing.expectEqual(@as(u32, 3), frame.vertex_count);
    try std.testing.expectEqual(@as(f32, -0.72), frame.vertices[1].position[0]);
}
