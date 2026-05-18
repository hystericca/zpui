pub const core = @import("core.zig");
pub const metal = @import("zmtl4");
pub const platform = struct {
    pub const macos = @import("platform/macos.zig");
};
pub const surface = @import("surface.zig");

pub const frame = core.frame;
pub const mask = core.mask;
pub const scene = core.scene;
pub const text = core.text;
pub const ui = core.ui;
pub const PlatformError = platform.macos.Error;
pub const FrameData = core.FrameData;
pub const Font = core.Font;
pub const FontHandle = core.FontHandle;
pub const FontInfo = core.FontInfo;
pub const FontLoadOptions = core.FontLoadOptions;
pub const FontVariation = core.FontVariation;
pub const Draw = core.Draw;
pub const DrawOptions = core.DrawOptions;
pub const Frame = core.Frame;
pub const FrameStorage = core.FrameStorage;
pub const MaskAtlasRect = core.MaskAtlasRect;
pub const MaskAtlasStorage = core.MaskAtlasStorage;
pub const MaskError = core.MaskError;
pub const Scene = core.Scene;
pub const SceneBuilder = core.SceneBuilder;
pub const SceneStorage = core.SceneStorage;
pub const TextMetrics = core.TextMetrics;
pub const TextLine = core.TextLine;
pub const LineCache = core.LineCache;
pub const LineCacheKey = core.LineCacheKey;
pub const LineCacheStats = core.LineCacheStats;
pub const LineCacheType = core.LineCacheType;
pub const TextLineStorage = core.TextLineStorage;
pub const RowTextPlacement = core.RowTextPlacement;
pub const DrawContext = platform.macos.DrawContext;
pub const DrawError = platform.macos.DrawError;
pub const DrawFn = platform.macos.DrawFn;
pub const FrameOptions = platform.macos.FrameOptions;
pub const WindowAppearance = platform.macos.WindowAppearance;
pub const WindowBackground = platform.macos.WindowBackground;
pub const WindowChrome = platform.macos.WindowChrome;
pub const WindowOptions = platform.macos.WindowOptions;
pub const WindowTitlebarSeparatorStyle = platform.macos.WindowTitlebarSeparatorStyle;
pub const WindowToolbarStyle = platform.macos.WindowToolbarStyle;
pub const initWindow = platform.macos.initWindow;
pub const fontAxis = core.fontAxis;
pub const lineCacheKey = core.lineCacheKey;

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
