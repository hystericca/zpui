const std = @import("std");

const mtl = @import("zmtl4");
const mask = @import("mask.zig");
const macos_text = @import("platform/macos_text.zig");
const text = @import("text.zig");
const ui_frame = @import("frame.zig");
const scene = @import("scene.zig");

pub const ObjCId = mtl.runtime.Id;

const fallback_allocator = std.heap.page_allocator;

pub const Error = mtl.Error || error{
    InvalidDevice,
    InvalidSurface,
    ShaderLibraryCreationFailed,
    FrameEncodingFailed,
    FrameWaitTimedOut,
    InvalidClipRect,
    InvalidFontOptions,
    InvalidFontSlot,
    OutOfMemory,
} || mask.Error || macos_text.Error;

pub const max_frames_in_flight = 3;
pub const frame_quad_cap = scene.max_quads;
pub const frame_buf_len = @sizeOf(scene.FrameData);
pub const text_frame_buf_len = @sizeOf(scene.TextFrameData);
pub const mask_frame_buf_len = @sizeOf(scene.MaskFrameData);
pub const font_slot_count = text.max_font_slots;
const frame_wait_timeout_ms = 10;
const frame_drain_timeout_ms = 5_000;
const mask_texture_index = text.max_font_slots;
const residency_allocation_cap = max_frames_in_flight * 3 + text.max_font_slots + 1;

pub const Options = struct {
    layer: mtl.layer.Config = .{},
};

extern fn zpui_platform_create_shader_library(device: ObjCId) ObjCId;

const GpuFrame = struct {
    buf: mtl.resource.OwnedBuffer,
    data: *scene.FrameData,
    addr: mtl.abi.GPUAddress,
    text_buf: mtl.resource.OwnedBuffer,
    text_data: *scene.TextFrameData,
    text_addr: mtl.abi.GPUAddress,
    mask_buf: mtl.resource.OwnedBuffer,
    mask_data: *scene.MaskFrameData,
    mask_addr: mtl.abi.GPUAddress,

    fn deinit(frame: *GpuFrame) void {
        frame.mask_buf.deinit();
        frame.text_buf.deinit();
        frame.buf.deinit();
    }
};

const Draw = struct {
    clear_color: mtl.abi.ClearColor,
    draw_vertex_count: u32,
    batch_count: u32,
    text_vertex_count: u32,
    text_batch_count: u32,
    mask_vertex_count: u32,
    mask_batch_count: u32,
    command_count: u32,
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
    invalid_font_options = 55,
    font_unavailable = 56,
    font_registration_failed = 57,
    invalid_font_data = 58,
    invalid_font_slot = 59,
    font_variation_unavailable = 60,
    invalid_mask_id = 61,
    invalid_mask = 62,
    mask_atlas_full = 63,
    mask_entry_capacity_exceeded = 64,

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
            Error.InvalidFontOptions => .invalid_font_options,
            Error.InvalidFontSlot => .invalid_font_slot,
            Error.FontUnavailable => .font_unavailable,
            Error.FontVariationUnavailable => .font_variation_unavailable,
            Error.FontRegistrationFailed => .font_registration_failed,
            Error.InvalidFontData => .invalid_font_data,
            Error.InvalidMaskId => .invalid_mask_id,
            Error.InvalidMask => .invalid_mask,
            Error.AtlasFull => .mask_atlas_full,
            Error.EntryCapacityExceeded => .mask_entry_capacity_exceeded,
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
    mask_pipeline_state: mtl.render.OwnedRenderPipelineState,
    command_allocators: [max_frames_in_flight]mtl.command.OwnedCommandAllocator,
    frames: [max_frames_in_flight]GpuFrame,
    draw_commands: [scene.max_draw_commands]scene.DrawCommand = undefined,
    frame_storage: ui_frame.Storage = .{},
    text_fonts: [text.max_font_slots]text.Font = [_]text.Font{.{}} ** text.max_font_slots,
    text_atlases: [text.max_font_slots]text.AtlasStorage = [_]text.AtlasStorage{.{}} ** text.max_font_slots,
    mask_atlas: mask.AtlasStorage = .{},
    font_families: [text.max_font_slots][text.max_font_family_len + 1]u8 = [_][text.max_font_family_len + 1]u8{[_]u8{0} ** (text.max_font_family_len + 1)} ** text.max_font_slots,
    font_family_lens: [text.max_font_slots]usize = [_]usize{0} ** text.max_font_slots,
    font_sizes: [text.max_font_slots]f32 = [_]f32{text.default_font_size} ** text.max_font_slots,
    font_variations: [text.max_font_slots][text.max_font_variations]text.FontVariation = [_][text.max_font_variations]text.FontVariation{[_]text.FontVariation{.{}} ** text.max_font_variations} ** text.max_font_slots,
    font_variation_lens: [text.max_font_slots]usize = [_]usize{0} ** text.max_font_slots,
    text_textures: [text.max_font_slots]mtl.resource.OwnedTexture,
    mask_texture: mtl.resource.OwnedTexture,
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
        return createWithOptions(alloc, device, .{ .layer = config });
    }

    pub fn createWithOptions(alloc: std.mem.Allocator, device: ObjCId, options: Options) Error!*Surface {
        const config = options.layer;
        const default_font = text.FontOptions{};
        const font_family = try storeFontFamily(default_font.family);

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

        var mask_pipeline_state = try createMaskPipeline(owned_device.ref(), config.pixel_format);
        errdefer mask_pipeline_state.deinit();

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

        var text_fonts: [text.max_font_slots]text.Font = [_]text.Font{.{}} ** text.max_font_slots;
        var text_atlases: [text.max_font_slots]text.AtlasStorage = [_]text.AtlasStorage{.{}} ** text.max_font_slots;
        var text_textures: [text.max_font_slots]mtl.resource.OwnedTexture = undefined;
        var text_texture_count: usize = 0;
        errdefer {
            for (text_textures[0..text_texture_count]) |*texture| {
                texture.deinit();
            }
        }
        while (text_texture_count < text.max_font_slots) : (text_texture_count += 1) {
            try buildTextAtlas(&text_fonts[text_texture_count], &text_atlases[text_texture_count], default_font, 2.0);
            text_textures[text_texture_count] = try createTextTexture(owned_device.ref(), &text_atlases[text_texture_count]);
        }

        var font_families: [text.max_font_slots][text.max_font_family_len + 1]u8 = undefined;
        var font_family_lens: [text.max_font_slots]usize = undefined;
        var font_sizes: [text.max_font_slots]f32 = undefined;
        var font_variations: [text.max_font_slots][text.max_font_variations]text.FontVariation = undefined;
        var font_variation_lens: [text.max_font_slots]usize = undefined;
        for (0..text.max_font_slots) |slot| {
            font_families[slot] = font_family;
            font_family_lens[slot] = default_font.family.len;
            font_sizes[slot] = default_font.size;
            font_variations[slot] = [_]text.FontVariation{.{}} ** text.max_font_variations;
            font_variation_lens[slot] = 0;
        }

        var mask_atlas: mask.AtlasStorage = .{};
        var mask_texture = try createMaskTexture(owned_device.ref(), &mask_atlas);
        errdefer mask_texture.deinit();

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
            const mask_buf = frames[frame_count].mask_buf;
            frame_count += 1;
            mtl.resource.addAllocation(residency_set.ref(), mtl.runtime.Object.fromRaw(buf.raw));
            mtl.resource.addAllocation(residency_set.ref(), mtl.runtime.Object.fromRaw(text_buf.raw));
            mtl.resource.addAllocation(residency_set.ref(), mtl.runtime.Object.fromRaw(mask_buf.raw));
        }
        for (&text_textures) |*texture| {
            mtl.resource.addAllocation(residency_set.ref(), mtl.runtime.Object.fromRaw(texture.raw));
        }
        mtl.resource.addAllocation(residency_set.ref(), mtl.runtime.Object.fromRaw(mask_texture.raw));
        mtl.resource.commit(residency_set.ref());
        mtl.resource.requestResidency(residency_set.ref());
        errdefer mtl.resource.endResidency(residency_set.ref());
        mtl.command.addResidencySet(command_queue.ref(), residency_set.ref());
        errdefer mtl.command.removeResidencySet(command_queue.ref(), residency_set.ref());

        var argument_table = try mtl.resource.createArgumentTableWithConfig(owned_device.ref(), .{
            .max_buffer_bind_count = 3,
            .max_texture_bind_count = text.max_font_slots + 1,
            .max_sampler_state_bind_count = 1,
        });
        errdefer argument_table.deinit();
        for (&text_textures, 0..) |*texture, slot| {
            mtl.resource.setTexture(argument_table.ref(), mtl.resource.gpuResourceId(texture.ref()), @intCast(slot));
        }
        mtl.resource.setTexture(argument_table.ref(), mtl.resource.gpuResourceId(mask_texture.ref()), mask_texture_index);
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
            .mask_pipeline_state = mask_pipeline_state,
            .command_allocators = command_allocators,
            .frames = frames,
            .draw_commands = undefined,
            .frame_storage = .{},
            .text_fonts = text_fonts,
            .text_atlases = text_atlases,
            .mask_atlas = mask_atlas,
            .font_families = font_families,
            .font_family_lens = font_family_lens,
            .font_sizes = font_sizes,
            .font_variations = font_variations,
            .font_variation_lens = font_variation_lens,
            .text_textures = text_textures,
            .mask_texture = mask_texture,
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
        surface.mask_texture.deinit();
        for (&surface.text_textures) |*texture| {
            texture.deinit();
        }
        surface.mask_pipeline_state.deinit();
        surface.text_pipeline_state.deinit();
        surface.pipeline_state.deinit();
        surface.command_buffer.deinit();
        surface.command_queue.deinit();
        surface.layer.deinit();
        surface.device.deinit();
        alloc.destroy(surface);
    }

    pub fn fonts(surface: *const Surface) []const text.Font {
        return surface.text_fonts[0..];
    }

    fn fontOptions(surface: *const Surface, slot: u32) Error!text.FontOptions {
        const index = try fontSlotIndex(slot);
        return .{
            .family = surface.font_families[index][0..surface.font_family_lens[index] :0],
            .size = surface.font_sizes[index],
            .variations = surface.font_variations[index][0..surface.font_variation_lens[index]],
        };
    }

    pub fn resolvedFontName(surface: *const Surface) []const u8 {
        return surface.resolvedFontNameSlot(text.default_font_slot) catch "";
    }

    pub fn resolvedFontNameSlot(surface: *const Surface, slot: u32) Error![]const u8 {
        const index = try fontSlotIndex(slot);
        return surface.text_fonts[index].resolvedName();
    }

    pub fn setFont(surface: *Surface, options: text.FontOptions) Error!void {
        try surface.setFontSlot(text.default_font_slot, options);
    }

    pub fn maskAtlas(surface: *const Surface) *const mask.AtlasStorage {
        return &surface.mask_atlas;
    }

    pub fn maskAtlasRect(surface: *const Surface, id: u32) Error!mask.AtlasRect {
        return surface.mask_atlas.rect(id);
    }

    pub fn setMaskAtlas(surface: *Surface, atlas: *const mask.AtlasStorage) Error!void {
        if (!atlas.valid()) return Error.InvalidMask;
        surface.drain();
        surface.mask_atlas = atlas.*;
        uploadMaskAtlas(surface.mask_texture.ref(), &surface.mask_atlas);
    }

    pub fn setFontSlot(surface: *Surface, slot: u32, options: text.FontOptions) Error!void {
        const index = try fontSlotIndex(slot);
        if (!options.valid()) return Error.InvalidFontOptions;
        if (surface.font_sizes[index] == options.size and
            std.mem.eql(u8, surface.font_families[index][0..surface.font_family_lens[index]], options.family) and
            fontVariationsEqual(surface.font_variations[index][0..surface.font_variation_lens[index]], options.variations))
        {
            return;
        }

        const next_family = try storeFontFamily(options.family);
        const next_variations = try storeFontVariations(options.variations);
        const scale32: f32 = @floatCast(surface.scale);
        var next_font: text.Font = .{};
        var next_atlas: text.AtlasStorage = .{};
        try buildTextAtlas(&next_font, &next_atlas, options, scale32);

        surface.drain();
        surface.text_fonts[index] = next_font;
        surface.text_atlases[index] = next_atlas;
        surface.font_families[index] = next_family;
        surface.font_family_lens[index] = options.family.len;
        surface.font_sizes[index] = options.size;
        surface.font_variations[index] = next_variations;
        surface.font_variation_lens[index] = options.variations.len;
        uploadTextAtlas(surface.text_textures[index].ref(), &surface.text_atlases[index]);
    }

    pub fn resize(surface: *Surface, drawable_size: mtl.abi.Size2D, scale: mtl.abi.CGFloat) Error!void {
        if (surface.drawable_size.width == drawable_size.width and
            surface.drawable_size.height == drawable_size.height and
            surface.scale == scale)
        {
            return;
        }

        try mtl.layer.resize(surface.layer.ref(), drawable_size, scale);
        const scale32: f32 = @floatCast(scale);
        if (surface.text_fonts[0].metrics.scale != scale32) {
            surface.drain();
            for (0..text.max_font_slots) |index| {
                var next_font: text.Font = .{};
                var next_atlas: text.AtlasStorage = .{};
                try buildTextAtlas(&next_font, &next_atlas, try surface.fontOptions(@intCast(index)), scale32);
                surface.text_fonts[index] = next_font;
                surface.text_atlases[index] = next_atlas;
                uploadTextAtlas(surface.text_textures[index].ref(), &surface.text_atlases[index]);
            }
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

    pub fn drawScene(surface: *Surface, frame_scene: *const scene.Scene, drawable_id: ObjCId) Error!void {
        const drawable = mtl.layer.Drawable.fromRaw(drawable_id orelse return Error.DrawableUnavailable);
        const command_allocator = try surface.nextCommandAllocator();
        const prepared = try surface.prepareScene(frame_scene);
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

        try surface.drawPreparedScene(encoder, frame_scene, prepared);

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

    fn prepareScene(surface: *Surface, frame_scene: *const scene.Scene) Error!Draw {
        const frame_slot = surface.currentFrameSlot();
        const frame = &surface.frames[frame_slot];

        const compiled = scene.compileScene(frame_scene, frame.data) catch return Error.FrameEncodingFailed;
        const text_compiled = scene.compileText(frame_scene, frame.text_data) catch return Error.FrameEncodingFailed;
        const mask_compiled = scene.compileMasks(frame_scene, frame.mask_data) catch return Error.FrameEncodingFailed;
        if (compiled.quad_count > frame_quad_cap) return Error.BufferCreationFailed;
        const command_count = try surface.buildDrawCommands(frame_scene);

        mtl.resource.setAddress(surface.argument_table.ref(), frame.addr, 0);
        mtl.resource.setAddress(surface.argument_table.ref(), frame.text_addr, 1);
        mtl.resource.setAddress(surface.argument_table.ref(), frame.mask_addr, 2);

        return .{
            .clear_color = toClearColor(frame_scene.clear_color),
            .draw_vertex_count = compiled.draw_vertex_count,
            .batch_count = compiled.batch_count,
            .text_vertex_count = text_compiled.draw_vertex_count,
            .text_batch_count = text_compiled.batch_count,
            .mask_vertex_count = mask_compiled.draw_vertex_count,
            .mask_batch_count = mask_compiled.batch_count,
            .command_count = command_count,
        };
    }

    fn buildDrawCommands(surface: *Surface, frame_scene: *const scene.Scene) Error!u32 {
        const total = frame_scene.batches.len + frame_scene.mask_batches.len + frame_scene.text_batches.len;
        if (total > scene.max_draw_commands) return Error.FrameEncodingFailed;

        var count: usize = 0;
        for (frame_scene.batches) |batch| {
            try validateClipRect(frame_scene.clips[@intCast(batch.clip_index)], frame_scene.drawable_size);
            surface.draw_commands[count] = .{
                .vertex_start = batch.vertex_start,
                .vertex_count = batch.vertex_count,
                .clip_index = batch.clip_index,
                .layer = batch.layer,
                .order = batch.order,
                .kind = .quad,
            };
            count += 1;
        }
        for (frame_scene.mask_batches) |batch| {
            try validateClipRect(frame_scene.clips[@intCast(batch.clip_index)], frame_scene.drawable_size);
            surface.draw_commands[count] = .{
                .vertex_start = batch.vertex_start,
                .vertex_count = batch.vertex_count,
                .clip_index = batch.clip_index,
                .layer = batch.layer,
                .order = batch.order,
                .kind = .mask,
            };
            count += 1;
        }
        for (frame_scene.text_batches) |batch| {
            try validateClipRect(frame_scene.clips[@intCast(batch.clip_index)], frame_scene.drawable_size);
            surface.draw_commands[count] = .{
                .vertex_start = batch.vertex_start,
                .vertex_count = batch.vertex_count,
                .clip_index = batch.clip_index,
                .layer = batch.layer,
                .order = batch.order,
                .kind = .text,
            };
            count += 1;
        }

        std.mem.sort(scene.DrawCommand, surface.draw_commands[0..count], {}, drawCommandLessThan);
        return @intCast(count);
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

    fn drawPreparedScene(surface: *Surface, encoder: mtl.render.RenderEncoder, frame_scene: *const scene.Scene, prepared: Draw) Error!void {
        var current_kind: ?scene.DrawKind = null;
        for (surface.draw_commands[0..@intCast(prepared.command_count)]) |command| {
            if (current_kind == null or current_kind.? != command.kind) {
                switch (command.kind) {
                    .quad => mtl.render.setPipelineState(encoder, surface.pipeline_state.ref()),
                    .mask => mtl.render.setPipelineState(encoder, surface.mask_pipeline_state.ref()),
                    .text => mtl.render.setPipelineState(encoder, surface.text_pipeline_state.ref()),
                }
                current_kind = command.kind;
            }
            try drawBatch(encoder, frame_scene.clips[@intCast(command.clip_index)], surface.scale, surface.drawable_size, command.vertex_start, command.vertex_count);
        }
    }
};

fn drawCommandLessThan(_: void, lhs: scene.DrawCommand, rhs: scene.DrawCommand) bool {
    if (lhs.layer != rhs.layer) return lhs.layer < rhs.layer;
    if (lhs.order != rhs.order) return lhs.order < rhs.order;
    return @intFromEnum(lhs.kind) < @intFromEnum(rhs.kind);
}

fn drawBatch(
    encoder: mtl.render.RenderEncoder,
    clip: scene.ClipRect,
    scale: mtl.abi.CGFloat,
    drawable_size: mtl.abi.Size2D,
    vertex_start: u32,
    vertex_count: u32,
) Error!void {
    mtl.render.setScissorRect(encoder, try physicalScissorRect(clip, scale, drawable_size));
    mtl.render.drawPrimitives(
        encoder,
        .triangle,
        @intCast(vertex_start),
        @intCast(vertex_count),
    );
}

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
        .blend = .{ .enabled = true },
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

fn createMaskPipeline(
    device: mtl.Device,
    pixel_format: mtl.abi.PixelFormat,
) Error!mtl.render.OwnedRenderPipelineState {
    var library = mtl.render.OwnedLibrary.fromRaw(
        zpui_platform_create_shader_library(device.raw) orelse return Error.ShaderLibraryCreationFailed,
    );
    defer library.deinit();

    return mtl.render.createPipelineStateFromLibrary(device, library.ref(), "zpui_mask_vertex", "zpui_mask_fragment", .{
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

    var mask_buf = try mtl.resource.createBuffer(
        device,
        mask_frame_buf_len,
        mtl.abi.shared_write_combined_buffer_options,
    );
    errdefer mask_buf.deinit();

    return .{
        .buf = buf,
        .data = try bufferContentsAs(buf.ref(), scene.FrameData),
        .addr = mtl.resource.gpuAddress(buf.ref()),
        .text_buf = text_buf,
        .text_data = try bufferContentsAs(text_buf.ref(), scene.TextFrameData),
        .text_addr = mtl.resource.gpuAddress(text_buf.ref()),
        .mask_buf = mask_buf,
        .mask_data = try bufferContentsAs(mask_buf.ref(), scene.MaskFrameData),
        .mask_addr = mtl.resource.gpuAddress(mask_buf.ref()),
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

fn createMaskTexture(device: mtl.Device, atlas: *const mask.AtlasStorage) Error!mtl.resource.OwnedTexture {
    var texture = try mtl.resource.createTexture(device, .{
        .width = mask.atlas_width,
        .height = mask.atlas_height,
        .pixel_format = .r8_unorm,
        .usage = mtl.abi.texture_usage_shader_read,
        .storage_mode = .shared,
    });
    errdefer texture.deinit();

    uploadMaskAtlas(texture.ref(), atlas);
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

fn uploadMaskAtlas(texture: mtl.resource.Texture, atlas: *const mask.AtlasStorage) void {
    mtl.resource.replaceRegion(
        texture,
        .{
            .origin = .{ .x = 0, .y = 0, .z = 0 },
            .size = .{ .width = mask.atlas_width, .height = mask.atlas_height, .depth = 1 },
        },
        0,
        atlas.bytes[0..].ptr,
        mask.atlas_width,
    );
}

fn validateClipRect(clip: scene.ClipRect, drawable_size: [2]f32) Error!void {
    if (clip.width == 0 or clip.height == 0) return Error.InvalidClipRect;

    const drawable_width = try sceneExtent(drawable_size[0]);
    const drawable_height = try sceneExtent(drawable_size[1]);
    if (clip.x > drawable_width or clip.width > drawable_width - clip.x) return Error.InvalidClipRect;
    if (clip.y > drawable_height or clip.height > drawable_height - clip.y) return Error.InvalidClipRect;
}

fn physicalScissorRect(clip: scene.ClipRect, scale: mtl.abi.CGFloat, drawable_size: mtl.abi.Size2D) Error!mtl.abi.ScissorRect {
    if (scale <= 0.0 or !std.math.isFinite(scale)) return Error.InvalidScale;

    const drawable_width = try drawableExtent(drawable_size.width);
    const drawable_height = try drawableExtent(drawable_size.height);
    const x0 = @floor(@as(f64, @floatFromInt(clip.x)) * scale);
    const y0 = @floor(@as(f64, @floatFromInt(clip.y)) * scale);
    const x1 = @ceil((@as(f64, @floatFromInt(clip.x)) + @as(f64, @floatFromInt(clip.width))) * scale);
    const y1 = @ceil((@as(f64, @floatFromInt(clip.y)) + @as(f64, @floatFromInt(clip.height))) * scale);
    if (x1 <= x0 or y1 <= y0) return Error.InvalidClipRect;
    if (x0 < 0.0 or y0 < 0.0) return Error.InvalidClipRect;

    const x = try checkedScissorExtent(x0);
    const y = try checkedScissorExtent(y0);
    const width = try checkedScissorExtent(x1 - x0);
    const height = try checkedScissorExtent(y1 - y0);
    if (x > drawable_width or width > drawable_width - x) return Error.InvalidClipRect;
    if (y > drawable_height or height > drawable_height - y) return Error.InvalidClipRect;

    return .{
        .x = @intCast(x),
        .y = @intCast(y),
        .width = @intCast(width),
        .height = @intCast(height),
    };
}

fn sceneExtent(value: f32) Error!u32 {
    if (value <= 0.0 or !std.math.isFinite(value)) return Error.InvalidDrawableSize;
    const floored = @floor(value);
    if (floored <= 0.0) return Error.InvalidDrawableSize;
    const max_exact_u32_f32: f32 = 4_294_967_040.0;
    if (floored >= max_exact_u32_f32) return std.math.maxInt(u32);
    return @intFromFloat(floored);
}

fn drawableExtent(value: f64) Error!u32 {
    if (value <= 0.0 or !std.math.isFinite(value)) return Error.InvalidDrawableSize;
    const floored = @floor(value);
    if (floored <= 0.0) return Error.InvalidDrawableSize;
    const capped = @min(floored, @as(f64, @floatFromInt(std.math.maxInt(u32))));
    return @intFromFloat(capped);
}

fn checkedScissorExtent(value: f64) Error!u32 {
    if (value < 0.0 or !std.math.isFinite(value)) return Error.InvalidClipRect;
    if (value > @as(f64, @floatFromInt(std.math.maxInt(u32)))) return Error.InvalidClipRect;
    return @intFromFloat(value);
}

fn toClearColor(color: [4]f64) mtl.abi.ClearColor {
    return .{
        .red = color[0],
        .green = color[1],
        .blue = color[2],
        .alpha = color[3],
    };
}

fn storeFontFamily(family: [:0]const u8) Error![text.max_font_family_len + 1]u8 {
    if (family.len == 0 or family.len > text.max_font_family_len) return Error.InvalidFontOptions;

    var stored = [_]u8{0} ** (text.max_font_family_len + 1);
    @memcpy(stored[0..family.len], family);
    return stored;
}

fn storeFontVariations(variations: []const text.FontVariation) Error![text.max_font_variations]text.FontVariation {
    if (variations.len > text.max_font_variations) return Error.InvalidFontOptions;

    var stored = [_]text.FontVariation{.{}} ** text.max_font_variations;
    for (variations, 0..) |variation, index| {
        if (!variation.valid()) return Error.InvalidFontOptions;
        for (variations[0..index]) |previous| {
            if (previous.tag == variation.tag) return Error.InvalidFontOptions;
        }
        stored[index] = variation;
    }
    return stored;
}

fn fontVariationsEqual(a: []const text.FontVariation, b: []const text.FontVariation) bool {
    if (a.len != b.len) return false;
    for (a, b) |lhs, rhs| {
        if (lhs.tag != rhs.tag or lhs.value != rhs.value) return false;
    }
    return true;
}

fn fontSlotIndex(slot: u32) Error!usize {
    const index: usize = @intCast(slot);
    if (index >= text.max_font_slots) return Error.InvalidFontSlot;
    return index;
}

fn buildTextAtlas(font: *text.Font, atlas: *text.AtlasStorage, options: text.FontOptions, scale: f32) Error!void {
    if (!options.valid() or scale <= 0.0 or !std.math.isFinite(scale)) return Error.InvalidFontOptions;
    try macos_text.buildAsciiAtlas(font, atlas, options, scale);
}

pub export fn zpui_surface_create(device: ObjCId, out_surface: *?*Surface) c_int {
    return zpui_surface_create_with_options(device, 1, out_surface);
}

pub export fn zpui_surface_create_with_options(device: ObjCId, layer_opaque: c_uint, out_surface: *?*Surface) c_int {
    out_surface.* = null;
    const surface = Surface.create(device, .{ .is_opaque = layer_opaque != 0 }) catch |err| {
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
    try std.testing.expectEqual(Status.invalid_font_options, Status.fromError(Error.InvalidFontOptions));
    try std.testing.expectEqual(Status.invalid_font_slot, Status.fromError(Error.InvalidFontSlot));
    try std.testing.expectEqual(Status.font_unavailable, Status.fromError(Error.FontUnavailable));
    try std.testing.expectEqual(Status.font_registration_failed, Status.fromError(Error.FontRegistrationFailed));
    try std.testing.expectEqual(Status.invalid_font_data, Status.fromError(Error.InvalidFontData));
    try std.testing.expectEqual(Status.frame_encoding_failed, Status.fromError(Error.FrameEncodingFailed));
    try std.testing.expectEqual(Status.frame_wait_timed_out, Status.fromError(Error.FrameWaitTimedOut));
    try std.testing.expectEqual(Status.invalid_clip_rect, Status.fromError(Error.InvalidClipRect));
    try std.testing.expectEqual(Status.render_encoder_creation_failed, Status.fromError(Error.CommandEncoderCreationFailed));
    try std.testing.expectEqual(Status.out_of_memory, Status.fromError(Error.OutOfMemory));
    try std.testing.expectEqual(@as(c_int, 55), @intFromEnum(Status.invalid_font_options));
    try std.testing.expectEqual(@as(c_int, 56), @intFromEnum(Status.font_unavailable));
    try std.testing.expectEqual(@as(c_int, 58), @intFromEnum(Status.invalid_font_data));
    try std.testing.expectEqual(@as(c_int, 59), @intFromEnum(Status.invalid_font_slot));
    try std.testing.expectEqual(@as(c_int, 60), @intFromEnum(Status.font_variation_unavailable));
    try std.testing.expectEqual(Status.font_variation_unavailable, Status.fromError(Error.FontVariationUnavailable));
    try std.testing.expectEqual(@as(c_int, 61), @intFromEnum(Status.invalid_mask_id));
    try std.testing.expectEqual(@as(c_int, 62), @intFromEnum(Status.invalid_mask));
    try std.testing.expectEqual(@as(c_int, 63), @intFromEnum(Status.mask_atlas_full));
    try std.testing.expectEqual(@as(c_int, 64), @intFromEnum(Status.mask_entry_capacity_exceeded));
    try std.testing.expectEqual(Status.invalid_mask_id, Status.fromError(Error.InvalidMaskId));
    try std.testing.expectEqual(Status.invalid_mask, Status.fromError(Error.InvalidMask));
    try std.testing.expectEqual(Status.mask_atlas_full, Status.fromError(Error.AtlasFull));
    try std.testing.expectEqual(Status.mask_entry_capacity_exceeded, Status.fromError(Error.EntryCapacityExceeded));
}

test "surface clip validation rejects scissors outside the drawable" {
    try validateClipRect(.{ .x = 0, .y = 0, .width = 640, .height = 480 }, .{ 640.0, 480.0 });
    try std.testing.expectError(Error.InvalidClipRect, validateClipRect(.{ .x = 0, .y = 0, .width = 641, .height = 480 }, .{ 640.0, 480.0 }));
    try std.testing.expectError(Error.InvalidClipRect, validateClipRect(.{ .x = 640, .y = 0, .width = 1, .height = 480 }, .{ 640.0, 480.0 }));
    try std.testing.expectError(Error.InvalidClipRect, validateClipRect(.{ .x = 0, .y = 0, .width = 0, .height = 480 }, .{ 640.0, 480.0 }));
    try std.testing.expectError(Error.InvalidDrawableSize, validateClipRect(.{ .x = 0, .y = 0, .width = 1, .height = 1 }, .{ 0.0, 480.0 }));
}

test "surface converts logical clips to physical Metal scissors" {
    const full = try physicalScissorRect(
        .{ .x = 0, .y = 0, .width = 960, .height = 600 },
        2.0,
        .{ .width = 1920.0, .height = 1200.0 },
    );
    try std.testing.expectEqual(@as(usize, 0), full.x);
    try std.testing.expectEqual(@as(usize, 0), full.y);
    try std.testing.expectEqual(@as(usize, 1920), full.width);
    try std.testing.expectEqual(@as(usize, 1200), full.height);

    const partial = try physicalScissorRect(
        .{ .x = 3, .y = 5, .width = 7, .height = 11 },
        1.5,
        .{ .width = 128.0, .height = 128.0 },
    );
    try std.testing.expectEqual(@as(usize, 4), partial.x);
    try std.testing.expectEqual(@as(usize, 7), partial.y);
    try std.testing.expectEqual(@as(usize, 11), partial.width);
    try std.testing.expectEqual(@as(usize, 17), partial.height);

    try std.testing.expectError(Error.InvalidScale, physicalScissorRect(
        .{ .x = 0, .y = 0, .width = 1, .height = 1 },
        0.0,
        .{ .width = 2.0, .height = 2.0 },
    ));
    try std.testing.expectError(Error.InvalidClipRect, physicalScissorRect(
        .{ .x = 960, .y = 0, .width = 1, .height = 1 },
        2.0,
        .{ .width = 1920.0, .height = 1200.0 },
    ));
    try std.testing.expectError(Error.InvalidClipRect, physicalScissorRect(
        .{ .x = 1, .y = 0, .width = 1, .height = 1 },
        1.0e20,
        .{ .width = 1.0e30, .height = 1.0e30 },
    ));
}

test "surface frame buffer capacity matches the scene contract" {
    try std.testing.expectEqual(@as(usize, scene.max_quads), frame_quad_cap);
    try std.testing.expectEqual(@sizeOf(scene.FrameData), frame_buf_len);
    try std.testing.expectEqual(@sizeOf(scene.TextFrameData), text_frame_buf_len);
    try std.testing.expectEqual(@sizeOf(scene.MaskFrameData), mask_frame_buf_len);
    try std.testing.expectEqual(@as(usize, max_frames_in_flight * 3 + text.max_font_slots + 1), residency_allocation_cap);
}

test "surface draw commands preserve layer and frame order" {
    var commands = [_]scene.DrawCommand{
        .{ .vertex_start = 0, .vertex_count = 6, .clip_index = 0, .layer = scene.layer_content, .order = 2, .kind = .mask },
        .{ .vertex_start = 0, .vertex_count = 6, .clip_index = 0, .layer = scene.layer_content, .order = 1, .kind = .text },
        .{ .vertex_start = 0, .vertex_count = 6, .clip_index = 0, .layer = scene.layer_foreground, .order = 0, .kind = .quad },
        .{ .vertex_start = 0, .vertex_count = 6, .clip_index = 0, .layer = scene.layer_content, .order = 0, .kind = .quad },
    };

    std.mem.sort(scene.DrawCommand, commands[0..], {}, drawCommandLessThan);

    try std.testing.expectEqual(scene.layer_content, commands[0].layer);
    try std.testing.expectEqual(@as(u32, 0), commands[0].order);
    try std.testing.expectEqual(scene.DrawKind.quad, commands[0].kind);
    try std.testing.expectEqual(@as(u32, 1), commands[1].order);
    try std.testing.expectEqual(scene.DrawKind.text, commands[1].kind);
    try std.testing.expectEqual(@as(u32, 2), commands[2].order);
    try std.testing.expectEqual(scene.DrawKind.mask, commands[2].kind);
    try std.testing.expectEqual(scene.layer_foreground, commands[3].layer);
}

test "surface stores app font choice without heap-owned strings" {
    const family = try storeFontFamily("JetBrains Mono Nerd Font");
    try std.testing.expectEqualStrings("JetBrains Mono Nerd Font", family[0.."JetBrains Mono Nerd Font".len]);
    try std.testing.expectEqual(@as(u8, 0), family["JetBrains Mono Nerd Font".len]);
    try std.testing.expectError(Error.InvalidFontOptions, storeFontFamily(""));

    const variations = try storeFontVariations(&.{.{ .tag = text.axis("wght"), .value = 500.0 }});
    try std.testing.expectEqual(text.axis("wght"), variations[0].tag);
    try std.testing.expectEqual(@as(f32, 500.0), variations[0].value);
    try std.testing.expect(fontVariationsEqual(
        variations[0..1],
        &.{.{ .tag = text.axis("wght"), .value = 500.0 }},
    ));
}
