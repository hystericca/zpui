const std = @import("std");

const metal = @import("gpu/metal.zig");
const objc = @import("objc.zig");
const render = @import("render.zig");

const allocator = std.heap.page_allocator;

pub const Error = error{
    InvalidDevice,
    InvalidSurface,
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
    FrameEncodingFailed,
    RetainFailed,
    OutOfMemory,
};

pub const max_frames_in_flight = 3;
pub const vertex_buffer_capacity = render.max_vertices;
pub const vertex_buffer_byte_len = @sizeOf(render.Vertex) * vertex_buffer_capacity;
const frame_drain_timeout_ms = 5_000;

const FrameResources = struct {
    vertex_buffer: objc.Id,
    vertex_buffer_contents: [*]u8,
    vertex_buffer_gpu_address: metal.MTLGPUAddress,
};

pub const PreparedFrame = extern struct {
    clear_color: [4]f64,
    vertex_count: u32,
    batch_count: u32,
    scissor_x: u32,
    scissor_y: u32,
    scissor_width: u32,
    scissor_height: u32,
    reserved: [2]u32 = .{ 0, 0 },
};

pub fn emptyPreparedFrame() PreparedFrame {
    return .{
        .clear_color = .{ 0, 0, 0, 1 },
        .vertex_count = 0,
        .batch_count = 0,
        .scissor_x = 0,
        .scissor_y = 0,
        .scissor_width = 0,
        .scissor_height = 0,
    };
}

pub const Status = enum(c_int) {
    ok = 0,
    invalid_device = 10,
    invalid_surface = 11,
    missing_class = 12,
    missing_selector = 13,
    layer_allocation_failed = 14,
    retain_failed = 15,
    out_of_memory = 16,
    command_queue_creation_failed = 17,
    unsupported_device = 18,
    command_allocator_creation_failed = 19,
    command_buffer_creation_failed = 20,
    buffer_creation_failed = 21,
    buffer_contents_unavailable = 22,
    argument_table_descriptor_creation_failed = 23,
    argument_table_creation_failed = 24,
    shared_event_creation_failed = 25,
    residency_set_descriptor_creation_failed = 26,
    residency_set_creation_failed = 27,
    frame_encoding_failed = 28,

    pub fn fromError(err: Error) Status {
        return switch (err) {
            Error.InvalidDevice => .invalid_device,
            Error.InvalidSurface => .invalid_surface,
            Error.MissingClass => .missing_class,
            Error.MissingSelector => .missing_selector,
            Error.UnsupportedDevice => .unsupported_device,
            Error.LayerAllocationFailed => .layer_allocation_failed,
            Error.CommandQueueCreationFailed => .command_queue_creation_failed,
            Error.CommandAllocatorCreationFailed => .command_allocator_creation_failed,
            Error.CommandBufferCreationFailed => .command_buffer_creation_failed,
            Error.BufferCreationFailed => .buffer_creation_failed,
            Error.BufferContentsUnavailable => .buffer_contents_unavailable,
            Error.ArgumentTableDescriptorCreationFailed => .argument_table_descriptor_creation_failed,
            Error.ArgumentTableCreationFailed => .argument_table_creation_failed,
            Error.ResidencySetDescriptorCreationFailed => .residency_set_descriptor_creation_failed,
            Error.ResidencySetCreationFailed => .residency_set_creation_failed,
            Error.SharedEventCreationFailed => .shared_event_creation_failed,
            Error.FrameEncodingFailed => .frame_encoding_failed,
            Error.RetainFailed => .retain_failed,
            Error.OutOfMemory => .out_of_memory,
        };
    }
};

pub const Surface = struct {
    device: objc.Id,
    layer: objc.Id,
    command_queue: objc.Id,
    command_buffer: objc.Id,
    command_allocators: [max_frames_in_flight]objc.Id,
    frame_resources: [max_frames_in_flight]FrameResources,
    argument_table: objc.Id,
    residency_set: objc.Id,
    frame_event: objc.Id,
    caps: metal.DeviceCapabilities,
    current_frame_index: u64 = max_frames_in_flight,
    drawable_size: objc.CGSize = .{ .width = 0, .height = 0 },
    scale: objc.CGFloat = 1.0,
    resize_generation: u64 = 0,
    config: metal.LayerConfig,

    pub fn create(device: objc.Id, config: metal.LayerConfig) Error!*Surface {
        const retained_device = try retainObject(device);
        errdefer releaseObject(retained_device);

        const caps = try metal.queryDeviceCapabilities(retained_device);
        try metal.validateTargetDevice(caps, metal.developer_target_profile);

        const layer = try metal.createLayer(retained_device, config);
        const retained_layer = try retainObject(layer);
        errdefer releaseObject(retained_layer);

        const command_queue = try metal.createMetal4CommandQueue(retained_device);
        errdefer releaseObject(command_queue);

        const command_buffer = try metal.createMetal4CommandBuffer(retained_device);
        errdefer releaseObject(command_buffer);

        var command_allocators: [max_frames_in_flight]objc.Id = undefined;
        var allocator_count: usize = 0;
        errdefer {
            for (command_allocators[0..allocator_count]) |command_allocator| {
                releaseObject(command_allocator);
            }
        }
        while (allocator_count < command_allocators.len) : (allocator_count += 1) {
            command_allocators[allocator_count] = try metal.createMetal4CommandAllocator(retained_device);
        }

        const residency_set = try metal.createResidencySet(retained_device, max_frames_in_flight);
        errdefer releaseObject(residency_set);

        var frame_resources: [max_frames_in_flight]FrameResources = undefined;
        var frame_resource_count: usize = 0;
        errdefer {
            for (frame_resources[0..frame_resource_count]) |frame_resource| {
                releaseObject(frame_resource.vertex_buffer);
            }
        }
        while (frame_resource_count < frame_resources.len) {
            frame_resources[frame_resource_count] = try createFrameResources(retained_device);
            const vertex_buffer = frame_resources[frame_resource_count].vertex_buffer;
            frame_resource_count += 1;
            try metal.addResidencyAllocation(residency_set, vertex_buffer);
        }
        try metal.commitResidencySet(residency_set);
        try metal.requestResidencySet(residency_set);
        errdefer metal.endResidencySet(residency_set) catch {};
        try metal.addCommandQueueResidencySet(command_queue, residency_set);
        errdefer metal.removeCommandQueueResidencySet(command_queue, residency_set) catch {};

        const argument_table = try metal.createMetal4ArgumentTable(retained_device, 1);
        errdefer releaseObject(argument_table);

        const frame_event = try metal.createSharedEvent(retained_device);
        errdefer releaseObject(frame_event);
        objc.sendVoidU64(frame_event, try sel("setSignaledValue:"), max_frames_in_flight - 1);

        const surface = allocator.create(Surface) catch return Error.OutOfMemory;
        surface.* = .{
            .device = retained_device,
            .layer = retained_layer,
            .command_queue = command_queue,
            .command_buffer = command_buffer,
            .command_allocators = command_allocators,
            .frame_resources = frame_resources,
            .argument_table = argument_table,
            .residency_set = residency_set,
            .frame_event = frame_event,
            .caps = caps,
            .config = config,
        };
        return surface;
    }

    pub fn destroy(surface: *Surface) void {
        surface.drain();
        metal.removeCommandQueueResidencySet(surface.command_queue, surface.residency_set) catch {};
        metal.endResidencySet(surface.residency_set) catch {};

        for (surface.command_allocators) |command_allocator| {
            releaseObject(command_allocator);
        }
        releaseObject(surface.argument_table);
        releaseObject(surface.residency_set);
        for (surface.frame_resources) |frame_resource| {
            releaseObject(frame_resource.vertex_buffer);
        }
        releaseObject(surface.frame_event);
        releaseObject(surface.command_buffer);
        releaseObject(surface.command_queue);
        releaseObject(surface.layer);
        releaseObject(surface.device);
        allocator.destroy(surface);
    }

    pub fn resize(surface: *Surface, drawable_size: objc.CGSize, scale: objc.CGFloat) Error!void {
        if (drawable_size.width <= 0 or drawable_size.height <= 0 or scale <= 0) return;

        try metal.resizeLayer(surface.layer, drawable_size, scale);
        surface.drawable_size = drawable_size;
        surface.scale = scale;
        surface.resize_generation +%= 1;
    }

    pub fn nextCommandAllocator(surface: *Surface) ?objc.Id {
        const allocator_index = surface.current_frame_index % max_frames_in_flight;
        const wait_value = surface.current_frame_index - max_frames_in_flight;
        const wait_sel = objc.selector("waitUntilSignaledValue:timeoutMS:") orelse return null;
        if (!objc.sendBoolU64U64(surface.frame_event, wait_sel, wait_value, 10)) return null;

        const command_allocator = surface.command_allocators[@intCast(allocator_index)];
        const reset_sel = objc.selector("reset") orelse return null;
        objc.sendVoid0(command_allocator, reset_sel);
        return command_allocator;
    }

    pub fn drain(surface: *Surface) void {
        const wait_sel = objc.selector("waitUntilSignaledValue:timeoutMS:") orelse return;
        const last_submitted_frame = surface.current_frame_index - 1;
        _ = objc.sendBoolU64U64(surface.frame_event, wait_sel, last_submitted_frame, frame_drain_timeout_ms);
    }

    pub fn signalFrameCompletion(surface: *Surface) Error!void {
        objc.sendVoidIdU64(
            surface.command_queue,
            try sel("signalEvent:value:"),
            surface.frame_event,
            surface.current_frame_index,
        );
        surface.current_frame_index +%= 1;
    }

    pub fn preparePacket(surface: *Surface, packet: *const render.RenderPacket, prepared: *PreparedFrame) Error!void {
        var vertices: [render.max_vertices]render.Vertex = undefined;
        const compiled = render.compilePacket(packet, &vertices) catch return Error.FrameEncodingFailed;
        if (compiled.vertex_count > vertex_buffer_capacity) return Error.BufferCreationFailed;

        const frame_slot = surface.currentFrameSlot();
        const frame_resource = surface.frame_resources[frame_slot];
        const byte_len = @as(usize, compiled.vertex_count) * @sizeOf(render.Vertex);
        const frame_vertices: [*]const u8 = @ptrCast(&vertices);
        @memcpy(frame_resource.vertex_buffer_contents[0..byte_len], frame_vertices[0..byte_len]);
        try metal.bindArgumentTableBufferAddress(surface.argument_table, frame_resource.vertex_buffer_gpu_address, 0);

        const clip = if (packet.clip_count > 0) packet.clips[0] else render.ClipRect{
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
        };
        prepared.* = .{
            .clear_color = packet.clear_color,
            .vertex_count = compiled.vertex_count,
            .batch_count = packet.batch_count,
            .scissor_x = clip.x,
            .scissor_y = clip.y,
            .scissor_width = clip.width,
            .scissor_height = clip.height,
        };
    }

    fn currentFrameSlot(surface: *const Surface) usize {
        return @intCast(surface.current_frame_index % max_frames_in_flight);
    }
};

fn retainObject(object: objc.Id) Error!objc.Id {
    const retain_sel = objc.selector("retain") orelse return Error.MissingSelector;
    return objc.sendId0(object, retain_sel) orelse Error.RetainFailed;
}

fn createFrameResources(device: objc.Id) Error!FrameResources {
    const vertex_buffer = try metal.createBuffer(
        device,
        vertex_buffer_byte_len,
        metal.shared_write_combined_buffer_options,
    );
    errdefer releaseObject(vertex_buffer);

    return .{
        .vertex_buffer = vertex_buffer,
        .vertex_buffer_contents = try metal.bufferContents(vertex_buffer),
        .vertex_buffer_gpu_address = try metal.bufferGpuAddress(vertex_buffer),
    };
}

fn releaseObject(object: objc.Id) void {
    const release_sel = objc.selector("release") orelse return;
    objc.sendVoid0(object, release_sel);
}

fn sel(name: [*:0]const u8) Error!objc.Sel {
    return objc.selector(name) orelse Error.MissingSelector;
}

pub export fn zpui_surface_create(device: ?objc.Id, out_surface: *?*Surface) c_int {
    out_surface.* = null;
    const unwrapped_device = device orelse return @intFromEnum(Status.invalid_device);

    const surface = Surface.create(unwrapped_device, .{}) catch |err| {
        return @intFromEnum(Status.fromError(err));
    };
    out_surface.* = surface;
    return @intFromEnum(Status.ok);
}

pub export fn zpui_surface_destroy(surface: ?*Surface) void {
    const unwrapped_surface = surface orelse return;
    unwrapped_surface.destroy();
}

pub export fn zpui_surface_layer(surface: ?*Surface) ?objc.Id {
    const unwrapped_surface = surface orelse return null;
    return unwrapped_surface.layer;
}

pub export fn zpui_surface_mtl4_command_queue(surface: ?*Surface) ?objc.Id {
    const unwrapped_surface = surface orelse return null;
    return unwrapped_surface.command_queue;
}

pub export fn zpui_surface_mtl4_command_buffer(surface: ?*Surface) ?objc.Id {
    const unwrapped_surface = surface orelse return null;
    return unwrapped_surface.command_buffer;
}

pub export fn zpui_surface_next_mtl4_command_allocator(surface: ?*Surface) ?objc.Id {
    const unwrapped_surface = surface orelse return null;
    return unwrapped_surface.nextCommandAllocator();
}

pub export fn zpui_surface_signal_frame_completion(surface: ?*Surface) c_int {
    const unwrapped_surface = surface orelse return @intFromEnum(Status.invalid_surface);
    unwrapped_surface.signalFrameCompletion() catch |err| {
        return @intFromEnum(Status.fromError(err));
    };
    return @intFromEnum(Status.ok);
}

pub export fn zpui_surface_argument_table(surface: ?*Surface) ?objc.Id {
    const unwrapped_surface = surface orelse return null;
    return unwrapped_surface.argument_table;
}

pub export fn zpui_surface_resize(surface: ?*Surface, width: f64, height: f64, scale: f64) c_int {
    const unwrapped_surface = surface orelse return @intFromEnum(Status.invalid_surface);
    unwrapped_surface.resize(
        .{ .width = width, .height = height },
        scale,
    ) catch |err| {
        return @intFromEnum(Status.fromError(err));
    };
    return @intFromEnum(Status.ok);
}

test "prepared frame layout stays stable across the Objective-C ABI" {
    try std.testing.expectEqual(@as(usize, 64), @sizeOf(PreparedFrame));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(PreparedFrame, "clear_color"));
    try std.testing.expectEqual(@as(usize, 32), @offsetOf(PreparedFrame, "vertex_count"));
    try std.testing.expectEqual(@as(usize, 36), @offsetOf(PreparedFrame, "batch_count"));
    try std.testing.expectEqual(@as(usize, 40), @offsetOf(PreparedFrame, "scissor_x"));
    try std.testing.expectEqual(@as(usize, 44), @offsetOf(PreparedFrame, "scissor_y"));
    try std.testing.expectEqual(@as(usize, 48), @offsetOf(PreparedFrame, "scissor_width"));
    try std.testing.expectEqual(@as(usize, 52), @offsetOf(PreparedFrame, "scissor_height"));
    try std.testing.expectEqual(@as(usize, 56), @offsetOf(PreparedFrame, "reserved"));
}

test "empty prepared frame has neutral draw defaults" {
    const prepared = emptyPreparedFrame();
    try std.testing.expectEqual([4]f64{ 0, 0, 0, 1 }, prepared.clear_color);
    try std.testing.expectEqual(@as(u32, 0), prepared.vertex_count);
    try std.testing.expectEqual(@as(u32, 0), prepared.batch_count);
    try std.testing.expectEqual(@as(u32, 0), prepared.scissor_width);
    try std.testing.expectEqual(@as(u32, 0), prepared.scissor_height);
}

test "surface status values stay stable across the Objective-C ABI" {
    try std.testing.expectEqual(@as(c_int, 0), @intFromEnum(Status.ok));
    try std.testing.expectEqual(@as(c_int, 10), @intFromEnum(Status.invalid_device));
    try std.testing.expectEqual(@as(c_int, 28), @intFromEnum(Status.frame_encoding_failed));
    try std.testing.expectEqual(Status.invalid_device, Status.fromError(Error.InvalidDevice));
    try std.testing.expectEqual(Status.invalid_surface, Status.fromError(Error.InvalidSurface));
    try std.testing.expectEqual(Status.unsupported_device, Status.fromError(Error.UnsupportedDevice));
    try std.testing.expectEqual(Status.frame_encoding_failed, Status.fromError(Error.FrameEncodingFailed));
    try std.testing.expectEqual(Status.out_of_memory, Status.fromError(Error.OutOfMemory));
}

test "surface vertex buffer capacity matches the render packet contract" {
    try std.testing.expectEqual(@as(usize, render.max_vertices), vertex_buffer_capacity);
    try std.testing.expectEqual(@as(usize, 1536), vertex_buffer_byte_len);
    try std.testing.expectEqual(@sizeOf(render.Vertex) * vertex_buffer_capacity, vertex_buffer_byte_len);
}
