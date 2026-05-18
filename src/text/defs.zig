const std = @import("std");

pub const max_frame_glyphs = 16384;
pub const atlas_width = 1024;
pub const atlas_height = 512;
pub const atlas_byte_len = atlas_width * atlas_height;
pub const glyph_atlas_width = 2048;
pub const glyph_atlas_height = 2048;
pub const glyph_atlas_byte_len = glyph_atlas_width * glyph_atlas_height;
pub const glyph_table_len = 128;
pub const max_font_slots = 4;
pub const max_fonts = 64;
pub const max_fallback_fonts = 16;
pub const max_atlas_pages = 4;
pub const max_cached_glyphs = 8192;
pub const max_dirty_rects = 256;
pub const max_line_glyphs = 4096;
pub const max_line_runs = 256;
pub const max_line_cache_entries = 128;
pub const max_line_cache_glyphs = max_frame_glyphs;
pub const max_raster_width = 256;
pub const max_raster_height = 256;
pub const max_raster_byte_len = max_raster_width * max_raster_height;
pub const default_font_slot: u32 = 0;
pub const no_fallback_index: u32 = std.math.maxInt(u32);
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
    InvalidFontHandle,
    InvalidFontOptions,
    FontCapacityExceeded,
    GlyphCapacityExceeded,
    LineGlyphCapacityExceeded,
    CachedGlyphCapacityExceeded,
    MissingGlyph,
    UnsupportedCodepoint,
    InvalidUtf8,
    InvalidAtlas,
    AtlasFull,
    LineCacheCapacityExceeded,
    RasterTooLarge,
};
