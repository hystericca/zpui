const std = @import("std");

const defs = @import("defs.zig");
const font = @import("font.zig");
const atlas = @import("atlas.zig");
const style = @import("../ui/style.zig");

pub const PushResult = extern struct {
    advance: f32 = 0.0,
    glyph_count: u32 = 0,
};

pub const TextRun = struct {
    bytes: []const u8,
    font: font.FontHandle,
    size: f32 = defs.default_font_size,
    color: style.Color,
};

pub const AsciiRun = struct {
    bytes: []const u8,
    color: style.Color,
    font_slot: u32 = defs.default_font_slot,
};

pub const LineGlyph = struct {
    instance: atlas.GlyphInstance = .{},
    byte_index: u32 = 0,
};

pub const TextLineStorage = struct {
    glyphs: [defs.max_line_glyphs]LineGlyph = undefined,
};

pub const TextLine = struct {
    advance: f32 = 0.0,
    ascent: f32 = 0.0,
    descent: f32 = 0.0,
    leading: f32 = 0.0,
    line_height: f32 = 0.0,
    baseline_offset: f32 = 0.0,
    bytes_len: u32 = 0,
    glyphs: []const LineGlyph = &.{},

    pub fn xForByte(line: TextLine, byte_index: u32) f32 {
        var x: f32 = 0.0;
        for (line.glyphs) |glyph| {
            if (glyph.byte_index > byte_index) break;
            x = glyph.instance.rect.x;
            if (glyph.byte_index == byte_index) return x;
        }
        if (byte_index >= line.bytes_len) return line.advance;
        return x;
    }

    pub fn byteForX(line: TextLine, x: f32) u32 {
        var closest: u32 = 0;
        for (line.glyphs) |glyph| {
            const left = glyph.instance.rect.x;
            const right = left + glyph.instance.rect.width;
            if (x < left) return closest;
            if (x <= right) return glyph.byte_index;
            closest = glyph.byte_index;
        }
        return line.bytes_len;
    }
};

pub fn colorForByte(runs: []const TextRun, byte_index: u32) style.Color {
    var start: u32 = 0;
    var last: style.Color = .{};
    for (runs) |run| {
        last = run.color;
        const run_len: u32 = @intCast(@min(run.bytes.len, @as(usize, std.math.maxInt(u32) - start)));
        const end = start + run_len;
        if (byte_index < end) return run.color;
        start = end;
    }
    return last;
}
