const std = @import("std");

const defs = @import("defs.zig");

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
    family: [:0]const u8 = defs.default_font_family,
    size: f32 = defs.default_font_size,
    variations: []const FontVariation = &.{},

    pub fn valid(options: FontOptions) bool {
        if (options.family.len == 0 or options.family.len > defs.max_font_family_len) return false;
        if (options.size <= 0.0 or !std.math.isFinite(options.size)) return false;
        if (options.variations.len > defs.max_font_variations) return false;
        return variationsValid(options.variations);
    }
};

pub const FontLoadOptions = struct {
    face: ?[:0]const u8 = null,
    variations: []const FontVariation = &.{},

    pub fn valid(options: FontLoadOptions) bool {
        if (options.face) |face| {
            if (face.len == 0 or face.len > defs.max_resolved_font_name_len) return false;
        }
        if (options.variations.len > defs.max_font_variations) return false;
        return variationsValid(options.variations);
    }
};

pub const FontHandle = extern struct {
    index: u32 = std.math.maxInt(u32),
    generation: u32 = 0,

    pub fn valid(handle: FontHandle) bool {
        return handle.index < defs.max_fonts and handle.generation != 0;
    }
};

pub const FontAxis = extern struct {
    tag: u32 = 0,
    min: f32 = 0.0,
    max: f32 = 0.0,
    default_value: f32 = 0.0,
};

pub const FontInfo = struct {
    postscript_name: []const u8 = &.{},
    family_name: []const u8 = &.{},
    display_name: []const u8 = &.{},
    axes: []const FontAxis = &.{},
};

fn variationsValid(variations: []const FontVariation) bool {
    for (variations, 0..) |variation, index| {
        if (!variation.valid()) return false;
        for (variations[0..index]) |previous| {
            if (previous.tag == variation.tag) return false;
        }
    }
    return true;
}
