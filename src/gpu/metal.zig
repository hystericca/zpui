const std = @import("std");

const objc = @import("../objc.zig");

pub const Error = error{
    InvalidDevice,
    InvalidLayer,
    MissingClass,
    MissingSelector,
    LayerAllocationFailed,
};

pub const Status = enum(c_int) {
    ok = 0,
    invalid_device = 10,
    invalid_layer = 11,
    missing_class = 12,
    missing_selector = 13,
    layer_allocation_failed = 14,

    pub fn fromError(err: Error) Status {
        return switch (err) {
            Error.InvalidDevice => .invalid_device,
            Error.InvalidLayer => .invalid_layer,
            Error.MissingClass => .missing_class,
            Error.MissingSelector => .missing_selector,
            Error.LayerAllocationFailed => .layer_allocation_failed,
        };
    }
};

pub const PixelFormat = enum(objc.NSUInteger) {
    bgra8_unorm = 80,
};

pub const LayerConfig = struct {
    pixel_format: PixelFormat = .bgra8_unorm,
    framebuffer_only: bool = true,
    is_opaque: bool = true,
    maximum_drawable_count: objc.NSUInteger = 3,
    presents_with_transaction: bool = false,
    allows_next_drawable_timeout: bool = false,
    display_sync_enabled: bool = true,
    needs_display_on_bounds_change: bool = true,
    autoresizing_mask: objc.CAAutoresizingMask = ca_layer_width_sizable | ca_layer_height_sizable,
};

pub const ca_layer_width_sizable: objc.CAAutoresizingMask = 1 << 1;
pub const ca_layer_height_sizable: objc.CAAutoresizingMask = 1 << 4;

pub fn createLayer(device: objc.Id, config: LayerConfig) Error!objc.Id {
    const cls = objc.getClass("CAMetalLayer") orelse return Error.MissingClass;
    const layer_sel = objc.selector("layer") orelse return Error.MissingSelector;
    const layer = objc.sendId0(cls, layer_sel) orelse return Error.LayerAllocationFailed;
    try configureLayer(layer, device, config);
    return layer;
}

pub fn configureLayer(layer: objc.Id, device: objc.Id, config: LayerConfig) Error!void {
    objc.sendVoidId(layer, try sel("setDevice:"), device);
    objc.sendVoidUSize(layer, try sel("setPixelFormat:"), @intFromEnum(config.pixel_format));
    objc.sendVoidBool(layer, try sel("setFramebufferOnly:"), config.framebuffer_only);
    objc.sendVoidBool(layer, try sel("setOpaque:"), config.is_opaque);
    objc.sendVoidUSize(layer, try sel("setMaximumDrawableCount:"), config.maximum_drawable_count);
    objc.sendVoidBool(layer, try sel("setPresentsWithTransaction:"), config.presents_with_transaction);
    objc.sendVoidBool(layer, try sel("setAllowsNextDrawableTimeout:"), config.allows_next_drawable_timeout);
    objc.sendVoidBool(layer, try sel("setDisplaySyncEnabled:"), config.display_sync_enabled);
    objc.sendVoidBool(layer, try sel("setNeedsDisplayOnBoundsChange:"), config.needs_display_on_bounds_change);
    objc.sendVoidUInt(layer, try sel("setAutoresizingMask:"), config.autoresizing_mask);
}

pub fn resizeLayer(layer: objc.Id, drawable_size: objc.CGSize, scale: objc.CGFloat) Error!void {
    if (drawable_size.width <= 0 or drawable_size.height <= 0 or scale <= 0) return;

    objc.sendVoidF64(layer, try sel("setContentsScale:"), scale);
    objc.sendVoidSize(layer, try sel("setDrawableSize:"), drawable_size);
}

fn sel(name: [*:0]const u8) Error!objc.Sel {
    return objc.selector(name) orelse Error.MissingSelector;
}

pub export fn zpui_metal_create_layer(device: ?objc.Id, out_layer: *?objc.Id) c_int {
    out_layer.* = null;
    const unwrapped_device = device orelse return @intFromEnum(Status.invalid_device);

    const layer = createLayer(unwrapped_device, .{}) catch |err| {
        return @intFromEnum(Status.fromError(err));
    };
    out_layer.* = layer;
    return @intFromEnum(Status.ok);
}

pub export fn zpui_metal_resize_layer(layer: ?objc.Id, width: f64, height: f64, scale: f64) c_int {
    const unwrapped_layer = layer orelse return @intFromEnum(Status.invalid_layer);
    resizeLayer(
        unwrapped_layer,
        .{ .width = width, .height = height },
        scale,
    ) catch |err| {
        return @intFromEnum(Status.fromError(err));
    };
    return @intFromEnum(Status.ok);
}

test "Metal layer constants match the macOS ABI surface" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(objc.CGFloat));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(objc.CGSize));
    try std.testing.expectEqual(@as(objc.NSUInteger, 80), @intFromEnum(PixelFormat.bgra8_unorm));
    try std.testing.expectEqual(@as(objc.CAAutoresizingMask, 18), ca_layer_width_sizable | ca_layer_height_sizable);
}
