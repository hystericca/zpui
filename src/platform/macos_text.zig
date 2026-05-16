const text = @import("../text.zig");
const std = @import("std");

pub const Error = error{
    FontAtlasCreationFailed,
};

extern fn zpui_macos_build_ascii_font_atlas(
    font_name: [*:0]const u8,
    font_size: f32,
    scale: f32,
    atlas_bytes: [*]u8,
    atlas_width: u32,
    atlas_height: u32,
    out_metrics: *text.FontMetrics,
    out_glyphs: [*]text.GlyphMetric,
    glyph_count: u32,
) c_int;

pub fn buildAsciiAtlas(
    font: *text.Font,
    atlas: *text.AtlasStorage,
    font_name: [*:0]const u8,
    font_size: f32,
    scale: f32,
) Error!void {
    const status = zpui_macos_build_ascii_font_atlas(
        font_name,
        font_size,
        scale,
        atlas.bytes[0..].ptr,
        text.atlas_width,
        text.atlas_height,
        &font.metrics,
        font.glyphs[0..].ptr,
        text.glyph_table_len,
    );
    if (status != 0) return Error.FontAtlasCreationFailed;
}

test "macos text builds a visible ascii atlas" {
    var font: text.Font = .{};
    var atlas: text.AtlasStorage = .{};

    try buildAsciiAtlas(&font, &atlas, "Menlo", 13.0, 1.0);

    const glyph = font.glyphs['A'];
    try std.testing.expect(glyph.present());
    try std.testing.expect(glyph.visible());
    try std.testing.expect(glyph.advance > 0.0);

    var nonzero: usize = 0;
    for (atlas.bytes) |byte| {
        if (byte != 0) nonzero += 1;
    }
    try std.testing.expect(nonzero > 0);
}
