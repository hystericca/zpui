pub const frame = @import("frame.zig");
pub const render = @import("render.zig");
pub const metal = @import("zmtl4");
pub const ui = @import("ui.zig");
pub const platform = struct {
    pub const macos = @import("platform/macos.zig");
};
pub const surface = @import("surface.zig");

pub const PlatformError = platform.macos.Error;
pub const FrameData = render.FrameData;
pub const Frame = frame.Frame;
pub const FrameStorage = frame.Storage;
pub const Scene = render.Scene;
pub const SceneBuilder = render.SceneBuilder;
pub const SceneStorage = render.SceneStorage;
pub const runHelloWindow = platform.macos.runHelloWindow;

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
    _ = @import("demo/workspace_shell.zig");
}
