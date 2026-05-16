const std = @import("std");

const layout = @import("ui/layout.zig");
const style = @import("ui/style.zig");

pub const max_frame_glyphs = 4096;
pub const atlas_width = 1024;
pub const atlas_height = 512;
pub const atlas_byte_len = atlas_width * atlas_height;
pub const glyph_table_len = 128;

pub const ascii_first = 32;
pub const ascii_last = 126;

pub const Error = error{
    NoFont,
    GlyphCapacityExceeded,
    MissingGlyph,
    UnsupportedCodepoint,
    InvalidAtlas,
};

pub const glyph_present: u32 = 1 << 0;
pub const glyph_visible: u32 = 1 << 1;

pub const AtlasStorage = struct {
    bytes: [atlas_byte_len]u8 = [_]u8{0} ** atlas_byte_len,
};

pub const FontMetrics = extern struct {
    size: f32 = 0.0,
    scale: f32 = 1.0,
    ascent: f32 = 0.0,
    descent: f32 = 0.0,
    leading: f32 = 0.0,
    line_height: f32 = 0.0,
    atlas_width: u32 = atlas_width,
    atlas_height: u32 = atlas_height,
};

pub const GlyphMetric = extern struct {
    codepoint: u32 = 0,
    glyph_id: u32 = 0,
    atlas_x: u32 = 0,
    atlas_y: u32 = 0,
    atlas_width: u32 = 0,
    atlas_height: u32 = 0,
    offset_x: f32 = 0.0,
    offset_y: f32 = 0.0,
    advance: f32 = 0.0,
    flags: u32 = 0,

    pub fn present(metric: GlyphMetric) bool {
        return (metric.flags & glyph_present) != 0;
    }

    pub fn visible(metric: GlyphMetric) bool {
        return (metric.flags & glyph_visible) != 0 and metric.atlas_width != 0 and metric.atlas_height != 0;
    }
};

pub const AtlasRect = extern struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    width: f32 = 0.0,
    height: f32 = 0.0,
};

pub const GlyphInstance = extern struct {
    rect: layout.Rect = .{},
    atlas_rect: AtlasRect = .{},
    color: style.Color = .{},
};

pub const Font = struct {
    metrics: FontMetrics = .{},
    glyphs: [glyph_table_len]GlyphMetric = [_]GlyphMetric{.{}} ** glyph_table_len,

    pub fn glyphForByte(font: *const Font, byte: u8) Error!GlyphMetric {
        if (byte >= glyph_table_len) return Error.UnsupportedCodepoint;
        const metric = font.glyphs[byte];
        if (!metric.present()) return Error.MissingGlyph;
        return metric;
    }

    pub fn lineHeight(font: *const Font) f32 {
        return font.metrics.line_height;
    }
};

pub const PushResult = extern struct {
    advance: f32 = 0.0,
    glyph_count: u32 = 0,
};

pub fn pushAscii(
    font: *const Font,
    out: []GlyphInstance,
    origin: layout.Point,
    bytes: []const u8,
    color: style.Color,
) Error!PushResult {
    var cursor = origin.x;
    var count: usize = 0;

    for (bytes) |byte| {
        if (byte == '\n' or byte == '\r' or byte == '\t') return Error.UnsupportedCodepoint;

        const metric = try font.glyphForByte(byte);
        if (metric.visible()) {
            if (count >= out.len) return Error.GlyphCapacityExceeded;
            out[count] = .{
                .rect = .{
                    .x = cursor + metric.offset_x,
                    .y = origin.y + metric.offset_y,
                    .width = @floatFromInt(metric.atlas_width),
                    .height = @floatFromInt(metric.atlas_height),
                },
                .atlas_rect = .{
                    .x = @as(f32, @floatFromInt(metric.atlas_x)) / @as(f32, @floatFromInt(font.metrics.atlas_width)),
                    .y = @as(f32, @floatFromInt(metric.atlas_y)) / @as(f32, @floatFromInt(font.metrics.atlas_height)),
                    .width = @as(f32, @floatFromInt(metric.atlas_width)) / @as(f32, @floatFromInt(font.metrics.atlas_width)),
                    .height = @as(f32, @floatFromInt(metric.atlas_height)) / @as(f32, @floatFromInt(font.metrics.atlas_height)),
                },
                .color = color,
            };
            count += 1;
        }
        cursor += metric.advance;
    }

    return .{
        .advance = cursor - origin.x,
        .glyph_count = @intCast(count),
    };
}

comptime {
    std.debug.assert(@sizeOf(FontMetrics) == 32);
    std.debug.assert(@sizeOf(GlyphMetric) == 40);
    std.debug.assert(@sizeOf(AtlasRect) == 16);
    std.debug.assert(@sizeOf(GlyphInstance) == 48);
}

test "ascii text emits visible glyph instances and advances over spaces" {
    var font: Font = .{};
    font.metrics = .{
        .size = 14.0,
        .scale = 2.0,
        .ascent = 10.0,
        .descent = 4.0,
        .line_height = 16.0,
        .atlas_width = atlas_width,
        .atlas_height = atlas_height,
    };
    font.glyphs['A'] = .{
        .codepoint = 'A',
        .glyph_id = 1,
        .atlas_x = 8,
        .atlas_y = 16,
        .atlas_width = 7,
        .atlas_height = 9,
        .offset_x = 1.0,
        .offset_y = 2.0,
        .advance = 8.0,
        .flags = glyph_present | glyph_visible,
    };
    font.glyphs[' '] = .{
        .codepoint = ' ',
        .advance = 4.0,
        .flags = glyph_present,
    };

    var glyphs: [4]GlyphInstance = undefined;
    const result = try pushAscii(&font, glyphs[0..], layout.Point.init(10.0, 20.0), "A A", style.Color.rgb(1.0, 1.0, 1.0));

    try std.testing.expectEqual(@as(u32, 2), result.glyph_count);
    try std.testing.expectEqual(@as(f32, 20.0), result.advance);
    try std.testing.expectEqual(layout.Rect.init(11.0, 22.0, 7.0, 9.0), glyphs[0].rect);
    try std.testing.expectEqual(layout.Rect.init(23.0, 22.0, 7.0, 9.0), glyphs[1].rect);
}

test "ascii text rejects missing glyphs and output overflow" {
    var font: Font = .{};
    font.glyphs['A'] = .{
        .codepoint = 'A',
        .atlas_width = 1,
        .atlas_height = 1,
        .advance = 1.0,
        .flags = glyph_present | glyph_visible,
    };

    var glyphs: [1]GlyphInstance = undefined;
    try std.testing.expectError(Error.MissingGlyph, pushAscii(&font, glyphs[0..], .{}, "B", .{}));
    try std.testing.expectError(Error.GlyphCapacityExceeded, pushAscii(&font, glyphs[0..], .{}, "AA", .{}));
}
