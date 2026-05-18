const std = @import("std");

const layout = @import("ui/layout.zig");
const style = @import("ui/style.zig");

pub const max_frame_glyphs = 16384;
pub const atlas_width = 1024;
pub const atlas_height = 512;
pub const atlas_byte_len = atlas_width * atlas_height;
pub const glyph_table_len = 128;
pub const max_font_slots = 4;
pub const default_font_slot: u32 = 0;
pub const max_font_family_len = 127;
pub const max_resolved_font_name_len = 127;
pub const max_font_variations = 8;
pub const default_font_family: [:0]const u8 = "Menlo";
pub const default_font_size: f32 = 13.0;

pub const ascii_first = 32;
pub const ascii_last = 126;

pub const Error = error{
    NoFont,
    InvalidFontSlot,
    GlyphCapacityExceeded,
    MissingGlyph,
    UnsupportedCodepoint,
    InvalidAtlas,
};

pub const FontVariation = extern struct {
    tag: u32 = 0,
    value: f32 = 0.0,

    pub fn valid(variation: FontVariation) bool {
        return variation.tag != 0 and std.math.isFinite(variation.value);
    }
};

pub fn axis(comptime tag: []const u8) u32 {
    comptime {
        if (tag.len != 4) @compileError("font variation axis tags must be four bytes");
    }
    return (@as(u32, tag[0]) << 24) |
        (@as(u32, tag[1]) << 16) |
        (@as(u32, tag[2]) << 8) |
        @as(u32, tag[3]);
}

pub const FontOptions = struct {
    family: [:0]const u8 = default_font_family,
    size: f32 = default_font_size,
    variations: []const FontVariation = &.{},

    pub fn valid(options: FontOptions) bool {
        if (options.family.len == 0 or options.family.len > max_font_family_len) return false;
        if (options.size <= 0.0 or !std.math.isFinite(options.size)) return false;
        if (options.variations.len > max_font_variations) return false;
        for (options.variations, 0..) |variation, index| {
            if (!variation.valid()) return false;
            for (options.variations[0..index]) |previous| {
                if (previous.tag == variation.tag) return false;
            }
        }
        return true;
    }
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
    font_slot: u32 = default_font_slot,
    // Keep GPU-shared padding as scalars. Metal vector3 types have 16-byte
    // alignment, which does not match a packed host [3]u32 tail.
    reserved: [3]u32 = .{ 0, 0, 0 },
};

pub const Font = struct {
    metrics: FontMetrics = .{},
    glyphs: [glyph_table_len]GlyphMetric = [_]GlyphMetric{.{}} ** glyph_table_len,
    resolved_name: [max_resolved_font_name_len + 1]u8 = [_]u8{0} ** (max_resolved_font_name_len + 1),
    resolved_name_len: usize = 0,

    pub fn glyphForByte(font: *const Font, byte: u8) Error!GlyphMetric {
        if (byte >= glyph_table_len) return Error.UnsupportedCodepoint;
        const metric = font.glyphs[byte];
        if (!metric.present()) return Error.MissingGlyph;
        return metric;
    }

    pub fn resolvedName(font: *const Font) []const u8 {
        return font.resolved_name[0..font.resolved_name_len];
    }

    pub fn lineHeight(font: *const Font) f32 {
        return font.metrics.line_height;
    }
};

pub const PushResult = extern struct {
    advance: f32 = 0.0,
    glyph_count: u32 = 0,
};

pub const TextRun = struct {
    bytes: []const u8,
    color: style.Color,
    font_slot: u32 = default_font_slot,
};

pub const MeasureResult = extern struct {
    advance: f32 = 0.0,
    width: f32 = 0.0,
    height: f32 = 0.0,
    glyph_count: u32 = 0,
};

pub const TextMetrics = extern struct {
    line_height: f32 = 0.0,
    ascent: f32 = 0.0,
    descent: f32 = 0.0,
    advance_width: f32 = 0.0,
    baseline_offset: f32 = 0.0,
};

pub const RowTextPlacement = extern struct {
    origin_y: f32 = 0.0,
    baseline_y: f32 = 0.0,
};

pub fn textMetrics(font: *const Font) Error!TextMetrics {
    const advance_metric = try font.glyphForByte('M');
    return .{
        .line_height = font.metrics.line_height,
        .ascent = font.metrics.ascent,
        .descent = font.metrics.descent,
        .advance_width = advance_metric.advance,
        .baseline_offset = font.metrics.ascent,
    };
}

pub fn placeTextInRow(metrics: TextMetrics, row_y: f32, row_height: f32) RowTextPlacement {
    const extra = @max(0.0, row_height - metrics.line_height);
    const origin_y = row_y + extra * 0.5;
    return .{
        .origin_y = origin_y,
        .baseline_y = origin_y + metrics.baseline_offset,
    };
}

pub fn logicalGlyphWidth(font: *const Font, metric: GlyphMetric) f32 {
    const scale = @max(font.metrics.scale, 1.0);
    return @as(f32, @floatFromInt(metric.atlas_width)) / scale;
}

pub fn logicalGlyphHeight(font: *const Font, metric: GlyphMetric) f32 {
    const scale = @max(font.metrics.scale, 1.0);
    return @as(f32, @floatFromInt(metric.atlas_height)) / scale;
}

pub const FontSet = struct {
    fonts: []const Font = &.{},
    fallback: ?*const Font = null,

    pub fn get(set: FontSet, slot: u32) Error!*const Font {
        const index: usize = @intCast(slot);
        if (index < set.fonts.len) return &set.fonts[index];
        if (slot == default_font_slot) {
            if (set.fallback) |font| return font;
        }
        return Error.InvalidFontSlot;
    }
};

pub fn measureAscii(font: *const Font, bytes: []const u8) Error!MeasureResult {
    var cursor: f32 = 0.0;
    var glyph_count: u32 = 0;
    var visual_right: f32 = 0.0;

    for (bytes) |byte| {
        if (byte == '\n' or byte == '\r' or byte == '\t') return Error.UnsupportedCodepoint;

        const metric = try font.glyphForByte(byte);
        if (metric.visible()) {
            const right = cursor + metric.offset_x + logicalGlyphWidth(font, metric);
            visual_right = @max(visual_right, right);
            glyph_count += 1;
        }
        cursor += metric.advance;
    }

    return .{
        .advance = cursor,
        .width = @max(cursor, visual_right),
        .height = font.lineHeight(),
        .glyph_count = glyph_count,
    };
}

pub fn measureAsciiRunsWithFontSet(font_set: FontSet, runs: []const TextRun) Error!MeasureResult {
    var cursor: f32 = 0.0;
    var glyph_count: u32 = 0;
    var max_height: f32 = 0.0;
    var visual_right: f32 = 0.0;

    for (runs) |run| {
        const font = try font_set.get(run.font_slot);
        max_height = @max(max_height, font.lineHeight());
        for (run.bytes) |byte| {
            if (byte == '\n' or byte == '\r' or byte == '\t') return Error.UnsupportedCodepoint;

            const metric = try font.glyphForByte(byte);
            if (metric.visible()) {
                const right = cursor + metric.offset_x + logicalGlyphWidth(font, metric);
                visual_right = @max(visual_right, right);
                glyph_count += 1;
            }
            cursor += metric.advance;
        }
    }

    return .{
        .advance = cursor,
        .width = @max(cursor, visual_right),
        .height = max_height,
        .glyph_count = glyph_count,
    };
}

pub fn pushAscii(
    font: *const Font,
    out: []GlyphInstance,
    origin: layout.Point,
    bytes: []const u8,
    color: style.Color,
) Error!PushResult {
    const runs = [_]TextRun{.{ .bytes = bytes, .color = color }};
    return pushAsciiRuns(font, out, origin, runs[0..]);
}

pub fn pushAsciiRuns(
    font: *const Font,
    out: []GlyphInstance,
    origin: layout.Point,
    runs: []const TextRun,
) Error!PushResult {
    return pushAsciiRunsWithFontSet(.{ .fallback = font }, out, origin, runs);
}

pub fn pushAsciiRunsWithFontSet(
    font_set: FontSet,
    out: []GlyphInstance,
    origin: layout.Point,
    runs: []const TextRun,
) Error!PushResult {
    var cursor = origin.x;
    var count: usize = 0;

    for (runs) |run| {
        const font = try font_set.get(run.font_slot);
        for (run.bytes) |byte| {
            if (byte == '\n' or byte == '\r' or byte == '\t') return Error.UnsupportedCodepoint;

            const metric = try font.glyphForByte(byte);
            if (metric.visible()) {
                if (count >= out.len) return Error.GlyphCapacityExceeded;
                out[count] = .{
                    .rect = .{
                        .x = cursor + metric.offset_x,
                        .y = origin.y + metric.offset_y,
                        .width = logicalGlyphWidth(font, metric),
                        .height = logicalGlyphHeight(font, metric),
                    },
                    .atlas_rect = .{
                        .x = @as(f32, @floatFromInt(metric.atlas_x)) / @as(f32, @floatFromInt(font.metrics.atlas_width)),
                        .y = @as(f32, @floatFromInt(metric.atlas_y)) / @as(f32, @floatFromInt(font.metrics.atlas_height)),
                        .width = @as(f32, @floatFromInt(metric.atlas_width)) / @as(f32, @floatFromInt(font.metrics.atlas_width)),
                        .height = @as(f32, @floatFromInt(metric.atlas_height)) / @as(f32, @floatFromInt(font.metrics.atlas_height)),
                    },
                    .color = run.color,
                    .font_slot = run.font_slot,
                };
                count += 1;
            }
            cursor += metric.advance;
        }
    }

    return .{
        .advance = cursor - origin.x,
        .glyph_count = @intCast(count),
    };
}

comptime {
    std.debug.assert(@sizeOf(FontMetrics) == 32);
    std.debug.assert(@sizeOf(GlyphMetric) == 40);
    std.debug.assert(@sizeOf(FontVariation) == 8);
    std.debug.assert(@sizeOf(AtlasRect) == 16);
    std.debug.assert(@sizeOf(GlyphInstance) == 64);
    std.debug.assert(@sizeOf(MeasureResult) == 16);
    std.debug.assert(@sizeOf(TextMetrics) == 20);
    std.debug.assert(@sizeOf(RowTextPlacement) == 8);
}

test "font options keep font choice at the app boundary" {
    try std.testing.expect((FontOptions{}).valid());
    try std.testing.expect((FontOptions{ .family = "JetBrainsMonoNF-Regular", .size = 13.0 }).valid());
    try std.testing.expect((FontOptions{
        .family = "Lilex",
        .size = 14.0,
        .variations = &.{.{ .tag = axis("wght"), .value = 500.0 }},
    }).valid());
    try std.testing.expect(!(FontOptions{ .family = "", .size = 13.0 }).valid());
    try std.testing.expect(!(FontOptions{ .family = "Menlo", .size = 0.0 }).valid());
    try std.testing.expect(!(FontOptions{
        .family = "Menlo",
        .size = 13.0,
        .variations = &.{.{ .tag = 0, .value = 400.0 }},
    }).valid());
    try std.testing.expect(!(FontOptions{
        .family = "Menlo",
        .size = 13.0,
        .variations = &.{.{ .tag = axis("wght"), .value = std.math.nan(f32) }},
    }).valid());
    try std.testing.expect(!(FontOptions{
        .family = "Menlo",
        .size = 13.0,
        .variations = &.{
            .{ .tag = axis("wght"), .value = 400.0 },
            .{ .tag = axis("wght"), .value = 500.0 },
        },
    }).valid());
}

test "font variation axis tags use OpenType byte order" {
    try std.testing.expectEqual(@as(u32, 0x77676874), axis("wght"));
    try std.testing.expectEqual(@as(u32, 0x736c6e74), axis("slnt"));
}

test "ascii text emits visible glyph instances and advances over spaces" {
    var font: Font = .{};
    font.metrics = .{
        .size = 14.0,
        .scale = 1.0,
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

test "glyph scene rect dimensions are logical while atlas dimensions are physical" {
    var font: Font = .{};
    font.metrics = .{
        .scale = 2.0,
        .atlas_width = atlas_width,
        .atlas_height = atlas_height,
    };
    font.glyphs['A'] = .{
        .codepoint = 'A',
        .atlas_width = 14,
        .atlas_height = 18,
        .offset_x = 1.5,
        .offset_y = 2.5,
        .advance = 8.0,
        .flags = glyph_present | glyph_visible,
    };

    var glyphs: [1]GlyphInstance = undefined;
    const result = try pushAscii(&font, glyphs[0..], layout.Point.init(10.0, 20.0), "A", style.Color.rgb(1.0, 1.0, 1.0));

    try std.testing.expectEqual(@as(u32, 1), result.glyph_count);
    try std.testing.expectEqual(@as(f32, 8.0), result.advance);
    try std.testing.expectEqual(layout.Rect.init(11.5, 22.5, 7.0, 9.0), glyphs[0].rect);
}

test "ascii text runs preserve one advancing cursor and per glyph colors" {
    var font: Font = .{};
    font.metrics = .{
        .atlas_width = atlas_width,
        .atlas_height = atlas_height,
    };
    font.glyphs['A'] = .{
        .codepoint = 'A',
        .atlas_width = 5,
        .atlas_height = 7,
        .advance = 6.0,
        .flags = glyph_present | glyph_visible,
    };
    font.glyphs['B'] = .{
        .codepoint = 'B',
        .atlas_x = 8,
        .atlas_width = 5,
        .atlas_height = 7,
        .advance = 7.0,
        .flags = glyph_present | glyph_visible,
    };

    var glyphs: [2]GlyphInstance = undefined;
    const runs = [_]TextRun{
        .{ .bytes = "A", .color = style.Color.rgb(1.0, 0.0, 0.0) },
        .{ .bytes = "B", .color = style.Color.rgb(0.0, 1.0, 0.0) },
    };
    const result = try pushAsciiRuns(&font, glyphs[0..], layout.Point.init(3.0, 4.0), runs[0..]);

    try std.testing.expectEqual(@as(u32, 2), result.glyph_count);
    try std.testing.expectEqual(@as(f32, 13.0), result.advance);
    try std.testing.expectEqual(layout.Rect.init(3.0, 4.0, 5.0, 7.0), glyphs[0].rect);
    try std.testing.expectEqual(layout.Rect.init(9.0, 4.0, 5.0, 7.0), glyphs[1].rect);
    try std.testing.expectEqual(style.Color.rgb(1.0, 0.0, 0.0), glyphs[0].color);
    try std.testing.expectEqual(style.Color.rgb(0.0, 1.0, 0.0), glyphs[1].color);
}

test "ascii text measures advance without emitting glyphs" {
    var font: Font = .{};
    font.metrics = .{
        .line_height = 16.0,
    };
    font.glyphs['A'] = .{
        .codepoint = 'A',
        .atlas_width = 7,
        .atlas_height = 9,
        .offset_x = 1.0,
        .advance = 8.0,
        .flags = glyph_present | glyph_visible,
    };
    font.glyphs[' '] = .{
        .codepoint = ' ',
        .advance = 4.0,
        .flags = glyph_present,
    };

    const measured = try measureAscii(&font, "A A ");

    try std.testing.expectEqual(@as(f32, 24.0), measured.advance);
    try std.testing.expectEqual(@as(f32, 24.0), measured.width);
    try std.testing.expectEqual(@as(f32, 16.0), measured.height);
    try std.testing.expectEqual(@as(u32, 2), measured.glyph_count);
}

test "text metrics expose editor line scalars" {
    var font: Font = .{};
    font.metrics = .{
        .ascent = 11.0,
        .descent = 4.0,
        .leading = 1.0,
        .line_height = 16.0,
    };
    font.glyphs['M'] = .{
        .codepoint = 'M',
        .advance = 8.0,
        .flags = glyph_present | glyph_visible,
    };

    const metrics = try textMetrics(&font);

    try std.testing.expectEqual(@as(f32, 16.0), metrics.line_height);
    try std.testing.expectEqual(@as(f32, 11.0), metrics.ascent);
    try std.testing.expectEqual(@as(f32, 4.0), metrics.descent);
    try std.testing.expectEqual(@as(f32, 8.0), metrics.advance_width);
    try std.testing.expectEqual(@as(f32, 11.0), metrics.baseline_offset);
}

test "text metrics place text inside compact rows in logical units" {
    const metrics = TextMetrics{
        .line_height = 18.0,
        .ascent = 13.0,
        .descent = 5.0,
        .advance_width = 8.0,
        .baseline_offset = 13.0,
    };

    const placement = placeTextInRow(metrics, 40.0, 28.0);

    try std.testing.expectEqual(@as(f32, 45.0), placement.origin_y);
    try std.testing.expectEqual(@as(f32, 58.0), placement.baseline_y);
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
    try std.testing.expectError(Error.MissingGlyph, measureAscii(&font, "B"));
    try std.testing.expectError(Error.UnsupportedCodepoint, measureAscii(&font, "\t"));
}
