const core = @import("core.zig");
const macos = @import("platform/macos.zig");

pub const mask = core.mask;
pub const scene = core.scene;
pub const text = core.text;
pub const ui = core.ui;

pub const PlatformError = macos.Error;
pub const FontHandle = core.FontHandle;
pub const FontInfo = core.FontInfo;
pub const FontLoadOptions = core.FontLoadOptions;
pub const FontVariation = core.FontVariation;
pub const Draw = core.Draw;
pub const DrawOptions = core.DrawOptions;
pub const Frame = core.Frame;
pub const FrameStorage = core.FrameStorage;
pub const TextMetrics = core.TextMetrics;
pub const TextLine = core.TextLine;
pub const LineCache = core.LineCache;
pub const LineCacheKey = core.LineCacheKey;
pub const LineCacheStats = core.LineCacheStats;
pub const LineCacheType = core.LineCacheType;
pub const TextLineStorage = core.TextLineStorage;
pub const RowTextPlacement = core.RowTextPlacement;

pub const DrawContext = macos.DrawContext;
pub const DrawError = macos.DrawError;
pub const DrawFn = macos.DrawFn;
pub const FrameOptions = macos.FrameOptions;
pub const WindowAppearance = macos.WindowAppearance;
pub const WindowBackground = macos.WindowBackground;
pub const WindowChrome = macos.WindowChrome;
pub const WindowOptions = macos.WindowOptions;
pub const WindowTitlebarSeparatorStyle = macos.WindowTitlebarSeparatorStyle;
pub const WindowToolbarStyle = macos.WindowToolbarStyle;
pub const initWindow = macos.initWindow;

pub const fontAxis = core.fontAxis;
pub const lineCacheKey = core.lineCacheKey;

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}

test "app root only exposes curated public surface" {
    const std = @import("std");
    try std.testing.expect(@hasDecl(@This(), "ui"));
    try std.testing.expect(@hasDecl(@This(), "text"));
    try std.testing.expect(@hasDecl(@This(), "scene"));
    try std.testing.expect(@hasDecl(@This(), "mask"));
    try std.testing.expect(!@hasDecl(@This(), "surface"));
    try std.testing.expect(!@hasDecl(@This(), "platform"));
    try std.testing.expect(!@hasDecl(@This(), "metal"));
    try std.testing.expect(!@hasDecl(@This(), "FrameData"));
    try std.testing.expect(!@hasDecl(@This(), "SceneBuilder"));
    try std.testing.expect(!@hasDecl(@This(), "SceneStorage"));

    const begin: Frame.Begin = .{ .frame_size_points = .{ 1.0, 1.0 } };
    try std.testing.expectEqual([2]f32{ 1.0, 1.0 }, begin.frame_size_points);
}
