pub const core = @import("core.zig");
pub const metal = @import("zmtl4");
pub const platform = struct {
    pub const macos = @import("platform/macos.zig");
};
pub const surface = @import("surface.zig");

pub const frame = core.frame;
pub const mask = core.mask;
pub const scene = core.scene;
pub const render = scene;
pub const text = core.text;
pub const ui = core.ui;
pub const PlatformError = platform.macos.Error;
pub const FrameData = core.FrameData;
pub const Font = core.Font;
pub const FontOptions = core.FontOptions;
pub const FontVariation = core.FontVariation;
pub const Frame = core.Frame;
pub const FrameStorage = core.FrameStorage;
pub const MaskAtlasRect = core.MaskAtlasRect;
pub const MaskAtlasStorage = core.MaskAtlasStorage;
pub const MaskError = core.MaskError;
pub const Scene = core.Scene;
pub const SceneBuilder = core.SceneBuilder;
pub const SceneStorage = core.SceneStorage;
pub const TextMetrics = core.TextMetrics;
pub const RowTextPlacement = core.RowTextPlacement;
pub const DrawContext = platform.macos.DrawContext;
pub const DrawError = platform.macos.DrawError;
pub const DrawFn = platform.macos.DrawFn;
pub const FrameOptions = platform.macos.FrameOptions;
pub const WindowOptions = platform.macos.WindowOptions;
pub const initWindow = platform.macos.initWindow;
pub const registerFontBytes = platform.macos.registerFontBytes;
pub const registerFontFile = platform.macos.registerFontFile;
pub const default_font_slot = core.default_font_slot;
pub const max_font_slots = core.max_font_slots;
pub const fontAxis = core.fontAxis;

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
