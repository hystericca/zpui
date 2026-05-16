pub const core = @import("core.zig");
pub const metal = @import("zmtl4");
pub const platform = struct {
    pub const macos = @import("platform/macos.zig");
};
pub const surface = @import("surface.zig");

pub const frame = core.frame;
pub const render = core.render;
pub const text = core.text;
pub const ui = core.ui;
pub const PlatformError = platform.macos.Error;
pub const FrameData = core.FrameData;
pub const Font = core.Font;
pub const Frame = core.Frame;
pub const FrameStorage = core.FrameStorage;
pub const Scene = core.Scene;
pub const SceneBuilder = core.SceneBuilder;
pub const SceneStorage = core.SceneStorage;
pub const DrawContext = platform.macos.DrawContext;
pub const DrawError = platform.macos.DrawError;
pub const DrawFn = platform.macos.DrawFn;
pub const FrameOptions = platform.macos.FrameOptions;
pub const WindowOptions = platform.macos.WindowOptions;
pub const initWindow = platform.macos.initWindow;

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
