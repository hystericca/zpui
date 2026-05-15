const std = @import("std");

const render = @import("render.zig");

pub const Error = render.SceneBuildError;

pub const InputSnapshot = struct {
    cursor: ?[2]f32 = null,
    buttons: u32 = 0,
    mods: u32 = 0,
};

pub const Begin = struct {
    size: [2]f32,
    scale: f32 = 1.0,
    clear_color: render.ClearColor = .{ 0.0, 0.0, 0.0, 1.0 },
    input: InputSnapshot = .{},
};

pub const Storage = struct {
    scene: render.SceneStorage = undefined,
};

pub const Frame = struct {
    storage: *Storage,
    size: [2]f32,
    scale: f32,
    input: InputSnapshot,
    scene: render.SceneBuilder,

    pub fn begin(storage: *Storage, options: Begin) Frame {
        return .{
            .storage = storage,
            .size = options.size,
            .scale = options.scale,
            .input = options.input,
            .scene = render.SceneBuilder.begin(&storage.scene, options.size, options.clear_color),
        };
    }

    pub fn pushDrawableClip(frame: *Frame) Error!u32 {
        return frame.scene.pushDrawableClip();
    }

    pub fn pushClip(frame: *Frame, clip: render.ClipRect) Error!u32 {
        return frame.scene.pushClip(clip);
    }

    pub fn beginBatch(frame: *Frame, clip_index: u32) Error!void {
        try frame.scene.beginBatch(clip_index);
    }

    pub fn pushQuad(frame: *Frame, rect: render.Rect, color: render.Color, clip_index: u32) Error!void {
        try frame.scene.pushQuad(rect, color, clip_index);
    }

    pub fn endBatch(frame: *Frame) Error!void {
        try frame.scene.endBatch();
    }

    pub fn finish(frame: *Frame) Error!render.Scene {
        return frame.scene.finish();
    }
};

test "frame owns caller-provided scene storage for one scene" {
    var storage: Storage = undefined;
    var frame = Frame.begin(&storage, .{
        .size = .{ 640.0, 480.0 },
        .scale = 2.0,
        .input = .{ .cursor = .{ 12.0, 18.0 }, .buttons = 1 },
    });

    const clip = try frame.pushDrawableClip();
    try frame.beginBatch(clip);
    try frame.pushQuad(.{
        .x = 8.0,
        .y = 10.0,
        .width = 24.0,
        .height = 18.0,
    }, .{ 1.0, 1.0, 1.0, 1.0 }, clip);
    const scene = try frame.finish();

    try std.testing.expectEqual([2]f32{ 640.0, 480.0 }, frame.size);
    try std.testing.expectEqual(@as(f32, 2.0), frame.scale);
    try std.testing.expectEqual(@as(?[2]f32, .{ 12.0, 18.0 }), frame.input.cursor);
    try std.testing.expectEqual(@as(usize, 1), scene.clips.len);
    try std.testing.expectEqual(@as(usize, 1), scene.quads.len);
    try std.testing.expectEqual(@as(usize, 1), scene.batches.len);
}

test "frame preserves scene builder errors" {
    var storage: Storage = undefined;
    var frame = Frame.begin(&storage, .{ .size = .{ 320.0, 200.0 } });
    const clip = try frame.pushDrawableClip();

    try std.testing.expectError(Error.NoOpenBatch, frame.pushQuad(.{
        .x = 0.0,
        .y = 0.0,
        .width = 1.0,
        .height = 1.0,
    }, .{ 1.0, 1.0, 1.0, 1.0 }, clip));
}
