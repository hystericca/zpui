const std = @import("std");

const mtl = @import("zmtl4");
const macos_text = @import("platform/macos_text.zig");
const text = @import("text.zig");
const ui_frame = @import("frame.zig");
const render = @import("render.zig");

pub const ObjCId = mtl.runtime.Id;

const fallback_allocator = std.heap.page_allocator;

pub const Error = mtl.Error || error{
    InvalidDevice,
    InvalidSurface,
    ShaderLibraryCreationFailed,
    FrameEncodingFailed,
    FrameWaitTimedOut,
    InvalidClipRect,
    OutOfMemory,
} || macos_text.Error;

pub const max_frames_in_flight = 3;
pub const frame_quad_cap = render.max_quads;
pub const frame_buf_len = @sizeOf(render.FrameData);
pub const text_frame_buf_len = @sizeOf(render.TextFrameData);
const frame_wait_timeout_ms = 10;
const frame_drain_timeout_ms = 5_000;
const residency_allocation_cap = max_frames_in_flight * 2 + 1;

extern fn zpui_platform_create_shader_library(device: ObjCId) ObjCId;

const GpuFrame = struct {
    buf: mtl.resource.OwnedBuffer,
    data: *render.FrameData,
    addr: mtl.abi.GPUAddress,
    text_buf: mtl.resource.OwnedBuffer,
    text_data: *render.TextFrameData,
    text_addr: mtl.abi.GPUAddress,

    fn deinit(frame: *GpuFrame) void {
        frame.text_buf.deinit();
        frame.buf.deinit();
    }
};

const Draw = struct {
    clear_color: mtl.abi.ClearColor,
    draw_vertex_count: u32,
    batch_count: u32,
    text_vertex_count: u32,
};

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
    shader_library_creation_failed = 29,
    compiler_descriptor_creation_failed = 30,
    compiler_creation_failed = 31,
    function_descriptor_creation_failed = 32,
    string_creation_failed = 33,
    pipeline_descriptor_creation_failed = 34,
    pipeline_creation_failed = 35,
    render_pass_descriptor_creation_failed = 36,
    render_attachment_descriptor_creation_failed = 37,
    render_encoder_creation_failed = 38,
    drawable_texture_unavailable = 39,
    invalid_drawable_size = 40,
    invalid_scale = 41,
    frame_wait_timed_out = 42,
    invalid_clip_rect = 43,
    object_creation_failed = 44,
    system_default_device_unavailable = 45,
    invalid_drawable_count = 46,
    drawable_unavailable = 47,
    too_many_items = 48,
    font_atlas_creation_failed = 49,
    texture_descriptor_creation_failed = 50,
    texture_creation_failed = 51,
    invalid_texture_size = 52,
    sampler_descriptor_creation_failed = 53,
    sampler_state_creation_failed = 54,

    pub fn fromError(err: Error) Status {
        return switch (err) {
            Error.InvalidDevice => .invalid_device,
            Error.InvalidSurface => .invalid_surface,
            Error.MissingClass => .missing_class,
            Error.ObjectCreationFailed => .object_creation_failed,
            Error.RetainFailed => .retain_failed,
            Error.SystemDefaultDeviceUnavailable => .system_default_device_unavailable,
            Error.UnsupportedDevice => .unsupported_device,
            Error.CommandQueueCreationFailed => .command_queue_creation_failed,
            Error.CommandAllocatorCreationFailed => .command_allocator_creation_failed,
            Error.CommandBufferCreationFailed => .command_buffer_creation_failed,
            Error.CommandEncoderCreationFailed => .render_encoder_creation_failed,
            Error.BufferCreationFailed => .buffer_creation_failed,
            Error.BufferContentsUnavailable => .buffer_contents_unavailable,
            Error.TextureDescriptorCreationFailed => .texture_descriptor_creation_failed,
            Error.TextureCreationFailed => .texture_creation_failed,
            Error.InvalidTextureSize => .invalid_texture_size,
            Error.SamplerDescriptorCreationFailed => .sampler_descriptor_creation_failed,
            Error.SamplerStateCreationFailed => .sampler_state_creation_failed,
            Error.ArgumentTableDescriptorCreationFailed => .argument_table_descriptor_creation_failed,
            Error.ArgumentTableCreationFailed => .argument_table_creation_failed,
            Error.ResidencySetDescriptorCreationFailed => .residency_set_descriptor_creation_failed,
            Error.ResidencySetCreationFailed => .residency_set_creation_failed,
            Error.SharedEventCreationFailed => .shared_event_creation_failed,
            Error.InvalidDrawableSize => .invalid_drawable_size,
            Error.InvalidDrawableCount => .invalid_drawable_count,
            Error.InvalidScale => .invalid_scale,
            Error.LayerCreationFailed => .layer_allocation_failed,
            Error.DrawableUnavailable => .drawable_unavailable,
            Error.DrawableTextureUnavailable => .drawable_texture_unavailable,
            Error.RenderPassDescriptorCreationFailed => .render_pass_descriptor_creation_failed,
            Error.RenderAttachmentDescriptorUnavailable => .render_attachment_descriptor_creation_failed,
            Error.CompilerDescriptorCreationFailed => .compiler_descriptor_creation_failed,
            Error.CompilerCreationFailed => .compiler_creation_failed,
            Error.FunctionDescriptorCreationFailed => .function_descriptor_creation_failed,
            Error.PipelineDescriptorCreationFailed => .pipeline_descriptor_creation_failed,
            Error.PipelineCreationFailed => .pipeline_creation_failed,
            Error.TooManyItems => .too_many_items,
            Error.ShaderLibraryCreationFailed => .shader_library_creation_failed,
            Error.FrameEncodingFailed => .frame_encoding_failed,
            Error.FrameWaitTimedOut => .frame_wait_timed_out,
            Error.InvalidClipRect => .invalid_clip_rect,
            Error.OutOfMemory => .out_of_memory,
            Error.FontAtlasCreationFailed => .font_atlas_creation_failed,
        };
    }
};

pub const Surface = struct {
    allocator: std.mem.Allocator,
    device: mtl.OwnedDevice,
    layer: mtl.layer.OwnedLayer,
    command_queue: mtl.command.OwnedCommandQueue,
    command_buffer: mtl.command.OwnedCommandBuffer,
    pipeline_state: mtl.render.OwnedRenderPipelineState,
    text_pipeline_state: mtl.render.OwnedRenderPipelineState,
    command_allocators: [max_frames_in_flight]mtl.command.OwnedCommandAllocator,
    frames: [max_frames_in_flight]GpuFrame,
    frame_storage: ui_frame.Storage = .{},
    text_font: text.Font = .{},
    text_atlas: text.AtlasStorage = .{},
    text_texture: mtl.resource.OwnedTexture,
    text_sampler: mtl.resource.OwnedSamplerState,
    argument_table: mtl.resource.OwnedArgumentTable,
    residency_set: mtl.resource.OwnedResidencySet,
    layer_residency_set: ?mtl.layer.LayerResidencySet,
    frame_event: mtl.resource.OwnedSharedEvent,
    caps: mtl.runtime.DeviceCapabilities,
    current_frame_index: u64 = max_frames_in_flight,
    drawable_size: mtl.abi.Size2D = .{ .width = 0, .height = 0 },
    scale: mtl.abi.CGFloat = 1.0,
    resize_generation: u64 = 0,
    config: mtl.layer.Config,

    pub fn create(device: ObjCId, config: mtl.layer.Config) Error!*Surface {
        return createWithAllocator(fallback_allocator, device, config);
    }

    pub fn createWithAllocator(alloc: std.mem.Allocator, device: ObjCId, config: mtl.layer.Config) Error!*Surface {
        const device_ref = mtl.Device.fromRaw(device orelse return Error.InvalidDevice);
        var owned_device = try mtl.retain(.device, device_ref);
        errdefer owned_device.deinit();

        const caps = try mtl.queryDeviceCapabilities(owned_device.ref());
        try mtl.validateTargetDevice(caps, mtl.runtime.developer_target_profile);

        var layer = try mtl.layer.create(owned_device.ref(), config);
        errdefer layer.deinit();
        const layer_residency_set = mtl.layer.residencySet(layer.ref());

        var command_queue = try mtl.command.createQueue(owned_device.ref());
        errdefer command_queue.deinit();

        var command_buffer = try mtl.command.createCommandBuffer(owned_device.ref());
        errdefer command_buffer.deinit();

        var pipeline_state = try createSolidQuadPipeline(owned_device.ref(), config.pixel_format);
        errdefer pipeline_state.deinit();

        var text_pipeline_state = try createTextPipeline(owned_device.ref(), config.pixel_format);
        errdefer text_pipeline_state.deinit();

        var command_allocators: [max_frames_in_flight]mtl.command.OwnedCommandAllocator = undefined;
        var allocator_count: usize = 0;
        errdefer {
            for (command_allocators[0..allocator_count]) |*command_allocator| {
                command_allocator.deinit();
            }
        }
        while (allocator_count < command_allocators.len) : (allocator_count += 1) {
            command_allocators[allocator_count] = try mtl.command.createAllocator(owned_device.ref());
        }

        var text_font: text.Font = .{};
        var text_atlas: text.AtlasStorage = .{};
        try macos_text.buildAsciiAtlas(&text_font, &text_atlas, "JetBrains Mono", 13.0, 2.0);

        var text_texture = try createTextTexture(owned_device.ref(), &text_atlas);
        errdefer text_texture.deinit();

        var text_sampler = try mtl.resource.createSamplerState(owned_device.ref(), .{});
        errdefer text_sampler.deinit();

        var residency_set = try mtl.resource.createResidencySetWithCapacity(owned_device.ref(), residency_allocation_cap);
        errdefer residency_set.deinit();

        var frames: [max_frames_in_flight]GpuFrame = undefined;
        var frame_count: usize = 0;
        errdefer {
            for (frames[0..frame_count]) |*frame| {
                frame.deinit();
            }
        }
        while (frame_count < frames.len) {
            frames[frame_count] = try createFrame(owned_device.ref());
            const buf = frames[frame_count].buf;
            const text_buf = frames[frame_count].text_buf;
            frame_count += 1;
            mtl.resource.addAllocation(residency_set.ref(), mtl.runtime.Object.fromRaw(buf.raw));
            mtl.resource.addAllocation(residency_set.ref(), mtl.runtime.Object.fromRaw(text_buf.raw));
        }
        mtl.resource.addAllocation(residency_set.ref(), mtl.runtime.Object.fromRaw(text_texture.raw));
        mtl.resource.commit(residency_set.ref());
        mtl.resource.requestResidency(residency_set.ref());
        errdefer mtl.resource.endResidency(residency_set.ref());
        mtl.command.addResidencySet(command_queue.ref(), residency_set.ref());
        errdefer mtl.command.removeResidencySet(command_queue.ref(), residency_set.ref());

        var argument_table = try mtl.resource.createArgumentTableWithConfig(owned_device.ref(), .{
            .max_buffer_bind_count = 2,
            .max_texture_bind_count = 1,
            .max_sampler_state_bind_count = 1,
        });
        errdefer argument_table.deinit();
        mtl.resource.setTexture(argument_table.ref(), mtl.resource.gpuResourceId(text_texture.ref()), 0);
        mtl.resource.setSamplerState(argument_table.ref(), mtl.resource.gpuResourceIdSampler(text_sampler.ref()), 0);

        var frame_event = try mtl.resource.createSharedEvent(owned_device.ref());
        errdefer frame_event.deinit();
        mtl.resource.setSignaledValue(frame_event.ref(), max_frames_in_flight - 1);

        const surface = alloc.create(Surface) catch return Error.OutOfMemory;
        surface.* = .{
            .allocator = alloc,
            .device = owned_device,
            .layer = layer,
            .command_queue = command_queue,
            .command_buffer = command_buffer,
            .pipeline_state = pipeline_state,
            .text_pipeline_state = text_pipeline_state,
            .command_allocators = command_allocators,
            .frames = frames,
            .frame_storage = .{},
            .text_font = text_font,
            .text_atlas = text_atlas,
            .text_texture = text_texture,
            .text_sampler = text_sampler,
            .argument_table = argument_table,
            .residency_set = residency_set,
            .layer_residency_set = layer_residency_set,
            .frame_event = frame_event,
            .caps = caps,
            .config = config,
        };
        return surface;
    }

    pub fn destroy(surface: *Surface) void {
        const alloc = surface.allocator;
        surface.drain();
        mtl.command.removeResidencySet(surface.command_queue.ref(), surface.residency_set.ref());
        mtl.resource.endResidency(surface.residency_set.ref());

        for (&surface.command_allocators) |*command_allocator| {
            command_allocator.deinit();
        }
        surface.argument_table.deinit();
        surface.residency_set.deinit();
        for (&surface.frames) |*frame| {
            frame.deinit();
        }
        surface.frame_event.deinit();
        surface.text_sampler.deinit();
        surface.text_texture.deinit();
        surface.text_pipeline_state.deinit();
        surface.pipeline_state.deinit();
        surface.command_buffer.deinit();
        surface.command_queue.deinit();
        surface.layer.deinit();
        surface.device.deinit();
        alloc.destroy(surface);
    }

    pub fn resize(surface: *Surface, drawable_size: mtl.abi.Size2D, scale: mtl.abi.CGFloat) Error!void {
        try mtl.layer.resize(surface.layer.ref(), drawable_size, scale);
        const scale32: f32 = @floatCast(scale);
        if (surface.text_font.metrics.scale != scale32) {
            var next_font: text.Font = .{};
            var next_atlas: text.AtlasStorage = .{};
            try macos_text.buildAsciiAtlas(&next_font, &next_atlas, "JetBrains Mono", 13.0, scale32);
            surface.text_font = next_font;
            surface.text_atlas = next_atlas;
            uploadTextAtlas(surface.text_texture.ref(), &surface.text_atlas);
        }
        surface.drawable_size = drawable_size;
        surface.scale = scale;
        surface.resize_generation +%= 1;
    }

    pub fn nextCommandAllocator(surface: *Surface) Error!mtl.command.CommandAllocator {
        const allocator_index = surface.current_frame_index % max_frames_in_flight;
        const wait_value = surface.current_frame_index - max_frames_in_flight;
        if (!mtl.resource.waitUntilSignaledValue(surface.frame_event.ref(), wait_value, frame_wait_timeout_ms)) {
            return Error.FrameWaitTimedOut;
        }

        const command_allocator = surface.command_allocators[@intCast(allocator_index)].ref();
        mtl.command.resetAllocator(command_allocator);
        return command_allocator;
    }

    pub fn drain(surface: *Surface) void {
        const last_submitted_frame = surface.current_frame_index - 1;
        _ = mtl.resource.waitUntilSignaledValue(surface.frame_event.ref(), last_submitted_frame, frame_drain_timeout_ms);
    }

    pub fn signalFrameCompletion(surface: *Surface) void {
        mtl.command.signalEvent(surface.command_queue.ref(), surface.frame_event.ref(), surface.current_frame_index);
        surface.current_frame_index +%= 1;
    }

    pub fn drawScene(surface: *Surface, scene: *const render.Scene, drawable_id: ObjCId) Error!void {
        const drawable = mtl.layer.Drawable.fromRaw(drawable_id orelse return Error.DrawableUnavailable);
        const command_allocator = try surface.nextCommandAllocator();
        const prepared = try surface.prepareScene(scene);
        const drawable_texture = try mtl.layer.drawableTexture(drawable);
        var pass_descriptor = try mtl.render.createColorPassDescriptor(drawable_texture, prepared.clear_color);
        defer pass_descriptor.deinit();

        mtl.command.begin(surface.command_buffer.ref(), command_allocator);
        var command_buffer_open = true;
        errdefer if (command_buffer_open) mtl.command.end(surface.command_buffer.ref());
        surface.useFrameResidency();

        const encoder = try mtl.render.renderCommandEncoder(surface.command_buffer.ref(), pass_descriptor.ref());
        var encoder_open = true;
        errdefer if (encoder_open) mtl.render.endEncoding(encoder);
        mtl.render.setViewport(encoder, .{
            .origin_x = 0.0,
            .origin_y = 0.0,
            .width = surface.drawable_size.width,
            .height = surface.drawable_size.height,
            .z_near = 0.0,
            .z_far = 1.0,
        });
        mtl.render.setArgumentTable(
            encoder,
            surface.argument_table.ref(),
            mtl.abi.render_stage_vertex | mtl.abi.render_stage_fragment,
        );

        if (prepared.draw_vertex_count > 0 and prepared.batch_count > 0) {
            mtl.render.setPipelineState(encoder, surface.pipeline_state.ref());
            for (scene.batches) |batch| {
                const clip = scene.clips[@intCast(batch.clip_index)];
                mtl.render.setScissorRect(encoder, .{
                    .x = clip.x,
                    .y = clip.y,
                    .width = clip.width,
                    .height = clip.height,
                });
                mtl.render.drawPrimitives(
                    encoder,
                    .triangle,
                    @intCast(batch.vertex_start),
                    @intCast(batch.vertex_count),
                );
            }
        }

        if (prepared.text_vertex_count > 0) {
            mtl.render.setPipelineState(encoder, surface.text_pipeline_state.ref());
            mtl.render.setScissorRect(encoder, try drawableScissor(surface.drawable_size));
            mtl.render.drawPrimitives(
                encoder,
                .triangle,
                0,
                @intCast(prepared.text_vertex_count),
            );
        }

        mtl.render.endEncoding(encoder);
        encoder_open = false;
        mtl.command.end(surface.command_buffer.ref());
        command_buffer_open = false;

        mtl.command.waitForDrawable(surface.command_queue.ref(), drawable);
        mtl.command.commitOne(surface.command_queue.ref(), surface.command_buffer.ref());
        surface.signalFrameCompletion();
        mtl.command.signalDrawable(surface.command_queue.ref(), drawable);
        mtl.layer.present(drawable);
    }

    fn prepareScene(surface: *Surface, scene: *const render.Scene) Error!Draw {
        const frame_slot = surface.currentFrameSlot();
        const frame = &surface.frames[frame_slot];

        const compiled = render.compileScene(scene, frame.data) catch return Error.FrameEncodingFailed;
        const text_compiled = render.compileText(scene, frame.text_data) catch return Error.FrameEncodingFailed;
        if (compiled.quad_count > frame_quad_cap) return Error.BufferCreationFailed;

        mtl.resource.setAddress(surface.argument_table.ref(), frame.addr, 0);
        mtl.resource.setAddress(surface.argument_table.ref(), frame.text_addr, 1);

        if (compiled.draw_vertex_count > 0 and compiled.batch_count > 0) {
            for (scene.batches) |batch| {
                const clip = scene.clips[@intCast(batch.clip_index)];
                try validateClipRect(clip, surface.drawable_size);
            }
        }
        if (text_compiled.draw_vertex_count > 0) {
            _ = try drawableScissor(surface.drawable_size);
        }
        return .{
            .clear_color = toClearColor(scene.clear_color),
            .draw_vertex_count = compiled.draw_vertex_count,
            .batch_count = compiled.batch_count,
            .text_vertex_count = text_compiled.draw_vertex_count,
        };
    }

    fn currentFrameSlot(surface: *const Surface) usize {
        return @intCast(surface.current_frame_index % max_frames_in_flight);
    }

    fn useFrameResidency(surface: *Surface) void {
        mtl.command.useResidencySet(surface.command_buffer.ref(), surface.residency_set.ref());
        if (surface.layer_residency_set) |layer_residency_set| {
            mtl.command.useLayerResidencySet(surface.command_buffer.ref(), layer_residency_set);
        }
    }
};

fn createSolidQuadPipeline(
    device: mtl.Device,
    pixel_format: mtl.abi.PixelFormat,
) Error!mtl.render.OwnedRenderPipelineState {
    var library = mtl.render.OwnedLibrary.fromRaw(
        zpui_platform_create_shader_library(device.raw) orelse return Error.ShaderLibraryCreationFailed,
    );
    defer library.deinit();

    return mtl.render.createPipelineStateFromLibrary(device, library.ref(), "zpui_vertex", "zpui_fragment", .{
        .pixel_format = pixel_format,
    });
}

fn createTextPipeline(
    device: mtl.Device,
    pixel_format: mtl.abi.PixelFormat,
) Error!mtl.render.OwnedRenderPipelineState {
    var library = mtl.render.OwnedLibrary.fromRaw(
        zpui_platform_create_shader_library(device.raw) orelse return Error.ShaderLibraryCreationFailed,
    );
    defer library.deinit();

    return mtl.render.createPipelineStateFromLibrary(device, library.ref(), "zpui_text_vertex", "zpui_text_fragment", .{
        .pixel_format = pixel_format,
        .blend = .{ .enabled = true },
    });
}

fn createFrame(device: mtl.Device) Error!GpuFrame {
    var buf = try mtl.resource.createBuffer(
        device,
        frame_buf_len,
        mtl.abi.shared_write_combined_buffer_options,
    );
    errdefer buf.deinit();

    var text_buf = try mtl.resource.createBuffer(
        device,
        text_frame_buf_len,
        mtl.abi.shared_write_combined_buffer_options,
    );
    errdefer text_buf.deinit();

    return .{
        .buf = buf,
        .data = try bufferContentsAs(buf.ref(), render.FrameData),
        .addr = mtl.resource.gpuAddress(buf.ref()),
        .text_buf = text_buf,
        .text_data = try bufferContentsAs(text_buf.ref(), render.TextFrameData),
        .text_addr = mtl.resource.gpuAddress(text_buf.ref()),
    };
}

fn bufferContentsAs(buffer: mtl.resource.Buffer, comptime T: type) Error!*T {
    const bytes = try mtl.resource.contents(buffer);
    return @ptrCast(@alignCast(bytes));
}

fn createTextTexture(device: mtl.Device, atlas: *const text.AtlasStorage) Error!mtl.resource.OwnedTexture {
    var texture = try mtl.resource.createTexture(device, .{
        .width = text.atlas_width,
        .height = text.atlas_height,
        .pixel_format = .r8_unorm,
        .usage = mtl.abi.texture_usage_shader_read,
        .storage_mode = .shared,
    });
    errdefer texture.deinit();

    uploadTextAtlas(texture.ref(), atlas);
    return texture;
}

fn uploadTextAtlas(texture: mtl.resource.Texture, atlas: *const text.AtlasStorage) void {
    mtl.resource.replaceRegion(
        texture,
        .{
            .origin = .{ .x = 0, .y = 0, .z = 0 },
            .size = .{ .width = text.atlas_width, .height = text.atlas_height, .depth = 1 },
        },
        0,
        atlas.bytes[0..].ptr,
        text.atlas_width,
    );
}

fn validateClipRect(clip: render.ClipRect, drawable_size: mtl.abi.Size2D) Error!void {
    if (clip.width == 0 or clip.height == 0) return Error.InvalidClipRect;

    const drawable_width = try drawableExtent(drawable_size.width);
    const drawable_height = try drawableExtent(drawable_size.height);
    if (clip.x > drawable_width or clip.width > drawable_width - clip.x) return Error.InvalidClipRect;
    if (clip.y > drawable_height or clip.height > drawable_height - clip.y) return Error.InvalidClipRect;
}

fn drawableScissor(drawable_size: mtl.abi.Size2D) Error!mtl.abi.ScissorRect {
    return .{
        .x = 0,
        .y = 0,
        .width = try drawableExtent(drawable_size.width),
        .height = try drawableExtent(drawable_size.height),
    };
}

fn drawableExtent(value: f64) Error!u32 {
    if (value <= 0) return Error.InvalidDrawableSize;
    const floored = @floor(value);
    if (floored <= 0) return Error.InvalidDrawableSize;
    const capped = @min(floored, @as(f64, @floatFromInt(std.math.maxInt(u32))));
    return @intFromFloat(capped);
}

fn toClearColor(color: [4]f64) mtl.abi.ClearColor {
    return .{
        .red = color[0],
        .green = color[1],
        .blue = color[2],
        .alpha = color[3],
    };
}

pub export fn zpui_surface_create(device: ObjCId, out_surface: *?*Surface) c_int {
    out_surface.* = null;
    const surface = Surface.create(device, .{}) catch |err| {
        return @intFromEnum(Status.fromError(err));
    };
    out_surface.* = surface;
    return @intFromEnum(Status.ok);
}

pub export fn zpui_surface_destroy(surface: ?*Surface) void {
    const unwrapped_surface = surface orelse return;
    unwrapped_surface.destroy();
}

pub export fn zpui_surface_layer(surface: ?*Surface) ObjCId {
    const unwrapped_surface = surface orelse return null;
    return unwrapped_surface.layer.raw;
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

test "surface status values stay stable across the Objective-C ABI" {
    try std.testing.expectEqual(@as(c_int, 0), @intFromEnum(Status.ok));
    try std.testing.expectEqual(@as(c_int, 10), @intFromEnum(Status.invalid_device));
    try std.testing.expectEqual(@as(c_int, 39), @intFromEnum(Status.drawable_texture_unavailable));
    try std.testing.expectEqual(@as(c_int, 40), @intFromEnum(Status.invalid_drawable_size));
    try std.testing.expectEqual(@as(c_int, 48), @intFromEnum(Status.too_many_items));
    try std.testing.expectEqual(Status.invalid_drawable_size, Status.fromError(Error.InvalidDrawableSize));
    try std.testing.expectEqual(Status.invalid_scale, Status.fromError(Error.InvalidScale));
    try std.testing.expectEqual(Status.invalid_device, Status.fromError(Error.InvalidDevice));
    try std.testing.expectEqual(Status.invalid_surface, Status.fromError(Error.InvalidSurface));
    try std.testing.expectEqual(Status.unsupported_device, Status.fromError(Error.UnsupportedDevice));
    try std.testing.expectEqual(Status.pipeline_creation_failed, Status.fromError(Error.PipelineCreationFailed));
    try std.testing.expectEqual(Status.texture_creation_failed, Status.fromError(Error.TextureCreationFailed));
    try std.testing.expectEqual(Status.sampler_state_creation_failed, Status.fromError(Error.SamplerStateCreationFailed));
    try std.testing.expectEqual(Status.invalid_texture_size, Status.fromError(Error.InvalidTextureSize));
    try std.testing.expectEqual(Status.frame_encoding_failed, Status.fromError(Error.FrameEncodingFailed));
    try std.testing.expectEqual(Status.frame_wait_timed_out, Status.fromError(Error.FrameWaitTimedOut));
    try std.testing.expectEqual(Status.invalid_clip_rect, Status.fromError(Error.InvalidClipRect));
    try std.testing.expectEqual(Status.render_encoder_creation_failed, Status.fromError(Error.CommandEncoderCreationFailed));
    try std.testing.expectEqual(Status.out_of_memory, Status.fromError(Error.OutOfMemory));
}

test "surface clip validation rejects scissors outside the drawable" {
    try validateClipRect(.{ .x = 0, .y = 0, .width = 640, .height = 480 }, .{ .width = 640, .height = 480 });
    try std.testing.expectError(Error.InvalidClipRect, validateClipRect(.{ .x = 0, .y = 0, .width = 641, .height = 480 }, .{ .width = 640, .height = 480 }));
    try std.testing.expectError(Error.InvalidClipRect, validateClipRect(.{ .x = 640, .y = 0, .width = 1, .height = 480 }, .{ .width = 640, .height = 480 }));
    try std.testing.expectError(Error.InvalidClipRect, validateClipRect(.{ .x = 0, .y = 0, .width = 0, .height = 480 }, .{ .width = 640, .height = 480 }));
    try std.testing.expectError(Error.InvalidDrawableSize, validateClipRect(.{ .x = 0, .y = 0, .width = 1, .height = 1 }, .{ .width = 0, .height = 480 }));
}

test "surface frame buffer capacity matches the scene contract" {
    try std.testing.expectEqual(@as(usize, render.max_quads), frame_quad_cap);
    try std.testing.expectEqual(@sizeOf(render.FrameData), frame_buf_len);
    try std.testing.expectEqual(@sizeOf(render.TextFrameData), text_frame_buf_len);
    try std.testing.expectEqual(@as(usize, max_frames_in_flight * 2 + 1), residency_allocation_cap);
}
