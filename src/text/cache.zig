const std = @import("std");

const defs = @import("defs.zig");
const font = @import("font.zig");
const line = @import("line.zig");
const style = @import("../ui/style.zig");

pub const LineCacheKey = extern struct {
    text_hash: u64 = 0,
    run_hash: u64 = 0,
    bytes_len: u32 = 0,
    run_count: u32 = 0,

    pub fn eql(a: LineCacheKey, b: LineCacheKey) bool {
        return a.text_hash == b.text_hash and
            a.run_hash == b.run_hash and
            a.bytes_len == b.bytes_len and
            a.run_count == b.run_count;
    }
};

pub const LineCacheStats = extern struct {
    current_hits: u32 = 0,
    previous_hits: u32 = 0,
    misses: u32 = 0,
    stores: u32 = 0,
};

const LineCacheEntry = extern struct {
    key: LineCacheKey = .{},
    advance: f32 = 0.0,
    ascent: f32 = 0.0,
    descent: f32 = 0.0,
    leading: f32 = 0.0,
    line_height: f32 = 0.0,
    baseline_offset: f32 = 0.0,
    bytes_len: u32 = 0,
    glyph_start: u32 = 0,
    glyph_count: u32 = 0,

    fn fromLine(key: LineCacheKey, glyph_start: u32, shaped: line.ShapedLine) LineCacheEntry {
        return .{
            .key = key,
            .advance = shaped.advance,
            .ascent = shaped.ascent,
            .descent = shaped.descent,
            .leading = shaped.leading,
            .line_height = shaped.line_height,
            .baseline_offset = shaped.baseline_offset,
            .bytes_len = shaped.bytes_len,
            .glyph_start = glyph_start,
            .glyph_count = @intCast(shaped.glyphs.len),
        };
    }

    fn asLine(entry: LineCacheEntry, glyphs: []const line.ShapedGlyph) line.ShapedLine {
        const start: usize = @intCast(entry.glyph_start);
        const count: usize = @intCast(entry.glyph_count);
        return .{
            .advance = entry.advance,
            .ascent = entry.ascent,
            .descent = entry.descent,
            .leading = entry.leading,
            .line_height = entry.line_height,
            .baseline_offset = entry.baseline_offset,
            .bytes_len = entry.bytes_len,
            .glyphs = glyphs[start .. start + count],
        };
    }
};

pub fn LineCacheType(comptime entry_capacity: usize, comptime glyph_capacity: usize) type {
    return struct {
        banks: [2]Bank = .{ .{}, .{} },
        active: u32 = 0,
        generation: u64 = 0,
        scratch: line.ShapedLineStorage = undefined,
        stats: LineCacheStats = .{},

        const Self = @This();

        const Bank = struct {
            entries: [entry_capacity]LineCacheEntry = @splat(.{}),
            glyphs: [glyph_capacity]line.ShapedGlyph = undefined,
            entry_count: u32 = 0,
            glyph_count: u32 = 0,

            fn clear(bank: *Bank) void {
                bank.entry_count = 0;
                bank.glyph_count = 0;
            }

            fn find(bank: *const Bank, key: LineCacheKey) ?LineCacheEntry {
                for (bank.entries[0..@intCast(bank.entry_count)]) |entry| {
                    if (entry.key.eql(key)) return entry;
                }
                return null;
            }

            fn append(bank: *Bank, key: LineCacheKey, shaped: line.ShapedLine) defs.Error!line.ShapedLine {
                if (bank.entry_count >= entry_capacity) return defs.Error.LineCacheCapacityExceeded;
                if (shaped.glyphs.len > glyph_capacity - @as(usize, @intCast(bank.glyph_count))) {
                    return defs.Error.LineCacheCapacityExceeded;
                }

                const glyph_start = bank.glyph_count;
                const dst_start: usize = @intCast(glyph_start);
                for (shaped.glyphs, 0..) |glyph, index| {
                    bank.glyphs[dst_start + index] = glyph;
                }

                const entry = LineCacheEntry.fromLine(key, glyph_start, shaped);
                bank.entries[@intCast(bank.entry_count)] = entry;
                bank.entry_count += 1;
                bank.glyph_count += @intCast(shaped.glyphs.len);
                return entry.asLine(bank.glyphs[0..]);
            }
        };

        pub fn beginFrame(cache: *Self) void {
            cache.beginFrameGeneration(0);
        }

        pub fn beginFrameGeneration(cache: *Self, generation: u64) void {
            cache.ensureGeneration(generation);
            cache.active = 1 - cache.active;
            cache.current().clear();
            cache.stats = .{};
        }

        pub fn clear(cache: *Self) void {
            cache.banks[0].clear();
            cache.banks[1].clear();
            cache.active = 0;
            cache.stats = .{};
        }

        pub fn ensureGeneration(cache: *Self, generation: u64) void {
            if (cache.generation == generation) return;
            cache.clear();
            cache.generation = generation;
        }

        pub fn lookup(cache: *Self, key: LineCacheKey) defs.Error!?line.ShapedLine {
            if (cache.current().find(key)) |entry| {
                cache.stats.current_hits += 1;
                return entry.asLine(cache.current().glyphs[0..]);
            }

            if (cache.previous().find(key)) |entry| {
                cache.stats.previous_hits += 1;
                const previous_line = entry.asLine(cache.previous().glyphs[0..]);
                return try cache.current().append(key, previous_line);
            }

            cache.stats.misses += 1;
            return null;
        }

        pub fn store(cache: *Self, key: LineCacheKey, shaped: line.ShapedLine) defs.Error!line.ShapedLine {
            cache.stats.stores += 1;
            return cache.current().append(key, shaped);
        }

        fn current(cache: *Self) *Bank {
            return &cache.banks[@intCast(cache.active)];
        }

        fn previous(cache: *Self) *Bank {
            return &cache.banks[@intCast(1 - cache.active)];
        }
    };
}

pub const LineCache = LineCacheType(defs.max_line_cache_entries, defs.max_line_cache_glyphs);

pub fn lineCacheKey(runs: []const line.TextRun) defs.Error!LineCacheKey {
    const bytes_len = try line.runsByteLen(runs);

    var text_hasher = std.hash.Wyhash.init(0x7a_70_75_69);
    var run_hasher = std.hash.Wyhash.init(0x74_65_78_74);

    for (runs) |run| {
        text_hasher.update(run.bytes);
        hashUsize(&run_hasher, run.bytes.len);
        hashFont(&run_hasher, run.font);
        hashF32(&run_hasher, run.size);
    }

    return .{
        .text_hash = text_hasher.final(),
        .run_hash = run_hasher.final(),
        .bytes_len = bytes_len,
        .run_count = @intCast(runs.len),
    };
}

fn hashFont(hasher: *std.hash.Wyhash, handle: font.FontHandle) void {
    hashU32(hasher, handle.index);
    hashU32(hasher, handle.generation);
}

fn hashF32(hasher: *std.hash.Wyhash, value: f32) void {
    hashU32(hasher, @bitCast(value));
}

fn hashUsize(hasher: *std.hash.Wyhash, value: usize) void {
    hashU64(hasher, @intCast(value));
}

fn hashU32(hasher: *std.hash.Wyhash, value: u32) void {
    var bits = value;
    hasher.update(std.mem.asBytes(&bits));
}

fn hashU64(hasher: *std.hash.Wyhash, value: u64) void {
    var bits = value;
    hasher.update(std.mem.asBytes(&bits));
}

comptime {
    std.debug.assert(@sizeOf(LineCacheKey) == 24);
    std.debug.assert(@sizeOf(LineCacheStats) == 16);
}

test "line cache key includes text, font, and size but not paint color" {
    const font_a: font.FontHandle = .{ .index = 1, .generation = 2 };
    const font_b: font.FontHandle = .{ .index = 1, .generation = 3 };
    const base = [_]line.TextRun{.{ .bytes = "abc", .font = font_a, .size = 15.0, .color = style.Color.rgb(1.0, 1.0, 1.0) }};

    const key = try lineCacheKey(base[0..]);
    try std.testing.expect(key.eql(try lineCacheKey(base[0..])));
    try std.testing.expect(!key.eql(try lineCacheKey(&.{.{ .bytes = "abcd", .font = font_a, .size = 15.0, .color = style.Color.rgb(1.0, 1.0, 1.0) }})));
    try std.testing.expect(!key.eql(try lineCacheKey(&.{.{ .bytes = "abc", .font = font_b, .size = 15.0, .color = style.Color.rgb(1.0, 1.0, 1.0) }})));
    try std.testing.expect(!key.eql(try lineCacheKey(&.{.{ .bytes = "abc", .font = font_a, .size = 16.0, .color = style.Color.rgb(1.0, 1.0, 1.0) }})));
    try std.testing.expect(key.eql(try lineCacheKey(&.{.{ .bytes = "abc", .font = font_a, .size = 15.0, .color = style.Color.rgb(0.5, 1.0, 1.0) }})));
}

test "line cache hits current and previous frame banks" {
    var cache: LineCacheType(4, 8) = .{};
    cache.beginFrame();

    var storage: line.ShapedLineStorage = undefined;
    storage.glyphs[0] = .{ .font = .{ .index = 1, .generation = 1 }, .glyph_id = 11, .byte_index = 0, .x = 1.0, .size = 15.0 };
    storage.glyphs[1] = .{ .font = .{ .index = 1, .generation = 1 }, .glyph_id = 12, .byte_index = 1, .x = 6.0, .size = 15.0 };
    const key: LineCacheKey = .{ .text_hash = 1, .run_hash = 2, .bytes_len = 2, .run_count = 1 };
    const shaped: line.ShapedLine = .{
        .advance = 12.0,
        .line_height = 18.0,
        .bytes_len = 2,
        .glyphs = storage.glyphs[0..2],
    };

    const stored = try cache.store(key, shaped);
    try std.testing.expectEqual(@as(usize, 2), stored.glyphs.len);
    try std.testing.expectEqual(@as(u32, 0), stored.glyphs[0].byte_index);
    try std.testing.expectEqual(@as(u32, 11), stored.glyphs[0].glyph_id);
    try std.testing.expectEqual(@as(u32, 1), cache.stats.stores);

    const current = (try cache.lookup(key)).?;
    try std.testing.expectEqual(@as(usize, 2), current.glyphs.len);
    try std.testing.expectEqual(@as(u32, 1), cache.stats.current_hits);

    cache.beginFrame();
    const previous = (try cache.lookup(key)).?;
    try std.testing.expectEqual(@as(usize, 2), previous.glyphs.len);
    try std.testing.expectEqual(@as(u32, 1), cache.stats.previous_hits);
    try std.testing.expectEqual(@as(u32, 1), cache.banks[@intCast(cache.active)].entry_count);
}

test "line cache clears when generation changes" {
    var cache: LineCacheType(4, 8) = .{};
    cache.beginFrameGeneration(1);

    var storage: line.ShapedLineStorage = undefined;
    storage.glyphs[0] = .{ .byte_index = 0 };
    const key: LineCacheKey = .{ .text_hash = 1, .run_hash = 2, .bytes_len = 1, .run_count = 1 };
    const shaped: line.ShapedLine = .{
        .bytes_len = 1,
        .glyphs = storage.glyphs[0..1],
    };
    _ = try cache.store(key, shaped);
    try std.testing.expect((try cache.lookup(key)) != null);

    cache.beginFrameGeneration(2);
    try std.testing.expect((try cache.lookup(key)) == null);
    try std.testing.expectEqual(@as(u64, 2), cache.generation);
    try std.testing.expectEqual(@as(u32, 1), cache.stats.misses);
}

test "line cache reports fixed capacity exhaustion" {
    var cache: LineCacheType(1, 1) = .{};
    cache.beginFrame();

    var storage: line.ShapedLineStorage = undefined;
    storage.glyphs[0] = .{ .byte_index = 0 };
    storage.glyphs[1] = .{ .byte_index = 1 };
    const too_many_glyphs: line.ShapedLine = .{ .glyphs = storage.glyphs[0..2] };
    try std.testing.expectError(defs.Error.LineCacheCapacityExceeded, cache.store(.{ .text_hash = 1 }, too_many_glyphs));

    const one_glyph: line.ShapedLine = .{ .glyphs = storage.glyphs[0..1] };
    _ = try cache.store(.{ .text_hash = 2 }, one_glyph);
    try std.testing.expectError(defs.Error.LineCacheCapacityExceeded, cache.store(.{ .text_hash = 3 }, one_glyph));
}
