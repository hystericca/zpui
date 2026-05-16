const std = @import("std");
const layout = @import("layout.zig");

pub const HitId = u32;
pub const none: HitId = 0;

pub const flag_enabled: u32 = 1 << 0;
pub const flag_hit: u32 = 1 << 1;
pub const flag_clip: u32 = 1 << 2;
pub const default_flags: u32 = flag_enabled | flag_hit;

pub const HitItem = extern struct {
    id: HitId = none,
    flags: u32 = default_flags,
    rect: layout.Rect = .{},
    clip: layout.Rect = .{},

    pub fn init(id: HitId, rect: layout.Rect) HitItem {
        return .{ .id = id, .rect = rect };
    }

    pub fn clipped(id: HitId, rect: layout.Rect, clip: layout.Rect) HitItem {
        return .{ .id = id, .flags = default_flags | flag_clip, .rect = rect, .clip = clip };
    }
};

pub const HitState = extern struct {
    hot: HitId = none,
    active: HitId = none,
    focus: HitId = none,
};

pub fn hitTest(point: layout.Point, items: []const HitItem) HitId {
    var index = items.len;
    while (index > 0) {
        index -= 1;

        const item = items[index];
        if (item.id == none) continue;
        if ((item.flags & flag_enabled) == 0) continue;
        if ((item.flags & flag_hit) == 0) continue;
        if (!item.rect.contains(point)) continue;
        if ((item.flags & flag_clip) != 0 and !item.clip.contains(point)) continue;

        return item.id;
    }

    return none;
}

comptime {
    std.debug.assert(@sizeOf(HitState) == 12);
    std.debug.assert(@sizeOf(HitItem) == 40);
    std.debug.assert(@offsetOf(HitItem, "id") == 0);
    std.debug.assert(@offsetOf(HitItem, "flags") == 4);
}

test "hit testing returns the last matching item as topmost z order" {
    const items = [_]HitItem{
        HitItem.init(1, layout.Rect.init(0.0, 0.0, 50.0, 50.0)),
        HitItem.init(2, layout.Rect.init(10.0, 10.0, 50.0, 50.0)),
    };

    try std.testing.expectEqual(@as(HitId, 2), hitTest(layout.Point.init(20.0, 20.0), items[0..]));
    try std.testing.expectEqual(@as(HitId, 1), hitTest(layout.Point.init(5.0, 5.0), items[0..]));
}

test "hit testing honors clipping rectangles" {
    const items = [_]HitItem{
        HitItem.clipped(
            7,
            layout.Rect.init(0.0, 0.0, 100.0, 100.0),
            layout.Rect.init(25.0, 25.0, 25.0, 25.0),
        ),
    };

    try std.testing.expectEqual(none, hitTest(layout.Point.init(10.0, 10.0), items[0..]));
    try std.testing.expectEqual(@as(HitId, 7), hitTest(layout.Point.init(30.0, 30.0), items[0..]));
}

test "hit testing skips disabled non-hit and empty ids" {
    const items = [_]HitItem{
        HitItem.init(3, layout.Rect.init(0.0, 0.0, 100.0, 100.0)),
        .{ .id = 4, .flags = flag_hit, .rect = layout.Rect.init(0.0, 0.0, 100.0, 100.0) },
        .{ .id = 5, .flags = flag_enabled, .rect = layout.Rect.init(0.0, 0.0, 100.0, 100.0) },
        HitItem.init(none, layout.Rect.init(0.0, 0.0, 100.0, 100.0)),
    };

    try std.testing.expectEqual(@as(HitId, 3), hitTest(layout.Point.init(12.0, 12.0), items[0..]));
}

test "hit state is plain ids with zero as no target" {
    var state: HitState = .{};
    try std.testing.expectEqual(none, state.hot);
    try std.testing.expectEqual(none, state.active);
    try std.testing.expectEqual(none, state.focus);

    state = .{ .hot = 10, .active = 11, .focus = 12 };
    try std.testing.expectEqual(@as(HitId, 10), state.hot);
    try std.testing.expectEqual(@as(HitId, 11), state.active);
    try std.testing.expectEqual(@as(HitId, 12), state.focus);
}
