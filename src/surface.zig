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
    InvalidFontHandle,
    OutOfMemory,
} || mask.Error || macos_text.Error || text.Error;

pub const max_frames_in_flight = 3;
pub const frame_quad_cap = scene.max_quads;
pub const frame_buf_len = @sizeOf(scene.FrameData);
pub const text_frame_buf_len = @sizeOf(scene.TextFrameData);
pub const mask_frame_buf_len = @sizeOf(scene.MaskFrameData);
const frame_wait_timeout_ms = 10;
const frame_drain_timeout_ms = 5_000;
const mask_texture_index = text.max_atlas_pages;
const residency_allocation_cap = max_frames_in_flight * 3 + text.max_atlas_pages + 1;

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

pub const RenderMetrics = struct {
    frame_index: u64 = 0,
    frame_size_points: [2]f32 = .{ 0.0, 0.0 },
    drawable_size_pixels: [2]f64 = .{ 0.0, 0.0 },
    scale: f32 = 1.0,
    quad_count: u32 = 0,
    glyph_count: u32 = 0,
    mask_count: u32 = 0,
    quad_batch_count: u32 = 0,
    text_batch_count: u32 = 0,
    mask_batch_count: u32 = 0,
    draw_command_count: u32 = 0,
    draw_call_count: u32 = 0,
    pipeline_switch_count: u32 = 0,
    scissor_set_count: u32 = 0,
    quad_vertex_count: u32 = 0,
    text_vertex_count: u32 = 0,
    mask_vertex_count: u32 = 0,
    frame_data_bytes: u64 = 0,
    text_data_bytes: u64 = 0,
    mask_data_bytes: u64 = 0,
    glyph_upload_count: u32 = 0,
    glyph_upload_bytes: u64 = 0,
    mask_upload_count: u32 = 0,
    mask_upload_bytes: u64 = 0,
    submitted_area_points: f64 = 0.0,
    frame_area_points: f64 = 0.0,
    overdraw_estimate: f32 = 0.0,

    pub fn totalBatchCount(metrics: RenderMetrics) u32 {
        return metrics.quad_batch_count + metrics.text_batch_count + metrics.mask_batch_count;
    }

    pub fn totalVertexCount(metrics: RenderMetrics) u32 {
        return metrics.quad_vertex_count + metrics.text_vertex_count + metrics.mask_vertex_count;
    }

    pub fn totalUploadBytes(metrics: RenderMetrics) u64 {
        return metrics.glyph_upload_bytes + metrics.mask_upload_bytes;
    }
};

const FontRecord = struct {
    platform: macos_text.PlatformFont = .{},
    generation: u32 = 0,
    occupied: bool = false,

    fn handle(record: *const FontRecord, index: usize) text.FontHandle {
        return .{ .index = @intCast(index), .generation = record.generation };
    }

    fn info(record: *const FontRecord) text.FontInfo {
        return .{
            .postscript_name = record.platform.postscript_name[0..record.platform.postscript_name_len],
            .family_name = record.platform.family_name[0..record.platform.family_name_len],
            .display_name = record.platform.display_name[0..record.platform.display_name_len],
            .axes = record.platform.axes[0..record.platform.axis_count],
        };
    }
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
    invalid_font_handle = 65,
    invalid_utf8 = 66,
    text_line_glyph_capacity_exceeded = 67,
    glyph_cache_capacity_exceeded = 68,
    glyph_raster_too_large = 69,
    font_capacity_exceeded = 70,
    text_line_cache_capacity_exceeded = 71,

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
            Error.InvalidFontHandle => .invalid_font_handle,
            Error.NoFont => .invalid_font_handle,
            Error.FontCapacityExceeded => .font_capacity_exceeded,
            Error.FontUnavailable => .font_unavailable,
            Error.FontVariationUnavailable => .font_variation_unavailable,
            Error.FontRegistrationFailed => .font_registration_failed,
            Error.InvalidFontData => .invalid_font_data,
            Error.InvalidUtf8 => .invalid_utf8,
            Error.LineGlyphCapacityExceeded => .text_line_glyph_capacity_exceeded,
            Error.GlyphCapacityExceeded => .text_line_glyph_capacity_exceeded,
            Error.CachedGlyphCapacityExceeded => .glyph_cache_capacity_exceeded,
            Error.RasterTooLarge => .glyph_raster_too_large,
            Error.LineCacheCapacityExceeded => .text_line_cache_capacity_exceeded,
            Error.MissingGlyph,
            Error.UnsupportedCodepoint,
            Error.InvalidAtlas,
            Error.ShapingFailed,
            => .frame_encoding_failed,
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
    font_records: [text.max_fonts]FontRecord = @splat(.{}),
    glyph_cache: [text.max_cached_glyphs]text.CachedGlyph = @splat(.{}),
    glyph_cache_count: u32 = 0,
    glyph_atlases: [text.max_atlas_pages]text.GlyphAtlasStorage = @splat(.{}),
    raster_scratch: [text.max_raster_byte_len]u8 = @splat(0),
    raw_text_runs: [text.max_line_runs]macos_text.RawTextRun = undefined,
    raw_shaped_glyphs: [text.max_line_glyphs]macos_text.RawShapedGlyph = undefined,
    raw_fallback_fonts: [text.max_fallback_fonts]macos_text.PlatformFont = @splat(.{}),
    mask_atlas: mask.AtlasStorage = .{},
    text_textures: [text.max_atlas_pages]mtl.resource.OwnedTexture,
    mask_texture: mtl.resource.OwnedTexture,
    text_sampler: mtl.resource.OwnedSamplerState,
    argument_table: mtl.resource.OwnedArgumentTable,
    residency_set: mtl.resource.OwnedResidencySet,
    layer_residency_set: ?mtl.layer.LayerResidencySet,
    frame_event: mtl.resource.OwnedSharedEvent,
    caps: mtl.runtime.DeviceCapabilities,
    current_frame_index: u64 = max_frames_in_flight,
    // CAMetalLayer exposes drawableSize as a CGSize in pixel coordinate space.
    // Keep that API shape here; integer Metal scissors are derived at encoding.
    drawable_size_pixels: mtl.abi.Size2D = .{ .width = 0, .height = 0 },
    scale: mtl.abi.CGFloat = 1.0,
    resize_generation: u64 = 0,
    glyph_atlas_generation: u64 = 1,
    config: mtl.layer.Config,
    current_metrics: RenderMetrics = .{},
    last_metrics: RenderMetrics = .{},
    metrics_frame_open: bool = false,
    pending_glyph_upload_count: u32 = 0,
    pending_glyph_upload_bytes: u64 = 0,
    pending_mask_upload_count: u32 = 0,
    pending_mask_upload_bytes: u64 = 0,

    pub fn create(device: ObjCId, config: mtl.layer.Config) Error!*Surface {
        return createWithAllocator(fallback_allocator, device, config);
    }

    pub fn createWithAllocator(alloc: std.mem.Allocator, device: ObjCId, config: mtl.layer.Config) Error!*Surface {
        return createWithOptions(alloc, device, .{ .layer = config });
    }

    pub fn createWithOptions(alloc: std.mem.Allocator, device: ObjCId, options: Options) Error!*Surface {
        const config = options.layer;
        const default_font = text.FontOptions{};

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

        var text_textures: [text.max_atlas_pages]mtl.resource.OwnedTexture = undefined;
        var text_texture_count: usize = 0;
        errdefer {
            for (text_textures[0..text_texture_count]) |*texture| {
                texture.deinit();
            }
        }
        while (text_texture_count < text.max_atlas_pages) : (text_texture_count += 1) {
            text_textures[text_texture_count] = try createGlyphTexture(owned_device.ref());
        }

        var font_records: [text.max_fonts]FontRecord = @splat(.{});
        var loaded_font_count: usize = 0;
        errdefer {
            for (font_records[0..loaded_font_count]) |*record| {
                if (record.occupied) macos_text.releaseFont(&record.platform);
            }
        }
        font_records[0] = .{
            .platform = try macos_text.loadSystemFont(default_font.family, .{}),
            .generation = 1,
            .occupied = true,
        };
        loaded_font_count = 1;

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
            .max_texture_bind_count = text.max_atlas_pages + 1,
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
            .font_records = font_records,
            .glyph_cache = @splat(.{}),
            .glyph_cache_count = 0,
            .glyph_atlases = @splat(.{}),
            .raster_scratch = @splat(0),
            .raw_text_runs = undefined,
            .raw_shaped_glyphs = undefined,
            .raw_fallback_fonts = @splat(.{}),
            .mask_atlas = mask_atlas,
            .text_textures = text_textures,
            .mask_texture = mask_texture,
            .text_sampler = text_sampler,
            .argument_table = argument_table,
            .residency_set = residency_set,
            .layer_residency_set = layer_residency_set,
            .frame_event = frame_event,
            .caps = caps,
            .resize_generation = 0,
            .glyph_atlas_generation = 1,
            .config = config,
            .current_metrics = .{},
            .last_metrics = .{},
            .metrics_frame_open = false,
        };
        return surface;
    }

    pub fn destroy(surface: *Surface) Error!void {
        const alloc = surface.allocator;
        try surface.drain();
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
        for (&surface.font_records) |*record| {
            if (record.occupied) macos_text.releaseFont(&record.platform);
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

    pub fn maskAtlas(surface: *const Surface) *const mask.AtlasStorage {
        return &surface.mask_atlas;
    }

    pub fn maskAtlasRect(surface: *const Surface, id: u32) Error!mask.AtlasRect {
        return surface.mask_atlas.rect(id);
    }

    pub fn setMaskAtlas(surface: *Surface, atlas: *const mask.AtlasStorage) Error!void {
        if (!atlas.valid()) return Error.InvalidMask;
        try surface.drain();
        surface.mask_atlas = atlas.*;
        uploadMaskAtlas(surface.mask_texture.ref(), &surface.mask_atlas);
        surface.recordMaskUpload(mask.atlas_byte_len);
    }

    pub fn beginMetricsFrame(surface: *Surface) void {
        surface.current_metrics = .{
            .frame_index = surface.current_frame_index,
            .drawable_size_pixels = .{
                surface.drawable_size_pixels.width,
                surface.drawable_size_pixels.height,
            },
            .scale = @floatCast(@max(surface.scale, 1.0)),
            .glyph_upload_count = surface.pending_glyph_upload_count,
            .glyph_upload_bytes = surface.pending_glyph_upload_bytes,
            .mask_upload_count = surface.pending_mask_upload_count,
            .mask_upload_bytes = surface.pending_mask_upload_bytes,
        };
        surface.pending_glyph_upload_count = 0;
        surface.pending_glyph_upload_bytes = 0;
        surface.pending_mask_upload_count = 0;
        surface.pending_mask_upload_bytes = 0;
        surface.metrics_frame_open = true;
    }

    pub fn renderMetrics(surface: *const Surface) RenderMetrics {
        return surface.last_metrics;
    }

    pub fn glyphAtlasGeneration(surface: *const Surface) u64 {
        return surface.glyph_atlas_generation;
    }

    pub fn defaultFont(surface: *const Surface) text.FontHandle {
        const record = &surface.font_records[0];
        if (!record.occupied) return .{};
        return record.handle(0);
    }

    pub fn loadSystemFont(surface: *Surface, name: [:0]const u8, options: text.FontLoadOptions) Error!text.FontHandle {
        if (name.len == 0 or name.len > text.max_resolved_font_name_len) return Error.InvalidFontOptions;
        const platform_font = try macos_text.loadSystemFont(name, options);
        errdefer {
            var owned = platform_font;
            macos_text.releaseFont(&owned);
        }
        return surface.addFont(platform_font);
    }

    pub fn loadFontFile(surface: *Surface, path: [:0]const u8, options: text.FontLoadOptions) Error!text.FontHandle {
        const platform_font = try macos_text.loadFontFile(path, options);
        errdefer {
            var owned = platform_font;
            macos_text.releaseFont(&owned);
        }
        return surface.addFont(platform_font);
    }

    pub fn loadFontBytes(surface: *Surface, bytes: []const u8, options: text.FontLoadOptions) Error!text.FontHandle {
        const platform_font = try macos_text.loadFontBytes(bytes, options);
        errdefer {
            var owned = platform_font;
            macos_text.releaseFont(&owned);
        }
        return surface.addFont(platform_font);
    }

    pub fn fontInfo(surface: *const Surface, handle: text.FontHandle) Error!text.FontInfo {
        const index = try surface.fontIndex(handle);
        return surface.font_records[index].info();
    }

    pub fn shapeLine(surface: *Surface, storage: *text.TextLineStorage, runs: []const text.TextRun) Error!text.TextLine {
        if (runs.len == 0 or runs.len > text.max_line_runs) return Error.InvalidFontOptions;

        var byte_len: usize = 0;
        const max_text_bytes = std.math.maxInt(u32);
        for (runs, 0..) |run, index| {
            if (run.bytes.len == 0 or !std.unicode.utf8ValidateSlice(run.bytes)) return Error.InvalidUtf8;
            if (run.size <= 0.0 or !std.math.isFinite(run.size)) return Error.InvalidFontOptions;
            const font_index = try surface.fontIndex(run.font);
            const record = surface.font_records[font_index];
            surface.raw_text_runs[index] = .{
                .bytes = run.bytes.ptr,
                .len = run.bytes.len,
                .descriptor = record.platform.descriptor,
                .font_index = run.font.index,
                .font_generation = run.font.generation,
                .size = run.size,
                .color = .{ run.color.r, run.color.g, run.color.b, run.color.a },
            };
            if (run.bytes.len > max_text_bytes - byte_len) return Error.InvalidUtf8;
            byte_len += run.bytes.len;
        }

        const metrics = try macos_text.shapeLine(
            surface.raw_text_runs[0..runs.len],
            surface.raw_shaped_glyphs[0..],
            surface.raw_fallback_fonts[0..],
        );
        if (metrics.glyph_count > storage.glyphs.len) return Error.LineGlyphCapacityExceeded;
        if (metrics.fallback_count > text.max_fallback_fonts) return Error.FontCapacityExceeded;

        var fallback_handles: [text.max_fallback_fonts]text.FontHandle = @splat(.{});
        try surface.resolveFallbackFonts(
            surface.raw_fallback_fonts[0..@intCast(metrics.fallback_count)],
            fallback_handles[0..@intCast(metrics.fallback_count)],
        );

        const glyph_count: usize = @intCast(metrics.glyph_count);
        var visible_count: usize = 0;
        for (surface.raw_shaped_glyphs[0..glyph_count]) |raw| {
            const handle = if (raw.fallback_index == text.no_fallback_index) text.FontHandle{
                .index = raw.font_index,
                .generation = raw.font_generation,
            } else fallback: {
                if (raw.fallback_index >= metrics.fallback_count) return Error.InvalidFontHandle;
                break :fallback fallback_handles[@intCast(raw.fallback_index)];
            };
            const cached = try surface.ensureGlyph(handle, raw.glyph_id, raw.size, raw.x);
            if (cached.width == 0.0 or cached.height == 0.0) continue;
            storage.glyphs[visible_count] = .{
                .instance = .{
                    .rect = .{
                        .x = raw.x + cached.offset_x,
                        .y = metrics.baseline_offset + raw.y + cached.offset_y_from_baseline,
                        .width = cached.width,
                        .height = cached.height,
                    },
                    .atlas_rect = cached.atlas_rect,
                    .color = .{ .r = raw.color[0], .g = raw.color[1], .b = raw.color[2], .a = raw.color[3] },
                    .atlas_page = cached.atlas_page,
                },
                .byte_index = raw.byte_index,
            };
            visible_count += 1;
        }

        return .{
            .advance = metrics.advance,
            .ascent = metrics.ascent,
            .descent = metrics.descent,
            .leading = metrics.leading,
            .line_height = metrics.line_height,
            .baseline_offset = metrics.baseline_offset,
            .bytes_len = metrics.bytes_len,
            .glyphs = storage.glyphs[0..visible_count],
        };
    }

    fn addFont(surface: *Surface, platform_font: macos_text.PlatformFont) Error!text.FontHandle {
        for (&surface.font_records, 0..) |*record, index| {
            if (!record.occupied) {
                record.* = .{
                    .platform = platform_font,
                    .generation = if (record.generation == 0) 1 else record.generation +% 1,
                    .occupied = true,
                };
                if (record.generation == 0) record.generation = 1;
                return record.handle(index);
            }
        }
        return Error.FontCapacityExceeded;
    }

    fn resolveFallbackFonts(surface: *Surface, fallback_fonts: []macos_text.PlatformFont, out_handles: []text.FontHandle) Error!void {
        if (fallback_fonts.len > out_handles.len) return Error.FontCapacityExceeded;

        var index: usize = 0;
        errdefer {
            for (fallback_fonts[index..]) |*fallback_font| {
                macos_text.releaseFont(fallback_font);
            }
        }

        while (index < fallback_fonts.len) : (index += 1) {
            const fallback_font = &fallback_fonts[index];
            if (surface.findFontByPostscript(fallback_font.*)) |handle| {
                out_handles[index] = handle;
                macos_text.releaseFont(fallback_font);
            } else {
                out_handles[index] = try surface.addFont(fallback_font.*);
                fallback_font.* = .{};
            }
        }
    }

    fn findFontByPostscript(surface: *const Surface, platform_font: macos_text.PlatformFont) ?text.FontHandle {
        if (platform_font.postscript_name_len == 0) return null;
        const needle = platform_font.postscript_name[0..platform_font.postscript_name_len];
        for (&surface.font_records, 0..) |*record, index| {
            if (!record.occupied or record.platform.postscript_name_len != needle.len) continue;
            if (std.mem.eql(u8, record.platform.postscript_name[0..record.platform.postscript_name_len], needle)) {
                return record.handle(index);
            }
        }
        return null;
    }

    fn fontIndex(surface: *const Surface, handle: text.FontHandle) Error!usize {
        if (!handle.valid()) return Error.InvalidFontHandle;
        const index: usize = @intCast(handle.index);
        if (index >= surface.font_records.len) return Error.InvalidFontHandle;
        const record = surface.font_records[index];
        if (!record.occupied or record.generation != handle.generation or record.platform.descriptor == null) return Error.InvalidFontHandle;
        return index;
    }

    fn ensureGlyph(surface: *Surface, font: text.FontHandle, glyph_id: u32, size: f32, x: f32) Error!text.CachedGlyph {
        const scale32: f32 = @floatCast(@max(surface.scale, 1.0));
        const physical_x = x * scale32;
        const fraction = physical_x - @floor(physical_x);
        const subpixel_x: u32 = @intFromFloat(@min(@floor(fraction * 4.0), 3.0));
        const subpixel_offset = @as(f32, @floatFromInt(subpixel_x)) * 0.25;
        const key = text.glyphCacheKey(font, glyph_id, size, scale32, subpixel_x);
        for (surface.glyph_cache[0..@intCast(surface.glyph_cache_count)]) |cached| {
            if (text.glyphCacheKeyEqual(cached.key, key)) return cached;
        }
        if (surface.glyph_cache_count >= text.max_cached_glyphs) return Error.CachedGlyphCapacityExceeded;

        const font_index = try surface.fontIndex(font);
        const record = &surface.font_records[font_index];
        const raster = try macos_text.rasterizeGlyph(
            record.platform.descriptor,
            glyph_id,
            size,
            scale32,
            subpixel_offset,
            surface.raster_scratch[0..],
        );
        if (raster.width == 0 or raster.height == 0) {
            const cached: text.CachedGlyph = .{
                .key = key,
                .atlas_page = 0,
            };
            surface.glyph_cache[@intCast(surface.glyph_cache_count)] = cached;
            surface.glyph_cache_count += 1;
            return cached;
        }

        var packed_glyph: ?text.PackedGlyph = null;
        for (&surface.glyph_atlases, 0..) |*atlas, page| {
            packed_glyph = atlas.append(@intCast(page), raster.width, raster.height, surface.raster_scratch[0 .. @as(usize, @intCast(raster.bytes_per_row)) * @as(usize, @intCast(raster.height))], raster.bytes_per_row) catch |err| switch (err) {
                error.AtlasFull => null,
                else => return err,
            };
            if (packed_glyph != null) break;
        }
        const placed = packed_glyph orelse return Error.AtlasFull;
        surface.uploadGlyph(placed);

        const cached: text.CachedGlyph = .{
            .key = key,
            .atlas_rect = .{
                .x = @as(f32, @floatFromInt(placed.x)) / @as(f32, @floatFromInt(text.glyph_atlas_width)),
                .y = @as(f32, @floatFromInt(placed.y)) / @as(f32, @floatFromInt(text.glyph_atlas_height)),
                .width = @as(f32, @floatFromInt(placed.width)) / @as(f32, @floatFromInt(text.glyph_atlas_width)),
                .height = @as(f32, @floatFromInt(placed.height)) / @as(f32, @floatFromInt(text.glyph_atlas_height)),
            },
            .atlas_page = placed.page,
            .width = raster.logical_width,
            .height = raster.logical_height,
            .offset_x = raster.offset_x,
            .offset_y_from_baseline = raster.offset_y_from_baseline,
        };
        surface.glyph_cache[@intCast(surface.glyph_cache_count)] = cached;
        surface.glyph_cache_count += 1;
        return cached;
    }

    fn uploadGlyph(surface: *Surface, glyph: text.PackedGlyph) void {
        const page: usize = @intCast(glyph.page);
        const atlas = &surface.glyph_atlases[page];
        const start = @as(usize, @intCast(glyph.y)) * text.glyph_atlas_width + @as(usize, @intCast(glyph.x));
        mtl.resource.replaceRegion(
            surface.text_textures[page].ref(),
            .{
                .origin = .{ .x = glyph.x, .y = glyph.y, .z = 0 },
                .size = .{ .width = glyph.width, .height = glyph.height, .depth = 1 },
            },
            0,
            atlas.bytes[start..].ptr,
            text.glyph_atlas_width,
        );
        surface.recordGlyphUpload(@as(u64, glyph.width) * @as(u64, glyph.height));
    }

    fn recordGlyphUpload(surface: *Surface, byte_len: u64) void {
        if (surface.metrics_frame_open) {
            surface.current_metrics.glyph_upload_count +|= 1;
            surface.current_metrics.glyph_upload_bytes +|= byte_len;
            return;
        }
        surface.pending_glyph_upload_count +|= 1;
        surface.pending_glyph_upload_bytes +|= byte_len;
    }

    fn recordMaskUpload(surface: *Surface, byte_len: u64) void {
        if (surface.metrics_frame_open) {
            surface.current_metrics.mask_upload_count +|= 1;
            surface.current_metrics.mask_upload_bytes +|= byte_len;
            return;
        }
        surface.pending_mask_upload_count +|= 1;
        surface.pending_mask_upload_bytes +|= byte_len;
    }

    pub fn resize(surface: *Surface, drawable_size_pixels: mtl.abi.Size2D, scale: mtl.abi.CGFloat) Error!void {
        if (!validDrawableSizePixels(drawable_size_pixels)) return Error.InvalidDrawableSize;
        if (!validScale(scale)) return Error.InvalidScale;

        if (surface.drawable_size_pixels.width == drawable_size_pixels.width and
            surface.drawable_size_pixels.height == drawable_size_pixels.height and
            surface.scale == scale)
        {
            return;
        }

        const scale_changed = surface.scale != scale;
        if (scale_changed) {
            try surface.drain();
        }

        try mtl.layer.resize(surface.layer.ref(), drawable_size_pixels, scale);
        if (scale_changed) {
            surface.glyph_cache_count = 0;
            for (&surface.glyph_atlases) |*atlas| atlas.clear();
            surface.glyph_atlas_generation += 1;
        }
        surface.drawable_size_pixels = drawable_size_pixels;
        surface.scale = scale;
        surface.resize_generation += 1;
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

    pub fn drain(surface: *Surface) Error!void {
        const last_submitted_frame = surface.current_frame_index - 1;
        if (!mtl.resource.waitUntilSignaledValue(surface.frame_event.ref(), last_submitted_frame, frame_drain_timeout_ms)) {
            return Error.FrameWaitTimedOut;
        }
    }

    pub fn signalFrameCompletion(surface: *Surface) void {
        mtl.command.signalEvent(surface.command_queue.ref(), surface.frame_event.ref(), surface.current_frame_index);
        surface.current_frame_index += 1;
    }

    pub fn drawScene(surface: *Surface, frame_scene: *const scene.Scene, drawable_id: ObjCId) Error!void {
        if (!surface.metrics_frame_open) surface.beginMetricsFrame();
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
            .width = surface.drawable_size_pixels.width,
            .height = surface.drawable_size_pixels.height,
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
        surface.last_metrics = surface.current_metrics;
        surface.metrics_frame_open = false;
    }

    fn prepareScene(surface: *Surface, frame_scene: *const scene.Scene) Error!Draw {
        const frame_slot = surface.currentFrameSlot();
        const frame = &surface.frames[frame_slot];

        const frame_scale: f32 = @floatCast(@max(surface.scale, 1.0));
        const compiled = scene.compileScene(frame_scene, frame.data, frame_scale) catch return Error.FrameEncodingFailed;
        const text_compiled = scene.compileText(frame_scene, frame.text_data, frame_scale) catch return Error.FrameEncodingFailed;
        const mask_compiled = scene.compileMasks(frame_scene, frame.mask_data, frame_scale) catch return Error.FrameEncodingFailed;
        if (compiled.quad_count > frame_quad_cap) return Error.BufferCreationFailed;
        const command_count = try surface.buildDrawCommands(frame_scene);

        mtl.resource.setAddress(surface.argument_table.ref(), frame.addr, 0);
        mtl.resource.setAddress(surface.argument_table.ref(), frame.text_addr, 1);
        mtl.resource.setAddress(surface.argument_table.ref(), frame.mask_addr, 2);

        surface.current_metrics = surface.preparedMetrics(frame_scene, compiled, text_compiled, mask_compiled, command_count);

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

    fn preparedMetrics(
        surface: *Surface,
        frame_scene: *const scene.Scene,
        compiled: scene.CompileResult,
        text_compiled: scene.TextCompileResult,
        mask_compiled: scene.MaskCompileResult,
        command_count: u32,
    ) RenderMetrics {
        var metrics = surface.current_metrics;
        metrics.frame_index = surface.current_frame_index;
        metrics.frame_size_points = frame_scene.frame_size_points;
        metrics.drawable_size_pixels = .{
            surface.drawable_size_pixels.width,
            surface.drawable_size_pixels.height,
        };
        metrics.scale = @floatCast(@max(surface.scale, 1.0));
        metrics.quad_count = compiled.quad_count;
        metrics.glyph_count = text_compiled.glyph_count;
        metrics.mask_count = mask_compiled.mask_count;
        metrics.quad_batch_count = compiled.batch_count;
        metrics.text_batch_count = text_compiled.batch_count;
        metrics.mask_batch_count = mask_compiled.batch_count;
        metrics.draw_command_count = command_count;
        metrics.draw_call_count = command_count;
        metrics.pipeline_switch_count = countPipelineSwitches(surface.draw_commands[0..@intCast(command_count)]);
        metrics.scissor_set_count = command_count;
        metrics.quad_vertex_count = compiled.draw_vertex_count;
        metrics.text_vertex_count = text_compiled.draw_vertex_count;
        metrics.mask_vertex_count = mask_compiled.draw_vertex_count;
        metrics.frame_data_bytes = @intCast(scene.frameDataByteLen(compiled.quad_count));
        metrics.text_data_bytes = @intCast(scene.textFrameDataByteLen(text_compiled.glyph_count));
        metrics.mask_data_bytes = @intCast(scene.maskFrameDataByteLen(mask_compiled.mask_count));
        metrics.submitted_area_points = estimateSubmittedArea(frame_scene);
        metrics.frame_area_points = frameAreaPoints(frame_scene.frame_size_points);
        metrics.overdraw_estimate = overdrawEstimate(metrics.submitted_area_points, metrics.frame_area_points);
        return metrics;
    }

    fn buildDrawCommands(surface: *Surface, frame_scene: *const scene.Scene) Error!u32 {
        const total = frame_scene.batches.len + frame_scene.mask_batches.len + frame_scene.text_batches.len;
        if (total > scene.max_draw_commands) return Error.FrameEncodingFailed;

        var count: usize = 0;
        for (frame_scene.batches) |batch| {
            try validateClipRect(frame_scene.clips[@intCast(batch.clip_index)], frame_scene.frame_size_points);
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
            try validateClipRect(frame_scene.clips[@intCast(batch.clip_index)], frame_scene.frame_size_points);
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
            try validateClipRect(frame_scene.clips[@intCast(batch.clip_index)], frame_scene.frame_size_points);
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
            try drawBatch(encoder, frame_scene.clips[@intCast(command.clip_index)], surface.scale, surface.drawable_size_pixels, command.vertex_start, command.vertex_count);
        }
    }
};

fn drawCommandLessThan(_: void, lhs: scene.DrawCommand, rhs: scene.DrawCommand) bool {
    if (lhs.layer != rhs.layer) return lhs.layer < rhs.layer;
    if (lhs.order != rhs.order) return lhs.order < rhs.order;
    return @intFromEnum(lhs.kind) < @intFromEnum(rhs.kind);
}

fn countPipelineSwitches(commands: []const scene.DrawCommand) u32 {
    var count: u32 = 0;
    var current_kind: ?scene.DrawKind = null;
    for (commands) |command| {
        if (current_kind == null or current_kind.? != command.kind) {
            count += 1;
            current_kind = command.kind;
        }
    }
    return count;
}

fn estimateSubmittedArea(frame_scene: *const scene.Scene) f64 {
    var area: f64 = 0.0;

    for (frame_scene.batches) |batch| {
        const clip = frame_scene.clips[@intCast(batch.clip_index)];
        const first_quad: usize = @intCast(batch.vertex_start / scene.vertices_per_quad);
        const quad_count: usize = @intCast(batch.vertex_count / scene.vertices_per_quad);
        for (frame_scene.quads[first_quad .. first_quad + quad_count]) |quad| {
            area += clippedArea(quad.rect.x, quad.rect.y, quad.rect.width, quad.rect.height, clip);
        }
    }

    for (frame_scene.text_batches) |batch| {
        const clip = frame_scene.clips[@intCast(batch.clip_index)];
        const first_glyph: usize = @intCast(batch.vertex_start / scene.vertices_per_glyph);
        const glyph_count: usize = @intCast(batch.vertex_count / scene.vertices_per_glyph);
        for (frame_scene.glyphs[first_glyph .. first_glyph + glyph_count]) |glyph| {
            area += clippedArea(glyph.rect.x, glyph.rect.y, glyph.rect.width, glyph.rect.height, clip);
        }
    }

    for (frame_scene.mask_batches) |batch| {
        const clip = frame_scene.clips[@intCast(batch.clip_index)];
        const first_mask: usize = @intCast(batch.vertex_start / scene.vertices_per_mask);
        const mask_count: usize = @intCast(batch.vertex_count / scene.vertices_per_mask);
        for (frame_scene.masks[first_mask .. first_mask + mask_count]) |instance| {
            area += clippedArea(instance.rect.x, instance.rect.y, instance.rect.width, instance.rect.height, clip);
        }
    }

    return area;
}

fn clippedArea(x: f32, y: f32, width: f32, height: f32, clip: scene.ClipRect) f64 {
    if (width <= 0.0 or height <= 0.0) return 0.0;
    const clip_x: f32 = @floatFromInt(clip.x);
    const clip_y: f32 = @floatFromInt(clip.y);
    const clip_width: f32 = @floatFromInt(clip.width);
    const clip_height: f32 = @floatFromInt(clip.height);
    const x0 = @max(x, clip_x);
    const y0 = @max(y, clip_y);
    const x1 = @min(x + width, clip_x + clip_width);
    const y1 = @min(y + height, clip_y + clip_height);
    const clipped_width = @max(x1 - x0, 0.0);
    const clipped_height = @max(y1 - y0, 0.0);
    return @as(f64, clipped_width) * @as(f64, clipped_height);
}

fn frameAreaPoints(frame_size_points: [2]f32) f64 {
    if (frame_size_points[0] <= 0.0 or frame_size_points[1] <= 0.0) return 0.0;
    return @as(f64, frame_size_points[0]) * @as(f64, frame_size_points[1]);
}

fn overdrawEstimate(submitted_area: f64, drawable_area_value: f64) f32 {
    if (drawable_area_value <= 0.0) return 0.0;
    return @floatCast(submitted_area / drawable_area_value);
}

fn drawBatch(
    encoder: mtl.render.RenderEncoder,
    clip: scene.ClipRect,
    scale: mtl.abi.CGFloat,
    drawable_size_pixels: mtl.abi.Size2D,
    vertex_start: u32,
    vertex_count: u32,
) Error!void {
    mtl.render.setScissorRect(encoder, try physicalScissorRect(clip, scale, drawable_size_pixels));
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

fn createGlyphTexture(device: mtl.Device) Error!mtl.resource.OwnedTexture {
    return mtl.resource.createTexture(device, .{
        .width = text.glyph_atlas_width,
        .height = text.glyph_atlas_height,
        .pixel_format = .r8_unorm,
        .usage = mtl.abi.texture_usage_shader_read,
        .storage_mode = .shared,
    });
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

fn validateClipRect(clip: scene.ClipRect, frame_size_points: [2]f32) Error!void {
    if (clip.width == 0 or clip.height == 0) return Error.InvalidClipRect;

    // Scene clips are integer points with exclusive max edges. Validate against
    // the same outward-rounded extent produced by Frame.clipRectFromPoints.
    const frame_width = try pointExtent(frame_size_points[0]);
    const frame_height = try pointExtent(frame_size_points[1]);
    if (clip.x > frame_width or clip.width > frame_width - clip.x) return Error.InvalidClipRect;
    if (clip.y > frame_height or clip.height > frame_height - clip.y) return Error.InvalidClipRect;
}

fn physicalScissorRect(clip: scene.ClipRect, scale: mtl.abi.CGFloat, drawable_size_pixels: mtl.abi.Size2D) Error!mtl.abi.ScissorRect {
    if (scale <= 0.0 or !std.math.isFinite(scale)) return Error.InvalidScale;

    const drawable_width = try drawablePixelExtent(drawable_size_pixels.width);
    const drawable_height = try drawablePixelExtent(drawable_size_pixels.height);
    const x0 = @floor(@as(f64, @floatFromInt(clip.x)) * scale);
    const y0 = @floor(@as(f64, @floatFromInt(clip.y)) * scale);
    const unclamped_x1 = @ceil((@as(f64, @floatFromInt(clip.x)) + @as(f64, @floatFromInt(clip.width))) * scale);
    const unclamped_y1 = @ceil((@as(f64, @floatFromInt(clip.y)) + @as(f64, @floatFromInt(clip.height))) * scale);
    const x1 = @min(unclamped_x1, @as(f64, @floatFromInt(drawable_width)));
    const y1 = @min(unclamped_y1, @as(f64, @floatFromInt(drawable_height)));
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

fn pointExtent(value: f32) Error!u32 {
    if (value <= 0.0 or !std.math.isFinite(value)) return Error.InvalidDrawableSize;
    const ceiled = @ceil(value);
    if (ceiled <= 0.0) return Error.InvalidDrawableSize;
    const max_exact_u32_f32: f32 = 4_294_967_040.0;
    if (ceiled >= max_exact_u32_f32) return std.math.maxInt(u32);
    return @intFromFloat(ceiled);
}

fn validDrawableSizePixels(size: mtl.abi.Size2D) bool {
    return size.width > 0.0 and
        size.height > 0.0 and
        std.math.isFinite(size.width) and
        std.math.isFinite(size.height);
}

fn validScale(scale: mtl.abi.CGFloat) bool {
    return scale > 0.0 and std.math.isFinite(scale);
}

fn drawablePixelExtent(value: f64) Error!u32 {
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

pub export fn zpui_surface_destroy(surface: ?*Surface) c_int {
    const unwrapped_surface = surface orelse return @intFromEnum(Status.ok);
    unwrapped_surface.destroy() catch |err| {
        return @intFromEnum(Status.fromError(err));
    };
    return @intFromEnum(Status.ok);
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
    try std.testing.expectEqual(Status.font_capacity_exceeded, Status.fromError(Error.FontCapacityExceeded));
    try std.testing.expectEqual(@as(c_int, 61), @intFromEnum(Status.invalid_mask_id));
    try std.testing.expectEqual(@as(c_int, 62), @intFromEnum(Status.invalid_mask));
    try std.testing.expectEqual(@as(c_int, 63), @intFromEnum(Status.mask_atlas_full));
    try std.testing.expectEqual(@as(c_int, 64), @intFromEnum(Status.mask_entry_capacity_exceeded));
    try std.testing.expectEqual(Status.invalid_mask_id, Status.fromError(Error.InvalidMaskId));
    try std.testing.expectEqual(Status.invalid_mask, Status.fromError(Error.InvalidMask));
    try std.testing.expectEqual(Status.mask_atlas_full, Status.fromError(Error.AtlasFull));
    try std.testing.expectEqual(Status.mask_entry_capacity_exceeded, Status.fromError(Error.EntryCapacityExceeded));
    try std.testing.expectEqual(@as(c_int, 70), @intFromEnum(Status.font_capacity_exceeded));
    try std.testing.expectEqual(Status.text_line_cache_capacity_exceeded, Status.fromError(Error.LineCacheCapacityExceeded));
    try std.testing.expectEqual(@as(c_int, 71), @intFromEnum(Status.text_line_cache_capacity_exceeded));
}

test "surface clip validation rejects clips outside the frame points" {
    try validateClipRect(.{ .x = 0, .y = 0, .width = 640, .height = 480 }, .{ 640.0, 480.0 });
    try std.testing.expectError(Error.InvalidClipRect, validateClipRect(.{ .x = 0, .y = 0, .width = 641, .height = 480 }, .{ 640.0, 480.0 }));
    try std.testing.expectError(Error.InvalidClipRect, validateClipRect(.{ .x = 640, .y = 0, .width = 1, .height = 480 }, .{ 640.0, 480.0 }));
    try std.testing.expectError(Error.InvalidClipRect, validateClipRect(.{ .x = 0, .y = 0, .width = 0, .height = 480 }, .{ 640.0, 480.0 }));
    try std.testing.expectError(Error.InvalidDrawableSize, validateClipRect(.{ .x = 0, .y = 0, .width = 1, .height = 1 }, .{ 0.0, 480.0 }));
}

test "surface converts point clips to physical Metal scissors" {
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

test "surface clip validation allows outward-rounded fractional logical roots" {
    try validateClipRect(.{ .x = 0, .y = 0, .width = 667, .height = 334 }, .{ 666.5, 333.5 });

    const scissor = try physicalScissorRect(
        .{ .x = 0, .y = 0, .width = 667, .height = 334 },
        2.0,
        .{ .width = 1333.0, .height = 667.0 },
    );
    try std.testing.expectEqual(@as(usize, 0), scissor.x);
    try std.testing.expectEqual(@as(usize, 0), scissor.y);
    try std.testing.expectEqual(@as(usize, 1333), scissor.width);
    try std.testing.expectEqual(@as(usize, 667), scissor.height);

    try std.testing.expectError(Error.InvalidClipRect, validateClipRect(
        .{ .x = 0, .y = 0, .width = 668, .height = 334 },
        .{ 666.5, 333.5 },
    ));
}

test "surface drawable pixel and scale validation rejects non-finite input" {
    try std.testing.expect(validDrawableSizePixels(.{ .width = 1333.0, .height = 667.0 }));
    try std.testing.expect(!validDrawableSizePixels(.{ .width = std.math.nan(f64), .height = 667.0 }));
    try std.testing.expect(!validDrawableSizePixels(.{ .width = 1333.0, .height = std.math.inf(f64) }));
    try std.testing.expect(!validDrawableSizePixels(.{ .width = 0.0, .height = 667.0 }));

    try std.testing.expect(validScale(2.0));
    try std.testing.expect(!validScale(0.0));
    try std.testing.expect(!validScale(std.math.nan(f64)));
    try std.testing.expect(!validScale(std.math.inf(f64)));
}

test "surface frame buffer capacity matches the scene contract" {
    try std.testing.expectEqual(@as(usize, scene.max_quads), frame_quad_cap);
    try std.testing.expectEqual(@sizeOf(scene.FrameData), frame_buf_len);
    try std.testing.expectEqual(@sizeOf(scene.TextFrameData), text_frame_buf_len);
    try std.testing.expectEqual(@sizeOf(scene.MaskFrameData), mask_frame_buf_len);
    try std.testing.expectEqual(@as(usize, max_frames_in_flight * 3 + text.max_atlas_pages + 1), residency_allocation_cap);
}

test "surface upload metrics carry cold uploads into the next frame" {
    const surface = try std.testing.allocator.create(Surface);
    defer std.testing.allocator.destroy(surface);

    surface.current_frame_index = 9;
    surface.drawable_size_pixels = .{ .width = 200.0, .height = 100.0 };
    surface.scale = 2.0;
    surface.current_metrics = .{};
    surface.last_metrics = .{};
    surface.metrics_frame_open = false;
    surface.pending_glyph_upload_count = 0;
    surface.pending_glyph_upload_bytes = 0;
    surface.pending_mask_upload_count = 0;
    surface.pending_mask_upload_bytes = 0;

    surface.recordGlyphUpload(32);
    surface.recordMaskUpload(64);
    surface.beginMetricsFrame();

    try std.testing.expectEqual(@as(u32, 1), surface.current_metrics.glyph_upload_count);
    try std.testing.expectEqual(@as(u64, 32), surface.current_metrics.glyph_upload_bytes);
    try std.testing.expectEqual(@as(u32, 1), surface.current_metrics.mask_upload_count);
    try std.testing.expectEqual(@as(u64, 64), surface.current_metrics.mask_upload_bytes);
    try std.testing.expectEqual(@as(u32, 0), surface.pending_glyph_upload_count);
    try std.testing.expectEqual(@as(u64, 0), surface.pending_glyph_upload_bytes);
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

test "surface metrics count pipeline switches from sorted draw commands" {
    const commands = [_]scene.DrawCommand{
        .{ .vertex_start = 0, .vertex_count = 6, .clip_index = 0, .layer = 0, .order = 0, .kind = .quad },
        .{ .vertex_start = 6, .vertex_count = 6, .clip_index = 0, .layer = 0, .order = 1, .kind = .quad },
        .{ .vertex_start = 0, .vertex_count = 6, .clip_index = 0, .layer = 0, .order = 2, .kind = .text },
        .{ .vertex_start = 0, .vertex_count = 6, .clip_index = 0, .layer = 0, .order = 3, .kind = .mask },
        .{ .vertex_start = 6, .vertex_count = 6, .clip_index = 0, .layer = 0, .order = 4, .kind = .text },
    };

    try std.testing.expectEqual(@as(u32, 4), countPipelineSwitches(commands[0..]));
    try std.testing.expectEqual(@as(u32, 0), countPipelineSwitches(&.{}));
}

test "surface metrics estimate clipped submitted area" {
    var storage: scene.SceneStorage = .{};
    var builder = scene.SceneBuilder.begin(&storage, .{ 100.0, 100.0 }, .{ 0.0, 0.0, 0.0, 1.0 });
    const full_clip = try builder.pushFrameClip();
    const small_clip = try builder.pushClip(.{ .x = 10, .y = 10, .width = 20, .height = 20 });

    try builder.beginLayerBatch(full_clip, scene.layer_background);
    try builder.pushQuad(.{ .x = 0.0, .y = 0.0, .width = 100.0, .height = 100.0 }, .{ 1.0, 1.0, 1.0, 1.0 }, full_clip);
    try builder.endBatch();

    try builder.beginLayerBatch(small_clip, scene.layer_surface);
    try builder.pushQuad(.{ .x = 0.0, .y = 0.0, .width = 100.0, .height = 100.0 }, .{ 1.0, 0.0, 0.0, 1.0 }, small_clip);
    try builder.endBatch();

    const out = try builder.finish();
    const submitted = estimateSubmittedArea(&out);
    const frame_area = frameAreaPoints(out.frame_size_points);

    try std.testing.expectEqual(@as(f64, 10_400.0), submitted);
    try std.testing.expectEqual(@as(f64, 10_000.0), frame_area);
    try std.testing.expectApproxEqAbs(@as(f32, 1.04), overdrawEstimate(submitted, frame_area), 0.001);
}

test "render metrics totals stay derived from explicit counters" {
    const metrics: RenderMetrics = .{
        .quad_batch_count = 2,
        .text_batch_count = 3,
        .mask_batch_count = 5,
        .quad_vertex_count = 12,
        .text_vertex_count = 18,
        .mask_vertex_count = 30,
        .glyph_upload_bytes = 128,
        .mask_upload_bytes = 256,
    };

    try std.testing.expectEqual(@as(u32, 10), metrics.totalBatchCount());
    try std.testing.expectEqual(@as(u32, 60), metrics.totalVertexCount());
    try std.testing.expectEqual(@as(u64, 384), metrics.totalUploadBytes());
}
