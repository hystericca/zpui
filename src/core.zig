pub const frame = @import("frame.zig");
pub const mask = @import("mask.zig");
pub const scene = @import("scene.zig");
pub const render = scene;
pub const text = @import("text.zig");
pub const ui = @import("ui.zig");

pub const FrameData = scene.FrameData;
pub const Font = text.Font;
pub const FontOptions = text.FontOptions;
pub const FontVariation = text.FontVariation;
pub const default_font_slot = text.default_font_slot;
pub const max_font_slots = text.max_font_slots;
pub const Frame = frame.Frame;
pub const FrameStorage = frame.Storage;
pub const MaskAtlasRect = mask.AtlasRect;
pub const MaskAtlasStorage = mask.AtlasStorage;
pub const MaskError = mask.Error;
pub const Scene = scene.Scene;
pub const SceneBuilder = scene.SceneBuilder;
pub const SceneStorage = scene.SceneStorage;
pub const TextMetrics = text.TextMetrics;
pub const RowTextPlacement = text.RowTextPlacement;

pub fn fontAxis(comptime tag: []const u8) u32 {
    return text.axis(tag);
}

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
