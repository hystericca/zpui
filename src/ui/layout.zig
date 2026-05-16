const std = @import("std");

const max_f32: f32 = 3.4028234663852886e38;

pub const Axis = enum(u8) {
    horizontal,
    vertical,

    pub fn cross(axis: Axis) Axis {
        return switch (axis) {
            .horizontal => .vertical,
            .vertical => .horizontal,
        };
    }
};

pub const Align = enum(u8) {
    start,
    center,
    end,
    stretch,
};

pub const Edge = enum(u8) {
    left,
    top,
    right,
    bottom,
};

pub const Point = extern struct {
    x: f32 = 0.0,
    y: f32 = 0.0,

    pub fn init(x: f32, y: f32) Point {
        return .{ .x = x, .y = y };
    }
};

pub const Size = extern struct {
    width: f32 = 0.0,
    height: f32 = 0.0,

    pub fn init(width: f32, height: f32) Size {
        return .{ .width = width, .height = height };
    }

    pub fn along(size: Size, axis: Axis) f32 {
        return switch (axis) {
            .horizontal => size.width,
            .vertical => size.height,
        };
    }

    pub fn withAlong(size: Size, axis: Axis, value: f32) Size {
        var next = size;
        switch (axis) {
            .horizontal => next.width = value,
            .vertical => next.height = value,
        }
        return next;
    }
};

pub const Rect = extern struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    width: f32 = 0.0,
    height: f32 = 0.0,

    pub fn init(x: f32, y: f32, width: f32, height: f32) Rect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn size(rect: Rect) Size {
        return .{ .width = rect.width, .height = rect.height };
    }

    pub fn contains(rect: Rect, point: Point) bool {
        if (rect.width <= 0.0 or rect.height <= 0.0) return false;
        return point.x >= rect.x and point.y >= rect.y and
            point.x < rect.x + rect.width and point.y < rect.y + rect.height;
    }

    pub fn inset(rect: Rect, amount: f32) Rect {
        return .{
            .x = rect.x + amount,
            .y = rect.y + amount,
            .width = @max(rect.width - amount * 2.0, 0.0),
            .height = @max(rect.height - amount * 2.0, 0.0),
        };
    }

    pub fn intersect(a: Rect, b: Rect) Rect {
        const x0 = @max(a.x, b.x);
        const y0 = @max(a.y, b.y);
        const x1 = @min(a.x + a.width, b.x + b.width);
        const y1 = @min(a.y + a.height, b.y + b.height);
        return .{
            .x = x0,
            .y = y0,
            .width = @max(x1 - x0, 0.0),
            .height = @max(y1 - y0, 0.0),
        };
    }
};

pub const Constraints = extern struct {
    min: Size = .{},
    max: Size = .{ .width = max_f32, .height = max_f32 },

    pub fn loose(max: Size) Constraints {
        return .{ .max = max };
    }

    pub fn tight(size: Size) Constraints {
        return .{ .min = size, .max = size };
    }

    pub fn clamp(constraints: Constraints, size: Size) Size {
        return .{
            .width = clampScalar(size.width, constraints.min.width, constraints.max.width),
            .height = clampScalar(size.height, constraints.min.height, constraints.max.height),
        };
    }
};

pub const flag_visible: u32 = 1 << 0;
pub const default_flags: u32 = flag_visible;

pub const LayoutItem = extern struct {
    size: Size = .{},
    min_size: Size = .{},
    max_size: Size = .{ .width = max_f32, .height = max_f32 },
    flags: u32 = default_flags,

    pub fn fixed(size: Size) LayoutItem {
        return .{ .size = size };
    }
};

pub const Pack = struct {
    bounds: Rect,
    axis: Axis = .horizontal,
    gap: f32 = 0.0,
    cross_align: Align = .start,
    clip: Rect = .{},
    flags: u32 = 0,
};

pub const pack_clip: u32 = 1 << 0;

pub const LayoutResult = extern struct {
    rect: Rect = .{},
    clip: Rect = .{},
};

pub const LayoutSummary = extern struct {
    count: usize = 0,
    content_size: Size = .{},
    overflow: Size = .{},
};

pub const Split = extern struct {
    bounds: Rect,
    edge: Edge = .left,
    size: f32 = 0.0,
    gap: f32 = 0.0,
};

pub const SplitResult = extern struct {
    head: Rect = .{},
    tail: Rect = .{},
};

pub const LayoutError = error{
    OutputTooSmall,
    InvalidBounds,
    InvalidClip,
    InvalidGap,
    InvalidConstraints,
    InvalidSize,
};

pub fn pack(spec: Pack, items: []const LayoutItem, out: []LayoutResult) LayoutError!LayoutSummary {
    if (out.len < items.len) return LayoutError.OutputTooSmall;
    if (!validRect(spec.bounds)) return LayoutError.InvalidBounds;
    if (!validNonNegative(spec.gap)) return LayoutError.InvalidGap;
    if ((spec.flags & pack_clip) != 0 and !validRect(spec.clip)) return LayoutError.InvalidClip;

    const clip = if ((spec.flags & pack_clip) != 0) spec.clip else spec.bounds;
    const axis = spec.axis;
    const cross_axis = axis.cross();
    var cursor = alongOrigin(spec.bounds, axis);
    var content_main: f32 = 0.0;
    var content_cross: f32 = 0.0;
    var visible_count: usize = 0;

    for (items, 0..) |item, index| {
        try validateItem(item);

        if ((item.flags & flag_visible) == 0) {
            out[index] = .{};
            continue;
        }

        var size = (Constraints{
            .min = item.min_size,
            .max = item.max_size,
        }).clamp(item.size);

        if (spec.cross_align == .stretch) {
            const stretched = clampScalar(spec.bounds.size().along(cross_axis), item.min_size.along(cross_axis), item.max_size.along(cross_axis));
            size = size.withAlong(cross_axis, stretched);
        }

        if (visible_count != 0) cursor += spec.gap;

        const rect = rectFor(spec.bounds, axis, spec.cross_align, cursor, size);
        out[index] = .{
            .rect = rect,
            .clip = rect.intersect(clip),
        };

        cursor += size.along(axis);
        content_main += size.along(axis);
        if (visible_count != 0) content_main += spec.gap;
        content_cross = @max(content_cross, size.along(cross_axis));
        visible_count += 1;
    }

    const content_size = switch (axis) {
        .horizontal => Size.init(content_main, content_cross),
        .vertical => Size.init(content_cross, content_main),
    };

    return .{
        .count = visible_count,
        .content_size = content_size,
        .overflow = overflow(content_size, spec.bounds.size()),
    };
}

pub fn splitEdge(spec: Split) LayoutError!SplitResult {
    if (!validRect(spec.bounds)) return LayoutError.InvalidBounds;
    if (!validNonNegative(spec.size)) return LayoutError.InvalidSize;
    if (!validNonNegative(spec.gap)) return LayoutError.InvalidGap;

    const total = spec.size + spec.gap;
    return switch (spec.edge) {
        .left => .{
            .head = Rect.init(spec.bounds.x, spec.bounds.y, spec.size, spec.bounds.height),
            .tail = Rect.init(spec.bounds.x + total, spec.bounds.y, @max(spec.bounds.width - total, 0.0), spec.bounds.height),
        },
        .top => .{
            .head = Rect.init(spec.bounds.x, spec.bounds.y, spec.bounds.width, spec.size),
            .tail = Rect.init(spec.bounds.x, spec.bounds.y + total, spec.bounds.width, @max(spec.bounds.height - total, 0.0)),
        },
        .right => .{
            .head = Rect.init(spec.bounds.x + spec.bounds.width - spec.size, spec.bounds.y, spec.size, spec.bounds.height),
            .tail = Rect.init(spec.bounds.x, spec.bounds.y, @max(spec.bounds.width - total, 0.0), spec.bounds.height),
        },
        .bottom => .{
            .head = Rect.init(spec.bounds.x, spec.bounds.y + spec.bounds.height - spec.size, spec.bounds.width, spec.size),
            .tail = Rect.init(spec.bounds.x, spec.bounds.y, spec.bounds.width, @max(spec.bounds.height - total, 0.0)),
        },
    };
}

fn rectFor(bounds: Rect, axis: Axis, alignment: Align, cursor: f32, size: Size) Rect {
    return switch (axis) {
        .horizontal => .{
            .x = cursor,
            .y = crossOrigin(bounds.y, bounds.height, size.height, alignment),
            .width = size.width,
            .height = size.height,
        },
        .vertical => .{
            .x = crossOrigin(bounds.x, bounds.width, size.width, alignment),
            .y = cursor,
            .width = size.width,
            .height = size.height,
        },
    };
}

fn alongOrigin(bounds: Rect, axis: Axis) f32 {
    return switch (axis) {
        .horizontal => bounds.x,
        .vertical => bounds.y,
    };
}

fn crossOrigin(origin: f32, available: f32, size: f32, alignment: Align) f32 {
    return switch (alignment) {
        .start, .stretch => origin,
        .center => origin + (available - size) * 0.5,
        .end => origin + available - size,
    };
}

fn overflow(content_size: Size, bounds_size: Size) Size {
    return .{
        .width = @max(content_size.width - bounds_size.width, 0.0),
        .height = @max(content_size.height - bounds_size.height, 0.0),
    };
}

fn clampScalar(value: f32, min: f32, max: f32) f32 {
    return @min(@max(value, min), max);
}

fn validateItem(item: LayoutItem) LayoutError!void {
    if (!validSize(item.size)) return LayoutError.InvalidSize;
    if (!validConstraints(.{ .min = item.min_size, .max = item.max_size })) return LayoutError.InvalidConstraints;
}

fn validRect(rect: Rect) bool {
    return validScalar(rect.x) and validScalar(rect.y) and validSize(rect.size());
}

fn validSize(size: Size) bool {
    return validNonNegative(size.width) and validNonNegative(size.height);
}

fn validConstraints(constraints: Constraints) bool {
    return validSize(constraints.min) and validSize(constraints.max) and
        constraints.min.width <= constraints.max.width and constraints.min.height <= constraints.max.height;
}

fn validNonNegative(value: f32) bool {
    return validScalar(value) and value >= 0.0;
}

fn validScalar(value: f32) bool {
    return std.math.isFinite(value);
}

comptime {
    std.debug.assert(@sizeOf(Point) == 8);
    std.debug.assert(@sizeOf(Size) == 8);
    std.debug.assert(@sizeOf(Rect) == 16);
    std.debug.assert(@sizeOf(Constraints) == 16);
    std.debug.assert(@sizeOf(LayoutItem) == 28);
    std.debug.assert(@sizeOf(LayoutResult) == 32);
    std.debug.assert(@sizeOf(LayoutSummary) == 24);
    std.debug.assert(@sizeOf(Split) == 28);
    std.debug.assert(@sizeOf(SplitResult) == 32);
}

test "pack writes row regions with gaps and center alignment" {
    const items = [_]LayoutItem{
        LayoutItem.fixed(Size.init(20.0, 10.0)),
        LayoutItem.fixed(Size.init(30.0, 20.0)),
    };
    var out: [items.len]LayoutResult = undefined;

    const summary = try pack(.{
        .bounds = Rect.init(10.0, 20.0, 100.0, 40.0),
        .gap = 5.0,
        .cross_align = .center,
    }, items[0..], out[0..]);

    try std.testing.expectEqual(@as(usize, 2), summary.count);
    try std.testing.expectEqual(Rect.init(10.0, 35.0, 20.0, 10.0), out[0].rect);
    try std.testing.expectEqual(Rect.init(10.0, 35.0, 20.0, 10.0), out[0].clip);
    try std.testing.expectEqual(Rect.init(35.0, 30.0, 30.0, 20.0), out[1].rect);
    try std.testing.expectEqual(Size.init(55.0, 20.0), summary.content_size);
    try std.testing.expectEqual(Size{}, summary.overflow);
}

test "pack stretches cross axis through item constraints" {
    const items = [_]LayoutItem{
        .{
            .size = Size.init(12.0, 10.0),
            .min_size = Size.init(20.0, 0.0),
            .max_size = Size.init(50.0, 40.0),
        },
        .{
            .size = Size.init(16.0, 8.0),
            .min_size = Size.init(20.0, 0.0),
            .max_size = Size.init(50.0, 40.0),
        },
    };
    var out: [items.len]LayoutResult = undefined;

    const summary = try pack(.{
        .bounds = Rect.init(4.0, 6.0, 80.0, 100.0),
        .axis = .vertical,
        .gap = 2.0,
        .cross_align = .stretch,
    }, items[0..], out[0..]);

    try std.testing.expectEqual(Rect.init(4.0, 6.0, 50.0, 10.0), out[0].rect);
    try std.testing.expectEqual(Rect.init(4.0, 18.0, 50.0, 8.0), out[1].rect);
    try std.testing.expectEqual(Size.init(50.0, 20.0), summary.content_size);
    try std.testing.expectEqual(Size{}, summary.overflow);
}

test "pack reports overflow while preserving unclipped rects" {
    const items = [_]LayoutItem{
        LayoutItem.fixed(Size.init(30.0, 10.0)),
        LayoutItem.fixed(Size.init(30.0, 10.0)),
    };
    var out: [items.len]LayoutResult = undefined;

    const summary = try pack(.{
        .bounds = Rect.init(0.0, 0.0, 50.0, 20.0),
        .gap = 4.0,
    }, items[0..], out[0..]);

    try std.testing.expectEqual(Rect.init(34.0, 0.0, 30.0, 10.0), out[1].rect);
    try std.testing.expectEqual(Rect.init(34.0, 0.0, 16.0, 10.0), out[1].clip);
    try std.testing.expectEqual(Size.init(64.0, 10.0), summary.content_size);
    try std.testing.expectEqual(Size.init(14.0, 0.0), summary.overflow);
}

test "pack can use an explicit clip rectangle" {
    const items = [_]LayoutItem{
        LayoutItem.fixed(Size.init(50.0, 20.0)),
    };
    var out: [items.len]LayoutResult = undefined;

    _ = try pack(.{
        .bounds = Rect.init(0.0, 0.0, 100.0, 40.0),
        .clip = Rect.init(10.0, 0.0, 30.0, 40.0),
        .flags = pack_clip,
    }, items[0..], out[0..]);

    try std.testing.expectEqual(Rect.init(0.0, 0.0, 50.0, 20.0), out[0].rect);
    try std.testing.expectEqual(Rect.init(10.0, 0.0, 30.0, 20.0), out[0].clip);
}

test "pack skips invisible regions without consuming strip space" {
    const items = [_]LayoutItem{
        LayoutItem.fixed(Size.init(10.0, 10.0)),
        .{ .size = Size.init(100.0, 100.0), .flags = 0 },
        LayoutItem.fixed(Size.init(20.0, 10.0)),
    };
    var out: [items.len]LayoutResult = undefined;

    const summary = try pack(.{
        .bounds = Rect.init(0.0, 0.0, 100.0, 20.0),
        .gap = 4.0,
    }, items[0..], out[0..]);

    try std.testing.expectEqual(@as(usize, 2), summary.count);
    try std.testing.expectEqual(Rect.init(0.0, 0.0, 10.0, 10.0), out[0].rect);
    try std.testing.expectEqual(LayoutResult{}, out[1]);
    try std.testing.expectEqual(Rect.init(14.0, 0.0, 20.0, 10.0), out[2].rect);
    try std.testing.expectEqual(Size.init(34.0, 10.0), summary.content_size);
}

test "split edge carves explicit rio-style bands" {
    const left = try splitEdge(.{
        .bounds = Rect.init(0.0, 0.0, 100.0, 30.0),
        .edge = .left,
        .size = 12.0,
        .gap = 4.0,
    });

    try std.testing.expectEqual(Rect.init(0.0, 0.0, 12.0, 30.0), left.head);
    try std.testing.expectEqual(Rect.init(16.0, 0.0, 84.0, 30.0), left.tail);

    const bottom = try splitEdge(.{
        .bounds = Rect.init(0.0, 0.0, 100.0, 30.0),
        .edge = .bottom,
        .size = 8.0,
        .gap = 2.0,
    });

    try std.testing.expectEqual(Rect.init(0.0, 22.0, 100.0, 8.0), bottom.head);
    try std.testing.expectEqual(Rect.init(0.0, 0.0, 100.0, 20.0), bottom.tail);
}

test "split edge preserves head size and empties tail on overflow" {
    const result = try splitEdge(.{
        .bounds = Rect.init(0.0, 0.0, 20.0, 10.0),
        .edge = .right,
        .size = 30.0,
        .gap = 4.0,
    });

    try std.testing.expectEqual(Rect.init(-10.0, 0.0, 30.0, 10.0), result.head);
    try std.testing.expectEqual(Rect.init(0.0, 0.0, 0.0, 10.0), result.tail);
}

test "layout validates caller buffers and numeric inputs" {
    const items = [_]LayoutItem{
        LayoutItem.fixed(Size.init(8.0, 8.0)),
        LayoutItem.fixed(Size.init(8.0, 8.0)),
    };
    var one_out: [1]LayoutResult = undefined;
    var out: [items.len]LayoutResult = undefined;

    try std.testing.expectError(LayoutError.OutputTooSmall, pack(.{
        .bounds = Rect.init(0.0, 0.0, 10.0, 10.0),
    }, items[0..], one_out[0..]));

    try std.testing.expectError(LayoutError.InvalidGap, pack(.{
        .bounds = Rect.init(0.0, 0.0, 10.0, 10.0),
        .gap = -1.0,
    }, items[0..], out[0..]));

    try std.testing.expectError(LayoutError.InvalidBounds, pack(.{
        .bounds = Rect.init(0.0, 0.0, -10.0, 10.0),
    }, items[0..], out[0..]));

    try std.testing.expectError(LayoutError.InvalidClip, pack(.{
        .bounds = Rect.init(0.0, 0.0, 10.0, 10.0),
        .clip = Rect.init(0.0, 0.0, -1.0, 1.0),
        .flags = pack_clip,
    }, items[0..], out[0..]));

    try std.testing.expectError(LayoutError.InvalidSize, pack(.{
        .bounds = Rect.init(0.0, 0.0, 10.0, 10.0),
    }, &.{LayoutItem.fixed(Size.init(-1.0, 2.0))}, out[0..1]));

    try std.testing.expectError(LayoutError.InvalidConstraints, pack(.{
        .bounds = Rect.init(0.0, 0.0, 10.0, 10.0),
    }, &.{.{ .min_size = Size.init(20.0, 0.0), .max_size = Size.init(10.0, 100.0) }}, out[0..1]));

    try std.testing.expectError(LayoutError.InvalidSize, splitEdge(.{
        .bounds = Rect.init(0.0, 0.0, 10.0, 10.0),
        .size = -1.0,
    }));
}
