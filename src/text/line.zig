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

pub const ShapedGlyph = struct {
    font: font.FontHandle = .{},
    glyph_id: u32 = 0,
    byte_index: u32 = 0,
    x: f32 = 0.0,
    y: f32 = 0.0,
    size: f32 = defs.default_font_size,
};

pub const ShapedLineStorage = struct {
    glyphs: [defs.max_line_glyphs]ShapedGlyph = undefined,
};

pub const ShapedLine = struct {
    advance: f32 = 0.0,
    ascent: f32 = 0.0,
    descent: f32 = 0.0,
    leading: f32 = 0.0,
    line_height: f32 = 0.0,
    baseline_offset: f32 = 0.0,
    bytes_len: u32 = 0,
    glyphs: []const ShapedGlyph = &.{},

    pub fn xForByte(line: ShapedLine, byte_index: u32) f32 {
        var x: f32 = 0.0;
        for (line.glyphs) |glyph| {
            if (glyph.byte_index > byte_index) break;
            x = glyph.x;
            if (glyph.byte_index == byte_index) return x;
        }
        if (byte_index >= line.bytes_len) return line.advance;
        return x;
    }

    pub fn byteForX(line: ShapedLine, x: f32) u32 {
        var closest: u32 = 0;
        for (line.glyphs) |glyph| {
            if (x < glyph.x) return closest;
            closest = glyph.byte_index;
        }
        if (x < line.advance) return closest;
        return line.bytes_len;
    }
};

pub const PreparedGlyph = struct {
    instance: atlas.GlyphInstance = .{},
    byte_index: u32 = 0,
};

pub const PreparedLineStorage = struct {
    glyphs: [defs.max_line_glyphs]PreparedGlyph = undefined,
};

pub const PreparedLine = struct {
    advance: f32 = 0.0,
    ascent: f32 = 0.0,
    descent: f32 = 0.0,
    leading: f32 = 0.0,
    line_height: f32 = 0.0,
    baseline_offset: f32 = 0.0,
    bytes_len: u32 = 0,
    glyphs: []const PreparedGlyph = &.{},

    pub fn xForByte(line: PreparedLine, byte_index: u32) f32 {
        var x: f32 = 0.0;
        for (line.glyphs) |glyph| {
            if (glyph.byte_index > byte_index) break;
            x = glyph.instance.rect.x;
            if (glyph.byte_index == byte_index) return x;
        }
        if (byte_index >= line.bytes_len) return line.advance;
        return x;
    }

    pub fn byteForX(line: PreparedLine, x: f32) u32 {
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

pub fn runsByteLen(runs: []const TextRun) defs.Error!u32 {
    if (runs.len == 0 or runs.len > defs.max_line_runs) return defs.Error.InvalidFontOptions;

    var total: usize = 0;
    const max_text_bytes = std.math.maxInt(u32);
    for (runs) |run| {
        if (run.bytes.len == 0) return defs.Error.InvalidUtf8;
        if (run.bytes.len > max_text_bytes - total) return defs.Error.InvalidUtf8;
        total += run.bytes.len;
    }
    return @intCast(total);
}
