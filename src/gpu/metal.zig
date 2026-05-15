const std = @import("std");

const objc = @import("../objc.zig");

pub const Error = error{
    MissingClass,
    MissingSelector,
    UnsupportedDevice,
    LayerAllocationFailed,
    CommandQueueCreationFailed,
    CommandAllocatorCreationFailed,
    CommandBufferCreationFailed,
    BufferCreationFailed,
    BufferContentsUnavailable,
    ArgumentTableDescriptorCreationFailed,
    ArgumentTableCreationFailed,
    ResidencySetDescriptorCreationFailed,
    ResidencySetCreationFailed,
    SharedEventCreationFailed,
};

pub const GPUFamily = enum(objc.NSInteger) {
    apple1 = 1001,
    apple2 = 1002,
    apple3 = 1003,
    apple4 = 1004,
    apple5 = 1005,
    apple6 = 1006,
    apple7 = 1007,
    apple8 = 1008,
    apple9 = 1009,
    apple10 = 1010,
    metal3 = 5001,
    metal4 = 5002,
};

pub const DeviceCapabilities = struct {
    has_unified_memory: bool,
    supports_metal4: bool,
    highest_apple_family: ?GPUFamily,
    recommended_max_working_set_size: u64,

    pub fn supportsAppleFamilyAtLeast(caps: DeviceCapabilities, minimum: GPUFamily) bool {
        const actual = caps.highest_apple_family orelse return false;
        return @intFromEnum(actual) >= @intFromEnum(minimum);
    }
};

pub const TargetProfile = struct {
    require_unified_memory: bool = true,
    require_metal4: bool = true,
    minimum_apple_family: GPUFamily = .apple10,
};

pub const developer_target_profile: TargetProfile = .{};

pub const PixelFormat = enum(objc.NSUInteger) {
    bgra8_unorm = 80,
};

pub const MTLGPUAddress = u64;
pub const resource_cpu_cache_mode_write_combined: objc.NSUInteger = 1 << 0;
pub const resource_storage_mode_shared: objc.NSUInteger = 0 << 4;
pub const shared_write_combined_buffer_options: objc.NSUInteger =
    resource_storage_mode_shared | resource_cpu_cache_mode_write_combined;

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

pub fn createMetal4CommandQueue(device: objc.Id) Error!objc.Id {
    const command_queue_sel = objc.selector("newMTL4CommandQueue") orelse return Error.MissingSelector;
    return objc.sendId0(device, command_queue_sel) orelse Error.CommandQueueCreationFailed;
}

pub fn createMetal4CommandAllocator(device: objc.Id) Error!objc.Id {
    const allocator_sel = objc.selector("newCommandAllocator") orelse return Error.MissingSelector;
    return objc.sendId0(device, allocator_sel) orelse Error.CommandAllocatorCreationFailed;
}

pub fn createMetal4CommandBuffer(device: objc.Id) Error!objc.Id {
    const command_buffer_sel = objc.selector("newCommandBuffer") orelse return Error.MissingSelector;
    return objc.sendId0(device, command_buffer_sel) orelse Error.CommandBufferCreationFailed;
}

pub fn createBuffer(device: objc.Id, byte_len: usize, options: objc.NSUInteger) Error!objc.Id {
    return objc.sendIdUSizeUSize(
        device,
        try sel("newBufferWithLength:options:"),
        byte_len,
        options,
    ) orelse Error.BufferCreationFailed;
}

pub fn bufferContents(buffer: objc.Id) Error![*]u8 {
    const contents = objc.sendPtr0(buffer, try sel("contents")) orelse return Error.BufferContentsUnavailable;
    return @ptrCast(contents);
}

pub fn bufferGpuAddress(buffer: objc.Id) Error!MTLGPUAddress {
    return objc.sendU64_0(buffer, try sel("gpuAddress"));
}

pub fn createMetal4ArgumentTable(device: objc.Id, max_buffer_bind_count: objc.NSUInteger) Error!objc.Id {
    const descriptor_class = objc.getClass("MTL4ArgumentTableDescriptor") orelse return Error.MissingClass;
    const descriptor = objc.sendId0(descriptor_class, try sel("new")) orelse return Error.ArgumentTableDescriptorCreationFailed;
    defer releaseObject(descriptor);

    objc.sendVoidUSize(descriptor, try sel("setMaxBufferBindCount:"), max_buffer_bind_count);
    objc.sendVoidUSize(descriptor, try sel("setMaxTextureBindCount:"), 0);
    objc.sendVoidUSize(descriptor, try sel("setMaxSamplerStateBindCount:"), 0);
    objc.sendVoidBool(descriptor, try sel("setInitializeBindings:"), true);

    return objc.sendIdIdPtr(
        device,
        try sel("newArgumentTableWithDescriptor:error:"),
        descriptor,
        null,
    ) orelse Error.ArgumentTableCreationFailed;
}

pub fn createResidencySet(device: objc.Id, initial_capacity: objc.NSUInteger) Error!objc.Id {
    const descriptor_class = objc.getClass("MTLResidencySetDescriptor") orelse return Error.MissingClass;
    const descriptor = objc.sendId0(descriptor_class, try sel("new")) orelse return Error.ResidencySetDescriptorCreationFailed;
    defer releaseObject(descriptor);

    objc.sendVoidUSize(descriptor, try sel("setInitialCapacity:"), initial_capacity);
    return objc.sendIdIdPtr(
        device,
        try sel("newResidencySetWithDescriptor:error:"),
        descriptor,
        null,
    ) orelse Error.ResidencySetCreationFailed;
}

pub fn addResidencyAllocation(residency_set: objc.Id, allocation: objc.Id) Error!void {
    objc.sendVoidId(residency_set, try sel("addAllocation:"), allocation);
}

pub fn commitResidencySet(residency_set: objc.Id) Error!void {
    objc.sendVoid0(residency_set, try sel("commit"));
}

pub fn requestResidencySet(residency_set: objc.Id) Error!void {
    objc.sendVoid0(residency_set, try sel("requestResidency"));
}

pub fn endResidencySet(residency_set: objc.Id) Error!void {
    objc.sendVoid0(residency_set, try sel("endResidency"));
}

pub fn addCommandQueueResidencySet(command_queue: objc.Id, residency_set: objc.Id) Error!void {
    objc.sendVoidId(command_queue, try sel("addResidencySet:"), residency_set);
}

pub fn removeCommandQueueResidencySet(command_queue: objc.Id, residency_set: objc.Id) Error!void {
    objc.sendVoidId(command_queue, try sel("removeResidencySet:"), residency_set);
}

pub fn createSharedEvent(device: objc.Id) Error!objc.Id {
    return objc.sendId0(device, try sel("newSharedEvent")) orelse Error.SharedEventCreationFailed;
}

pub fn bindArgumentTableBufferAddress(argument_table: objc.Id, address: MTLGPUAddress, index: objc.NSUInteger) Error!void {
    objc.sendVoidU64USize(argument_table, try sel("setAddress:atIndex:"), address, index);
}

pub fn queryDeviceCapabilities(device: objc.Id) Error!DeviceCapabilities {
    const unified_sel = objc.selector("hasUnifiedMemory") orelse return Error.MissingSelector;
    const working_set_sel = objc.selector("recommendedMaxWorkingSetSize") orelse return Error.MissingSelector;

    return .{
        .has_unified_memory = objc.sendBool0(device, unified_sel),
        .supports_metal4 = try supportsFamily(device, .metal4),
        .highest_apple_family = try highestAppleFamily(device),
        .recommended_max_working_set_size = objc.sendU64_0(device, working_set_sel),
    };
}

pub fn validateTargetDevice(caps: DeviceCapabilities, profile: TargetProfile) Error!void {
    if (profile.require_unified_memory and !caps.has_unified_memory) return Error.UnsupportedDevice;
    if (profile.require_metal4 and !caps.supports_metal4) return Error.UnsupportedDevice;
    if (!caps.supportsAppleFamilyAtLeast(profile.minimum_apple_family)) return Error.UnsupportedDevice;
}

pub fn supportsFamily(device: objc.Id, family: GPUFamily) Error!bool {
    return objc.sendBoolISize(device, try sel("supportsFamily:"), @intFromEnum(family));
}

pub fn highestAppleFamily(device: objc.Id) Error!?GPUFamily {
    const families = [_]GPUFamily{
        .apple10,
        .apple9,
        .apple8,
        .apple7,
        .apple6,
        .apple5,
        .apple4,
        .apple3,
        .apple2,
        .apple1,
    };

    for (families) |family| {
        if (try supportsFamily(device, family)) return family;
    }
    return null;
}

fn sel(name: [*:0]const u8) Error!objc.Sel {
    return objc.selector(name) orelse Error.MissingSelector;
}

fn releaseObject(object: objc.Id) void {
    const release_sel = objc.selector("release") orelse return;
    objc.sendVoid0(object, release_sel);
}

test "Metal layer constants match the macOS ABI surface" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(objc.CGFloat));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(objc.CGSize));
    try std.testing.expectEqual(@as(objc.NSUInteger, 80), @intFromEnum(PixelFormat.bgra8_unorm));
    try std.testing.expectEqual(@as(objc.CAAutoresizingMask, 18), ca_layer_width_sizable | ca_layer_height_sizable);
    try std.testing.expectEqual(@as(objc.NSUInteger, 1), shared_write_combined_buffer_options);
}

test "developer target profile is intentionally Apple Silicon forward" {
    try std.testing.expect(developer_target_profile.require_unified_memory);
    try std.testing.expect(developer_target_profile.require_metal4);
    try std.testing.expectEqual(GPUFamily.apple10, developer_target_profile.minimum_apple_family);
    try std.testing.expectEqual(@as(objc.NSInteger, 5002), @intFromEnum(GPUFamily.metal4));
}
