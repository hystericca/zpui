const text = @import("../text.zig");
const std = @import("std");

pub const Error = error{
    FontAtlasCreationFailed,
    FontUnavailable,
    FontVariationUnavailable,
    FontRegistrationFailed,
    InvalidFontData,
};

extern fn zpui_macos_build_ascii_font_atlas(
    font_name: [*:0]const u8,
    font_size: f32,
    variations: ?[*]const text.FontVariation,
    variation_count: u32,
    scale: f32,
    atlas_bytes: [*]u8,
    atlas_width: u32,
    atlas_height: u32,
    out_metrics: *text.FontMetrics,
    out_glyphs: [*]text.GlyphMetric,
    glyph_count: u32,
    resolved_name: [*]u8,
    resolved_name_capacity: u32,
    resolved_name_len: *u32,
) c_int;

extern fn zpui_macos_register_font_file(path: [*:0]const u8) c_int;
extern fn zpui_macos_register_font_bytes(bytes: [*]const u8, len: usize) c_int;

pub fn registerFontFile(path: [:0]const u8) Error!void {
    return switch (zpui_macos_register_font_file(path.ptr)) {
        0 => {},
        2 => Error.InvalidFontData,
        else => Error.FontRegistrationFailed,
    };
}

pub fn registerFontBytes(bytes: []const u8) Error!void {
    if (bytes.len == 0) return Error.InvalidFontData;
    return switch (zpui_macos_register_font_bytes(bytes.ptr, bytes.len)) {
        0 => {},
        2 => Error.InvalidFontData,
        else => Error.FontRegistrationFailed,
    };
}

pub fn buildAsciiAtlas(
    font: *text.Font,
    atlas: *text.AtlasStorage,
    options: text.FontOptions,
    scale: f32,
) Error!void {
    var resolved_name_len: u32 = 0;
    const status = zpui_macos_build_ascii_font_atlas(
        options.family.ptr,
        options.size,
        if (options.variations.len == 0) null else options.variations.ptr,
        @intCast(options.variations.len),
        scale,
        atlas.bytes[0..].ptr,
        text.atlas_width,
        text.atlas_height,
        &font.metrics,
        font.glyphs[0..].ptr,
        text.glyph_table_len,
        font.resolved_name[0..].ptr,
        @intCast(font.resolved_name.len),
        &resolved_name_len,
    );
    switch (status) {
        0 => {
            font.resolved_name_len = @min(@as(usize, @intCast(resolved_name_len)), text.max_resolved_font_name_len);
        },
        2 => return Error.FontUnavailable,
        3 => return Error.FontVariationUnavailable,
        else => return Error.FontAtlasCreationFailed,
    }
}

test "macos text builds a visible ascii atlas" {
    var font: text.Font = .{};
    var atlas: text.AtlasStorage = .{};

    try buildAsciiAtlas(&font, &atlas, .{ .family = "Menlo", .size = 13.0 }, 1.0);

    const glyph = font.glyphs['A'];
    try std.testing.expect(glyph.present());
    try std.testing.expect(glyph.visible());
    try std.testing.expect(glyph.advance > 0.0);
    try std.testing.expect(std.mem.startsWith(u8, font.resolvedName(), "Menlo"));

    var nonzero: usize = 0;
    for (atlas.bytes) |byte| {
        if (byte != 0) nonzero += 1;
    }
    try std.testing.expect(nonzero > 0);
}

test "macos text glyph rects point at their atlas coverage" {
    var font: text.Font = .{};
    var atlas: text.AtlasStorage = .{};

    try buildAsciiAtlas(&font, &atlas, .{ .family = "Menlo", .size = 13.0 }, 1.0);

    try expectGlyphRectHasCoverage(&font, &atlas, 'A');
    try expectGlyphRectHasCoverage(&font, &atlas, 'x');
    try expectGlyphRectHasCoverage(&font, &atlas, 'y');
}

test "macos text exposes logical metrics independent of backing scale" {
    var scale_one_font: text.Font = .{};
    var scale_one_atlas: text.AtlasStorage = .{};
    var retina_font: text.Font = .{};
    var retina_atlas: text.AtlasStorage = .{};

    try buildAsciiAtlas(&scale_one_font, &scale_one_atlas, .{ .family = "Menlo", .size = 15.0 }, 1.0);
    try buildAsciiAtlas(&retina_font, &retina_atlas, .{ .family = "Menlo", .size = 15.0 }, 2.0);

    const scale_one_metrics = try text.textMetrics(&scale_one_font);
    const retina_metrics = try text.textMetrics(&retina_font);
    const row_placement = text.placeTextInRow(retina_metrics, 0.0, 28.0);

    try std.testing.expectApproxEqAbs(scale_one_metrics.line_height, retina_metrics.line_height, 1.0);
    try std.testing.expectApproxEqAbs(scale_one_metrics.advance_width, retina_metrics.advance_width, 1.0);
    try std.testing.expect(retina_metrics.line_height < 28.0);
    try std.testing.expect(row_placement.origin_y >= 0.0);
    try std.testing.expect(row_placement.baseline_y < 28.0);
}

test "macos text fails loudly for unavailable fonts" {
    var font: text.Font = .{};
    var atlas: text.AtlasStorage = .{};

    try std.testing.expectError(Error.FontUnavailable, buildAsciiAtlas(
        &font,
        &atlas,
        .{ .family = "ZPUI Definitely Missing Font", .size = 15.0 },
        2.0,
    ));
}

test "macos text fails loudly for unavailable variation axes" {
    var font: text.Font = .{};
    var atlas: text.AtlasStorage = .{};

    try std.testing.expectError(Error.FontVariationUnavailable, buildAsciiAtlas(
        &font,
        &atlas,
        .{
            .family = "Menlo",
            .size = 15.0,
            .variations = &.{.{ .tag = text.axis("ZP0X"), .value = 1.0 }},
        },
        2.0,
    ));
}

test "macos text rejects invalid font registration data" {
    try std.testing.expectError(Error.InvalidFontData, registerFontBytes(&.{}));
    try std.testing.expectError(Error.InvalidFontData, registerFontBytes("not a font"));
    try std.testing.expectError(Error.InvalidFontData, registerFontFile("/zpui/no/such/font.ttf"));
}

fn expectGlyphRectHasCoverage(font: *const text.Font, atlas: *const text.AtlasStorage, byte: u8) !void {
    const glyph = try font.glyphForByte(byte);
    try std.testing.expect(glyph.visible());

    var nonzero: usize = 0;
    var min_x: u32 = text.atlas_width;
    var min_y: u32 = text.atlas_height;
    var max_x: u32 = 0;
    var max_y: u32 = 0;
    const y_end = glyph.atlas_y + glyph.atlas_height;
    const x_end = glyph.atlas_x + glyph.atlas_width;
    var y = glyph.atlas_y;
    while (y < y_end) : (y += 1) {
        var x = glyph.atlas_x;
        while (x < x_end) : (x += 1) {
            const index: usize = @as(usize, y) * text.atlas_width + x;
            if (atlas.bytes[index] != 0) {
                nonzero += 1;
                min_x = @min(min_x, x);
                min_y = @min(min_y, y);
                max_x = @max(max_x, x);
                max_y = @max(max_y, y);
            }
        }
    }
    try std.testing.expect(nonzero > 0);
    try std.testing.expect(max_x >= min_x);
    try std.testing.expect(max_y >= min_y);
    try std.testing.expect(max_y - min_y + 1 >= glyph.atlas_height / 2);
}
