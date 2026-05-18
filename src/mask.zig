const std = @import("std");

const layout = @import("ui/layout.zig");
const style = @import("ui/style.zig");

pub const atlas_width = 1024;
pub const atlas_height = 1024;
pub const atlas_byte_len = atlas_width * atlas_height;
pub const max_entries = 256;
pub const pack_padding = 1;

pub const Error = error{
    InvalidMaskId,
    InvalidMask,
    AtlasFull,
    EntryCapacityExceeded,
};

pub const AtlasRect = extern struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    width: f32 = 0.0,
    height: f32 = 0.0,
};

pub const Instance = extern struct {
    rect: layout.Rect = .{},
    atlas_rect: AtlasRect = .{},
    color: style.Color = .{},
};

pub const AtlasStorage = struct {
    bytes: [atlas_byte_len]u8 = [_]u8{0} ** atlas_byte_len,
    rects: [max_entries]AtlasRect = [_]AtlasRect{.{}} ** max_entries,
    count: u32 = 0,
    next_x: u32 = 0,
    next_y: u32 = 0,
    row_height: u32 = 0,

    pub fn clear(atlas: *AtlasStorage) void {
        @memset(&atlas.bytes, 0);
        atlas.rects = [_]AtlasRect{.{}} ** max_entries;
        atlas.count = 0;
        atlas.next_x = 0;
        atlas.next_y = 0;
        atlas.row_height = 0;
    }

    pub fn rect(atlas: *const AtlasStorage, id: u32) Error!AtlasRect {
        if (atlas.count > max_entries) return Error.EntryCapacityExceeded;
        if (id >= atlas.count) return Error.InvalidMaskId;
        return atlas.rects[@intCast(id)];
    }

    pub fn appendMask(atlas: *AtlasStorage, width: u32, height: u32, bytes: []const u8, bytes_per_row: u32) Error!u32 {
        if (atlas.count > max_entries) return Error.EntryCapacityExceeded;
        if (width == 0 or height == 0) return Error.InvalidMask;
        if (width > atlas_width - pack_padding * 2 or height > atlas_height - pack_padding * 2) return Error.AtlasFull;
        if (bytes_per_row < width) return Error.InvalidMask;
        const required_len = @as(usize, @intCast(bytes_per_row)) * @as(usize, @intCast(height));
        if (bytes.len < required_len) return Error.InvalidMask;
        if (atlas.count >= max_entries) return Error.EntryCapacityExceeded;

        const padded_width = width + pack_padding * 2;
        const padded_height = height + pack_padding * 2;
        if (atlas.next_x + padded_width > atlas_width) {
            atlas.next_x = 0;
            atlas.next_y += atlas.row_height;
            atlas.row_height = 0;
        }
        if (atlas.next_y + padded_height > atlas_height) return Error.AtlasFull;

        const dst_x = atlas.next_x + pack_padding;
        const dst_y = atlas.next_y + pack_padding;
        var row: u32 = 0;
        while (row < height) : (row += 1) {
            const src_start = @as(usize, @intCast(row)) * @as(usize, @intCast(bytes_per_row));
            const dst_start = @as(usize, @intCast(dst_y + row)) * atlas_width + @as(usize, @intCast(dst_x));
            @memcpy(atlas.bytes[dst_start .. dst_start + @as(usize, @intCast(width))], bytes[src_start .. src_start + @as(usize, @intCast(width))]);
        }

        const id = atlas.count;
        atlas.rects[@intCast(id)] = rectFromPixels(dst_x, dst_y, width, height);
        atlas.count += 1;
        atlas.next_x += padded_width;
        atlas.row_height = @max(atlas.row_height, padded_height);
        return id;
    }

    pub fn valid(atlas: *const AtlasStorage) bool {
        if (atlas.count > max_entries) return false;
        if (atlas.next_x > atlas_width or atlas.next_y > atlas_height or atlas.row_height > atlas_height) return false;
        for (atlas.rects[0..@intCast(atlas.count)]) |entry| {
            if (!validRect(entry)) return false;
        }
        return true;
    }
};

pub fn rectFromPixels(x: u32, y: u32, width: u32, height: u32) AtlasRect {
    return .{
        .x = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(atlas_width)),
        .y = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(atlas_height)),
        .width = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(atlas_width)),
        .height = @as(f32, @floatFromInt(height)) / @as(f32, @floatFromInt(atlas_height)),
    };
}

pub fn validRect(rect: AtlasRect) bool {
    const epsilon = 0.0001;
    return rect.x >= 0.0 and
        rect.y >= 0.0 and
        rect.width > 0.0 and
        rect.height > 0.0 and
        rect.x + rect.width <= 1.0 + epsilon and
        rect.y + rect.height <= 1.0 + epsilon and
        std.math.isFinite(rect.x) and
        std.math.isFinite(rect.y) and
        std.math.isFinite(rect.width) and
        std.math.isFinite(rect.height);
}

comptime {
    std.debug.assert(@sizeOf(AtlasRect) == 16);
    std.debug.assert(@sizeOf(Instance) == 48);
}

test "mask atlas appends prepared monochrome masks with padding" {
    var atlas: AtlasStorage = .{};

    const pixels = [_]u8{
        0,  10, 20, 30,
        40, 50, 60, 70,
    };
    const id = try atlas.appendMask(4, 2, pixels[0..], 4);
    const rect = try atlas.rect(id);
    const dst_x: usize = pack_padding;
    const dst_y: usize = pack_padding;

    try std.testing.expectEqual(@as(u32, 0), id);
    try std.testing.expectEqual(rectFromPixels(@intCast(dst_x), @intCast(dst_y), 4, 2), rect);
    try std.testing.expectEqual(@as(u8, 0), atlas.bytes[dst_y * atlas_width + dst_x - 1]);
    try std.testing.expectEqual(@as(u8, 0), atlas.bytes[(dst_y - 1) * atlas_width + dst_x]);
    try std.testing.expectEqual(@as(u8, 0), atlas.bytes[(dst_y + 2) * atlas_width + dst_x]);
    try std.testing.expectEqual(@as(u8, 0), atlas.bytes[dst_y * atlas_width + dst_x + 4]);
    try std.testing.expectEqual(@as(u8, 50), atlas.bytes[(dst_y + 1) * atlas_width + dst_x + 1]);
    try std.testing.expect(atlas.valid());
}

test "mask atlas rejects invalid masks and entry overflow" {
    var atlas: AtlasStorage = .{};
    atlas.clear();

    try std.testing.expectError(Error.InvalidMask, atlas.appendMask(0, 1, &.{1}, 1));
    try std.testing.expectError(Error.InvalidMask, atlas.appendMask(2, 1, &.{1}, 1));
    try std.testing.expectError(Error.InvalidMask, atlas.appendMask(2, 2, &.{ 1, 2, 3 }, 2));
    try std.testing.expectError(Error.AtlasFull, atlas.appendMask(atlas_width, 1, &.{}, atlas_width));

    const pixel = [_]u8{255};
    for (0..max_entries) |_| {
        _ = try atlas.appendMask(1, 1, pixel[0..], 1);
    }
    try std.testing.expectError(Error.EntryCapacityExceeded, atlas.appendMask(1, 1, pixel[0..], 1));
    try std.testing.expectError(Error.InvalidMaskId, atlas.rect(max_entries));
}

test "mask atlas validates public storage before upload" {
    var atlas: AtlasStorage = .{};
    try std.testing.expect(atlas.valid());

    const pixel = [_]u8{255};
    _ = try atlas.appendMask(1, 1, pixel[0..], 1);
    atlas.rects[0].width = 0.0;
    try std.testing.expect(!atlas.valid());

    atlas.clear();
    atlas.count = max_entries + 1;
    try std.testing.expect(!atlas.valid());
    try std.testing.expectError(Error.EntryCapacityExceeded, atlas.rect(0));
}
