pub const frame = @import("frame.zig");
pub const mask = @import("mask.zig");
pub const scene = @import("scene.zig");
pub const text = @import("text.zig");
pub const ui = @import("ui.zig");

pub const Limits = scene.Limits;
pub const default_limits = scene.default_limits;
pub const FontHandle = text.FontHandle;
pub const FontInfo = text.FontInfo;
pub const FontLoadOptions = text.FontLoadOptions;
pub const FontVariation = text.FontVariation;
pub const Draw = frame.Draw;
pub const DrawOptions = frame.DrawOptions;
pub const Frame = frame.Frame;
pub const FrameStorage = frame.FrameStorage;
pub const DefaultFrameStorage = frame.DefaultFrameStorage;
pub const TextMetrics = text.TextMetrics;
pub const ShapedLine = text.ShapedLine;
pub const ShapedLineStorage = text.ShapedLineStorage;
pub const PreparedLine = text.PreparedLine;
pub const LineCache = text.LineCache;
pub const LineCacheKey = text.LineCacheKey;
pub const LineCacheStats = text.LineCacheStats;
pub const LineCacheType = text.LineCacheType;
pub const PreparedLineStorage = text.PreparedLineStorage;
pub const RowTextPlacement = text.RowTextPlacement;

pub fn fontAxis(comptime tag: []const u8) u32 {
    return text.axis(tag);
}

pub fn lineCacheKey(runs: []const text.TextRun) text.Error!text.LineCacheKey {
    return text.lineCacheKey(runs);
}

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}

test "core root keeps renderer internals behind modules" {
    const std = @import("std");
    try std.testing.expect(!@hasDecl(@This(), "FrameData"));
    try std.testing.expect(!@hasDecl(@This(), "Scene"));
    try std.testing.expect(!@hasDecl(@This(), "SceneBuilder"));
    try std.testing.expect(!@hasDecl(@This(), "SceneStorage"));
    try std.testing.expect(!@hasDecl(@This(), "MaskAtlasRect"));
    try std.testing.expect(!@hasDecl(@This(), "MaskAtlasStorage"));
    try std.testing.expect(!@hasDecl(@This(), "TextLine"));
    try std.testing.expect(!@hasDecl(@This(), "TextLineStorage"));
    try std.testing.expect(@hasDecl(@This(), "ShapedLine"));
    try std.testing.expect(@hasDecl(@This(), "PreparedLine"));
    try std.testing.expect(@hasDecl(@This(), "scene"));
    try std.testing.expect(@hasDecl(@This(), "mask"));
}
