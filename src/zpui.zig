const core = @import("core.zig");
const macos = @import("platform/macos.zig");

pub const mask = core.mask;
pub const scene = core.scene;
pub const text = core.text;
pub const ui = core.ui;

pub const PlatformError = macos.Error;
pub const Limits = core.Limits;
pub const default_limits = core.default_limits;
pub const FontHandle = core.FontHandle;
pub const FontInfo = core.FontInfo;
pub const FontLoadOptions = core.FontLoadOptions;
pub const FontVariation = core.FontVariation;
pub const Draw = core.Draw;
pub const DrawOptions = core.DrawOptions;
pub const Frame = core.Frame;
pub const FrameStorage = core.FrameStorage;
pub const DefaultFrameStorage = core.DefaultFrameStorage;
pub const TextMetrics = core.TextMetrics;
pub const ShapedLine = core.ShapedLine;
pub const ShapedLineStorage = core.ShapedLineStorage;
pub const PreparedLine = core.PreparedLine;
pub const LineCache = core.LineCache;
pub const LineCacheKey = core.LineCacheKey;
pub const LineCacheStats = core.LineCacheStats;
pub const LineCacheType = core.LineCacheType;
pub const PreparedLineStorage = core.PreparedLineStorage;
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

test "app root has no renderer shortcuts" {
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
    try std.testing.expect(!@hasDecl(@This(), "TextLine"));
    try std.testing.expect(!@hasDecl(@This(), "TextLineStorage"));
    try std.testing.expect(!@hasDecl(text, "TextLine"));
    try std.testing.expect(!@hasDecl(text, "TextLineStorage"));
    try std.testing.expect(@hasDecl(@This(), "ShapedLine"));
    try std.testing.expect(@hasDecl(@This(), "PreparedLine"));
    try std.testing.expect(@hasDecl(Draw, "fill"));
    try std.testing.expect(@hasDecl(Draw, "rect"));
    try std.testing.expect(@hasDecl(Draw, "textLine"));
    try std.testing.expect(@hasDecl(Draw, "mask"));
    try std.testing.expect(@hasDecl(Draw, "hit"));
    try std.testing.expect(!@hasDecl(Frame, "pushFill"));
    try std.testing.expect(!@hasDecl(Frame, "pushStyledRect"));
    try std.testing.expect(!@hasDecl(Frame, "pushTextLine"));
    try std.testing.expect(!@hasDecl(Frame, "pushMask"));

    const limits: Limits = .{
        .quads = 4,
        .batches = 4,
        .clips = 4,
        .glyphs = 4,
        .text_batches = 4,
        .masks = 4,
        .mask_batches = 4,
    };
    var custom_storage: FrameStorage(limits) = .{};
    const Storage = DefaultFrameStorage;
    _ = &custom_storage;
    try std.testing.expect(@sizeOf(Storage) > @sizeOf(@TypeOf(custom_storage)));

    const begin: Frame.Begin = .{ .frame_size_points = .{ 1.0, 1.0 } };
    try std.testing.expectEqual([2]f32{ 1.0, 1.0 }, begin.frame_size_points);
}
