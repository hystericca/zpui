const std = @import("std");

const defs = @import("defs.zig");
const font = @import("font.zig");
const layout = @import("../ui/layout.zig");
const style = @import("../ui/style.zig");

pub const glyph_present: u32 = 1 << 0;
pub const glyph_visible: u32 = 1 << 1;

pub const AtlasStorage = struct {
    bytes: [defs.atlas_byte_len]u8 = @splat(0),
};

pub const DirtyRect = extern struct {
    page: u32 = 0,
    x: u32 = 0,
    y: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
};

pub const PackedGlyph = extern struct {
    page: u32 = 0,
    x: u32 = 0,
    y: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
};

pub const GlyphAtlasStorage = struct {
    bytes: [defs.glyph_atlas_byte_len]u8 = @splat(0),
    next_x: u32 = 0,
    next_y: u32 = 0,
    row_height: u32 = 0,

    pub fn clear(atlas: *GlyphAtlasStorage) void {
        @memset(&atlas.bytes, 0);
        atlas.next_x = 0;
        atlas.next_y = 0;
        atlas.row_height = 0;
    }

    pub fn append(atlas: *GlyphAtlasStorage, page: u32, width: u32, height: u32, bytes: []const u8, bytes_per_row: u32) defs.Error!PackedGlyph {
        if (width == 0 or height == 0 or bytes_per_row < width) return defs.Error.InvalidAtlas;
        if (width > defs.glyph_atlas_width or height > defs.glyph_atlas_height) return defs.Error.AtlasFull;
        const required_len = @as(usize, @intCast(bytes_per_row)) * @as(usize, @intCast(height));
        if (bytes.len < required_len) return defs.Error.InvalidAtlas;

        if (atlas.next_x + width > defs.glyph_atlas_width) {
            atlas.next_x = 0;
            atlas.next_y += atlas.row_height;
            atlas.row_height = 0;
        }
        if (atlas.next_y + height > defs.glyph_atlas_height) return defs.Error.AtlasFull;

        const dst_x = atlas.next_x;
        const dst_y = atlas.next_y;
        const w: usize = @intCast(width);
        const h: usize = @intCast(height);
        const stride: usize = @intCast(bytes_per_row);
        const dst_x_usize: usize = @intCast(dst_x);
        const dst_y_usize: usize = @intCast(dst_y);
        for (0..h) |row| {
            const src_start = row * stride;
            const dst_start = (dst_y_usize + row) * defs.glyph_atlas_width + dst_x_usize;
            @memcpy(atlas.bytes[dst_start..][0..w], bytes[src_start..][0..w]);
        }

        atlas.next_x += width;
        atlas.row_height = @max(atlas.row_height, height);
        return .{
            .page = page,
            .x = dst_x,
            .y = dst_y,
            .width = width,
            .height = height,
        };
    }
};

pub const FontMetrics = extern struct {
    size: f32 = 0.0,
    scale: f32 = 1.0,
    ascent: f32 = 0.0,
    descent: f32 = 0.0,
    leading: f32 = 0.0,
    line_height: f32 = 0.0,
    atlas_width: u32 = defs.atlas_width,
    atlas_height: u32 = defs.atlas_height,
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
    atlas_page: u32 = 0,
    reserved: [3]u32 = .{ 0, 0, 0 },
};

pub const GlyphCacheKey = extern struct {
    font: font.FontHandle = .{},
    glyph_id: u32 = 0,
    size_bits: u32 = 0,
    scale_bits: u32 = 0,
    subpixel_x: u32 = 0,
};

pub const CachedGlyph = extern struct {
    key: GlyphCacheKey = .{},
    atlas_rect: AtlasRect = .{},
    atlas_page: u32 = 0,
    width: f32 = 0.0,
    height: f32 = 0.0,
    offset_x: f32 = 0.0,
    offset_y_from_baseline: f32 = 0.0,
};

pub fn glyphCacheKey(handle: font.FontHandle, glyph_id: u32, size: f32, scale: f32, subpixel_x: u32) GlyphCacheKey {
    return .{
        .font = handle,
        .glyph_id = glyph_id,
        .size_bits = @bitCast(size),
        .scale_bits = @bitCast(scale),
        .subpixel_x = subpixel_x,
    };
}

pub fn glyphCacheKeyEqual(a: GlyphCacheKey, b: GlyphCacheKey) bool {
    return a.font.index == b.font.index and
        a.font.generation == b.font.generation and
        a.glyph_id == b.glyph_id and
        a.size_bits == b.size_bits and
        a.scale_bits == b.scale_bits and
        a.subpixel_x == b.subpixel_x;
}

comptime {
    std.debug.assert(@sizeOf(FontMetrics) == 32);
    std.debug.assert(@sizeOf(GlyphMetric) == 40);
    std.debug.assert(@sizeOf(AtlasRect) == 16);
    std.debug.assert(@sizeOf(GlyphInstance) == 64);
}
