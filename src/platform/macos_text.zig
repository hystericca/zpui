const text = @import("../text.zig");
const std = @import("std");

pub const Error = error{
    FontAtlasCreationFailed,
    FontUnavailable,
    FontVariationUnavailable,
    FontRegistrationFailed,
    InvalidFontData,
    FontCapacityExceeded,
    InvalidFontHandle,
    InvalidUtf8,
    LineGlyphCapacityExceeded,
    ShapingFailed,
    RasterTooLarge,
};

pub const PlatformFont = extern struct {
    descriptor: ?*anyopaque = null,
    postscript_name: [text.max_resolved_font_name_len + 1]u8 = @splat(0),
    postscript_name_len: u32 = 0,
    family_name: [text.max_resolved_font_name_len + 1]u8 = @splat(0),
    family_name_len: u32 = 0,
    display_name: [text.max_resolved_font_name_len + 1]u8 = @splat(0),
    display_name_len: u32 = 0,
    axes: [text.max_font_variations]text.FontAxis = @splat(.{}),
    axis_count: u32 = 0,
};

pub const RawTextRun = extern struct {
    bytes: [*]const u8,
    len: usize,
    descriptor: ?*anyopaque,
    font_index: u32,
    font_generation: u32,
    size: f32,
};

pub const RawShapedGlyph = extern struct {
    font_index: u32 = 0,
    font_generation: u32 = 0,
    glyph_id: u32 = 0,
    byte_index: u32 = 0,
    fallback_index: u32 = text.no_fallback_index,
    x: f32 = 0.0,
    y: f32 = 0.0,
    size: f32 = 0.0,
};

pub const RawLineMetrics = extern struct {
    advance: f32 = 0.0,
    ascent: f32 = 0.0,
    descent: f32 = 0.0,
    leading: f32 = 0.0,
    line_height: f32 = 0.0,
    baseline_offset: f32 = 0.0,
    bytes_len: u32 = 0,
    glyph_count: u32 = 0,
    fallback_count: u32 = 0,
};

pub const GlyphRaster = extern struct {
    width: u32 = 0,
    height: u32 = 0,
    bytes_per_row: u32 = 0,
    offset_x: f32 = 0.0,
    offset_y_from_baseline: f32 = 0.0,
    logical_width: f32 = 0.0,
    logical_height: f32 = 0.0,
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
extern fn zpui_macos_load_system_font_descriptor(
    name: [*:0]const u8,
    variations: ?[*]const text.FontVariation,
    variation_count: u32,
    out_font: *PlatformFont,
) c_int;
extern fn zpui_macos_load_font_file_descriptor(
    path: [*:0]const u8,
    face: ?[*:0]const u8,
    variations: ?[*]const text.FontVariation,
    variation_count: u32,
    out_font: *PlatformFont,
) c_int;
extern fn zpui_macos_load_font_bytes_descriptor(
    bytes: [*]const u8,
    len: usize,
    face: ?[*:0]const u8,
    variations: ?[*]const text.FontVariation,
    variation_count: u32,
    out_font: *PlatformFont,
) c_int;
extern fn zpui_macos_release_font_descriptor(descriptor: ?*anyopaque) void;
extern fn zpui_macos_shape_line(
    runs: [*]const RawTextRun,
    run_count: u32,
    out_glyphs: [*]RawShapedGlyph,
    glyph_capacity: u32,
    out_fallback_fonts: [*]PlatformFont,
    fallback_capacity: u32,
    out_metrics: *RawLineMetrics,
) c_int;
extern fn zpui_macos_rasterize_glyph(
    descriptor: ?*anyopaque,
    glyph_id: u32,
    font_size: f32,
    scale: f32,
    subpixel_x: f32,
    out_bytes: [*]u8,
    byte_capacity: usize,
    out_raster: *GlyphRaster,
) c_int;

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

pub fn releaseFont(font: *PlatformFont) void {
    zpui_macos_release_font_descriptor(font.descriptor);
    font.* = .{};
}

pub fn loadSystemFont(name: [:0]const u8, options: text.FontLoadOptions) Error!PlatformFont {
    if (!options.valid()) return Error.FontVariationUnavailable;
    var font: PlatformFont = .{};
    const status = zpui_macos_load_system_font_descriptor(
        name.ptr,
        if (options.variations.len == 0) null else options.variations.ptr,
        @intCast(options.variations.len),
        &font,
    );
    try fontStatus(status);
    return font;
}

pub fn loadFontFile(path: [:0]const u8, options: text.FontLoadOptions) Error!PlatformFont {
    if (!options.valid()) return Error.FontVariationUnavailable;
    var font: PlatformFont = .{};
    const status = zpui_macos_load_font_file_descriptor(
        path.ptr,
        if (options.face) |face| face.ptr else null,
        if (options.variations.len == 0) null else options.variations.ptr,
        @intCast(options.variations.len),
        &font,
    );
    try fontStatus(status);
    return font;
}

pub fn loadFontBytes(bytes: []const u8, options: text.FontLoadOptions) Error!PlatformFont {
    if (bytes.len == 0) return Error.InvalidFontData;
    if (!options.valid()) return Error.FontVariationUnavailable;
    var font: PlatformFont = .{};
    const status = zpui_macos_load_font_bytes_descriptor(
        bytes.ptr,
        bytes.len,
        if (options.face) |face| face.ptr else null,
        if (options.variations.len == 0) null else options.variations.ptr,
        @intCast(options.variations.len),
        &font,
    );
    try fontStatus(status);
    return font;
}

pub fn shapeLine(runs: []const RawTextRun, out_glyphs: []RawShapedGlyph, out_fallback_fonts: []PlatformFont) Error!RawLineMetrics {
    var metrics: RawLineMetrics = .{};
    const status = zpui_macos_shape_line(
        runs.ptr,
        @intCast(runs.len),
        out_glyphs.ptr,
        @intCast(out_glyphs.len),
        out_fallback_fonts.ptr,
        @intCast(out_fallback_fonts.len),
        &metrics,
    );
    try shapeStatus(status);
    return metrics;
}

pub fn rasterizeGlyph(
    descriptor: ?*anyopaque,
    glyph_id: u32,
    size: f32,
    scale: f32,
    subpixel_x: f32,
    out_bytes: []u8,
) Error!GlyphRaster {
    var raster: GlyphRaster = .{};
    const status = zpui_macos_rasterize_glyph(
        descriptor,
        glyph_id,
        size,
        scale,
        subpixel_x,
        out_bytes.ptr,
        out_bytes.len,
        &raster,
    );
    try rasterStatus(status);
    return raster;
}

fn fontStatus(status: c_int) Error!void {
    return switch (status) {
        0 => {},
        2 => Error.FontUnavailable,
        3 => Error.FontVariationUnavailable,
        4 => Error.InvalidFontData,
        else => Error.FontAtlasCreationFailed,
    };
}

fn shapeStatus(status: c_int) Error!void {
    return switch (status) {
        0 => {},
        2 => Error.FontUnavailable,
        5 => Error.InvalidUtf8,
        6 => Error.InvalidFontHandle,
        7 => Error.LineGlyphCapacityExceeded,
        9 => Error.FontCapacityExceeded,
        else => Error.ShapingFailed,
    };
}

fn rasterStatus(status: c_int) Error!void {
    return switch (status) {
        0 => {},
        6 => Error.InvalidFontHandle,
        8 => Error.RasterTooLarge,
        else => Error.ShapingFailed,
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
    try std.testing.expectError(Error.InvalidFontData, loadFontBytes("not a font", .{}));
    try std.testing.expectError(Error.FontVariationUnavailable, loadSystemFont("Menlo", .{
        .variations = &.{.{ .tag = text.axis("ZP0X"), .value = 1.0 }},
    }));
}

test "macos text loads descriptors from system file and bytes" {
    var system_font = try loadSystemFont("Menlo", .{});
    defer releaseFont(&system_font);
    try std.testing.expect(system_font.postscript_name_len > 0);

    var file_font = try loadFontFile("/System/Library/Fonts/Menlo.ttc", .{});
    defer releaseFont(&file_font);
    try std.testing.expect(file_font.postscript_name_len > 0);

    const font_bytes = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "/System/Library/Fonts/Menlo.ttc", std.testing.allocator, .limited(32 * 1024 * 1024));
    defer std.testing.allocator.free(font_bytes);
    var bytes_font = try loadFontBytes(font_bytes, .{});
    defer releaseFont(&bytes_font);
    try std.testing.expect(bytes_font.postscript_name_len > 0);
}

test "macos text shapes utf8 lines and rasterizes glyph coverage" {
    var font = try loadSystemFont("Menlo", .{});
    defer releaseFont(&font);

    const sample = "caf\u{e9} ffi";
    const runs = [_]RawTextRun{.{
        .bytes = sample.ptr,
        .len = sample.len,
        .descriptor = font.descriptor,
        .font_index = 0,
        .font_generation = 1,
        .size = 15.0,
    }};
    var glyphs: [64]RawShapedGlyph = undefined;
    var fallback_fonts: [text.max_fallback_fonts]PlatformFont = @splat(.{});
    const metrics = try shapeLine(runs[0..], glyphs[0..], fallback_fonts[0..]);
    defer {
        for (fallback_fonts[0..metrics.fallback_count]) |*fallback| releaseFont(fallback);
    }

    try std.testing.expect(metrics.glyph_count > 0);
    try std.testing.expect(metrics.line_height > 0.0);
    try std.testing.expect(metrics.line_height < 28.0);
    try std.testing.expectEqual(@as(u32, sample.len), metrics.bytes_len);
    try std.testing.expect(glyphs[0].byte_index == 0);

    var scratch: [text.max_raster_byte_len]u8 = undefined;
    const raster = try rasterizeGlyph(font.descriptor, glyphs[0].glyph_id, 15.0, 2.0, 0.0, scratch[0..]);
    try std.testing.expect(raster.width > 0);
    try std.testing.expect(raster.height > 0);
    try std.testing.expect(raster.logical_height < 28.0);

    const invalid = [_]u8{0xff};
    const bad_runs = [_]RawTextRun{.{
        .bytes = invalid[0..].ptr,
        .len = invalid.len,
        .descriptor = font.descriptor,
        .font_index = 0,
        .font_generation = 1,
        .size = 15.0,
    }};
    try std.testing.expectError(Error.InvalidUtf8, shapeLine(bad_runs[0..], glyphs[0..], fallback_fonts[0..]));
}

test "macos text reports CoreText fallback font descriptors" {
    var font = try loadSystemFont("Menlo", .{});
    defer releaseFont(&font);

    const sample = "\u{6f22}\u{5b57}";
    const runs = [_]RawTextRun{.{
        .bytes = sample.ptr,
        .len = sample.len,
        .descriptor = font.descriptor,
        .font_index = 0,
        .font_generation = 1,
        .size = 15.0,
    }};
    var glyphs: [64]RawShapedGlyph = undefined;
    var fallback_fonts: [text.max_fallback_fonts]PlatformFont = @splat(.{});
    const metrics = try shapeLine(runs[0..], glyphs[0..], fallback_fonts[0..]);
    defer {
        for (fallback_fonts[0..metrics.fallback_count]) |*fallback| releaseFont(fallback);
    }

    try std.testing.expect(metrics.glyph_count > 0);
    try std.testing.expect(metrics.fallback_count > 0);
    var saw_fallback = false;
    for (glyphs[0..metrics.glyph_count]) |glyph| {
        if (glyph.fallback_index != text.no_fallback_index) {
            try std.testing.expect(glyph.fallback_index < metrics.fallback_count);
            saw_fallback = true;
        }
    }
    try std.testing.expect(saw_fallback);
    try std.testing.expect(fallback_fonts[0].descriptor != null);
    try std.testing.expect(fallback_fonts[0].postscript_name_len > 0);
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
