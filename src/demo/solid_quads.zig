const render = @import("../render.zig");

pub fn buildPacket(packet: *render.RenderPacket, drawable_size: [2]f32) render.PacketBuildError!void {
    render.resetPacket(packet, drawable_size, .{ 0.035, 0.045, 0.06, 1.0 });
    render.setDrawableClip(packet);

    if (drawable_size[0] <= 0 or drawable_size[1] <= 0) return;

    const width = drawable_size[0];
    const height = drawable_size[1];
    const top_h: f32 = @min(@max(height * 0.11, 48.0), 72.0);
    const rail_w: f32 = @min(@max(width * 0.22, 172.0), 240.0);
    const gap: f32 = @min(@max(width * 0.025, 18.0), 32.0);

    try render.appendSolidQuad(packet, .{
        .x = 0,
        .y = 0,
        .width = width,
        .height = top_h,
    }, .{ 0.070, 0.090, 0.120, 1.0 }, 0);
    try render.appendSolidQuad(packet, .{
        .x = 0,
        .y = top_h,
        .width = rail_w,
        .height = @max(height - top_h, 1.0),
    }, .{ 0.055, 0.070, 0.095, 1.0 }, 0);
    try render.appendSolidQuad(packet, .{
        .x = rail_w + gap,
        .y = top_h + gap,
        .width = @max(width - rail_w - gap * 2.0, 1.0),
        .height = @max(height - top_h - gap * 2.0, 1.0),
    }, .{ 0.105, 0.125, 0.155, 1.0 }, 0);
    try render.appendSolidQuad(packet, .{
        .x = rail_w + gap * 2.0,
        .y = top_h + gap * 2.0,
        .width = @min(@max(width * 0.36, 220.0), @max(width - rail_w - gap * 4.0, 1.0)),
        .height = 12.0,
    }, .{ 0.25, 0.72, 1.00, 1.0 }, 0);
    try render.appendSolidQuad(packet, .{
        .x = gap,
        .y = top_h + gap,
        .width = @max(rail_w - gap * 2.0, 1.0),
        .height = 36.0,
    }, .{ 0.18, 0.28, 0.36, 1.0 }, 0);
    try render.finalizeSingleBatch(packet, 0);
}
