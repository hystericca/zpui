#include <metal_stdlib>
using namespace metal;

struct ZPUIRect {
    float x;
    float y;
    float width;
    float height;
};

struct ZPUIQuad {
    ZPUIRect rect;
    float4 fill_color;
    float4 border_color;
    float4 radius;
    float border_width;
    float reserved0;
    float reserved1;
    float reserved2;
};

struct ZPUIFrameData {
    float2 drawable_size;
    uint quad_count;
    uint reserved;
    ZPUIQuad quads[2048];
};

struct ZPUIAtlasRect {
    float x;
    float y;
    float width;
    float height;
};

struct ZPUIGlyph {
    ZPUIRect rect;
    ZPUIAtlasRect atlas_rect;
    float4 color;
    uint font_slot;
    uint reserved0;
    uint reserved1;
    uint reserved2;
};

struct ZPUIMask {
    ZPUIRect rect;
    ZPUIAtlasRect atlas_rect;
    float4 color;
};

struct ZPUITextFrameData {
    float2 drawable_size;
    uint glyph_count;
    uint reserved;
    ZPUIGlyph glyphs[16384];
};

struct ZPUIMaskFrameData {
    float2 drawable_size;
    uint mask_count;
    uint reserved;
    ZPUIMask masks[1024];
};

static_assert(sizeof(ZPUIRect) == 16, "ZPUIRect ABI size mismatch");
static_assert(sizeof(ZPUIQuad) == 80, "ZPUIQuad ABI size mismatch");
static_assert(sizeof(ZPUIFrameData) == 163856, "ZPUIFrameData ABI size mismatch");
static_assert(sizeof(ZPUIAtlasRect) == 16, "ZPUIAtlasRect ABI size mismatch");
static_assert(sizeof(ZPUIGlyph) == 64, "ZPUIGlyph ABI size mismatch");
static_assert(sizeof(ZPUITextFrameData) == 1048592, "ZPUITextFrameData ABI size mismatch");
static_assert(sizeof(ZPUIMask) == 48, "ZPUIMask ABI size mismatch");
static_assert(sizeof(ZPUIMaskFrameData) == 49168, "ZPUIMaskFrameData ABI size mismatch");

struct ZPUIVertexOut {
    float4 position [[position]];
    float2 pixel;
    uint quad_index [[flat]];
};

struct ZPUITextVertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    uint font_slot [[flat]];
};

struct ZPUIMaskVertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
};

constant float2 zpui_quad_corners[6] = {
    float2(0.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 1.0),
};

static float4 zpui_pixel_position(float2 pixel, float2 drawable_size) {
    const float2 clip = float2(
        pixel.x / drawable_size.x * 2.0 - 1.0,
        1.0 - pixel.y / drawable_size.y * 2.0
    );
    return float4(clip, 0.0, 1.0);
}

static float4 zpui_premultiply(float4 color) {
    return float4(color.rgb * color.a, color.a);
}

static bool zpui_zero_radius(float4 radius) {
    return radius.x == 0.0 && radius.y == 0.0 && radius.z == 0.0 && radius.w == 0.0;
}

static float zpui_pick_radius(float2 local, float2 size, float4 radius) {
    const bool left = local.x < size.x * 0.5;
    const bool top = local.y < size.y * 0.5;
    if (top) {
        return left ? radius.x : radius.y;
    }
    return left ? radius.w : radius.z;
}

static float zpui_rounded_rect_sdf(float2 local, float2 size, float4 radius) {
    const float max_radius = max(0.0, min(size.x, size.y) * 0.5);
    const float corner_radius = clamp(zpui_pick_radius(local, size, radius), 0.0, max_radius);
    const float2 half_size = size * 0.5;
    const float2 center_to_point = local - half_size;
    const float2 q = abs(center_to_point) - half_size + corner_radius;
    return length(max(q, float2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
}

vertex ZPUIVertexOut zpui_vertex(uint vertex_id [[vertex_id]],
                                 constant ZPUIFrameData &frame [[buffer(0)]]) {
    const uint quad_index = vertex_id / 6;
    const uint corner_index = vertex_id - quad_index * 6;
    const ZPUIQuad quad = frame.quads[quad_index];
    const float2 corner = zpui_quad_corners[corner_index];
    const float2 pixel = float2(
        quad.rect.x + quad.rect.width * corner.x,
        quad.rect.y + quad.rect.height * corner.y
    );

    ZPUIVertexOut out;
    out.position = zpui_pixel_position(pixel, frame.drawable_size);
    out.pixel = pixel;
    out.quad_index = quad_index;
    return out;
}

fragment float4 zpui_fragment(ZPUIVertexOut in [[stage_in]],
                              constant ZPUIFrameData &frame [[buffer(0)]]) {
    const ZPUIQuad quad = frame.quads[in.quad_index];
    const float2 size = float2(quad.rect.width, quad.rect.height);
    const float2 local = in.pixel - float2(quad.rect.x, quad.rect.y);

    if (quad.border_width == 0.0 && zpui_zero_radius(quad.radius)) {
        return zpui_premultiply(quad.fill_color);
    }

    const float outer_distance = zpui_rounded_rect_sdf(local, size, quad.radius);
    const float outer_alpha = saturate(0.5 - outer_distance);
    if (outer_alpha <= 0.0) {
        return float4(0.0);
    }

    if (quad.border_width <= 0.0) {
        return zpui_premultiply(quad.fill_color) * outer_alpha;
    }

    const float border_width = min(quad.border_width, min(size.x, size.y) * 0.5);
    const float2 inner_size = max(size - float2(border_width * 2.0), float2(0.0));
    float inner_alpha = 0.0;
    if (inner_size.x > 0.0 && inner_size.y > 0.0) {
        const float2 inner_local = local - float2(border_width);
        const float4 inner_radius = max(quad.radius - float4(border_width), float4(0.0));
        const float inner_distance = zpui_rounded_rect_sdf(inner_local, inner_size, inner_radius);
        inner_alpha = saturate(0.5 - inner_distance);
    }

    const float4 color = mix(quad.border_color, quad.fill_color, inner_alpha);
    return zpui_premultiply(color) * outer_alpha;
}

vertex ZPUITextVertexOut zpui_text_vertex(uint vertex_id [[vertex_id]],
                                          constant ZPUITextFrameData &frame [[buffer(1)]]) {
    const uint glyph_index = vertex_id / 6;
    const uint corner_index = vertex_id - glyph_index * 6;
    const ZPUIGlyph glyph = frame.glyphs[glyph_index];
    const float2 corner = zpui_quad_corners[corner_index];
    const float2 pixel = float2(
        glyph.rect.x + glyph.rect.width * corner.x,
        glyph.rect.y + glyph.rect.height * corner.y
    );

    ZPUITextVertexOut out;
    out.position = zpui_pixel_position(pixel, frame.drawable_size);
    out.uv = float2(
        glyph.atlas_rect.x + glyph.atlas_rect.width * corner.x,
        glyph.atlas_rect.y + glyph.atlas_rect.height * corner.y
    );
    out.color = glyph.color;
    out.font_slot = glyph.font_slot;
    return out;
}

fragment float4 zpui_text_fragment(ZPUITextVertexOut in [[stage_in]],
                                   texture2d<float> atlas0 [[texture(0)]],
                                   texture2d<float> atlas1 [[texture(1)]],
                                   texture2d<float> atlas2 [[texture(2)]],
                                   texture2d<float> atlas3 [[texture(3)]],
                                   sampler atlas_sampler [[sampler(0)]]) {
    float coverage = 0.0;
    switch (in.font_slot) {
        case 1:
            coverage = atlas1.sample(atlas_sampler, in.uv).r;
            break;
        case 2:
            coverage = atlas2.sample(atlas_sampler, in.uv).r;
            break;
        case 3:
            coverage = atlas3.sample(atlas_sampler, in.uv).r;
            break;
        default:
            coverage = atlas0.sample(atlas_sampler, in.uv).r;
            break;
    }
    const float alpha = in.color.a * coverage;
    return float4(in.color.rgb * alpha, alpha);
}

vertex ZPUIMaskVertexOut zpui_mask_vertex(uint vertex_id [[vertex_id]],
                                          constant ZPUIMaskFrameData &frame [[buffer(2)]]) {
    const uint mask_index = vertex_id / 6;
    const uint corner_index = vertex_id - mask_index * 6;
    const ZPUIMask mask = frame.masks[mask_index];
    const float2 corner = zpui_quad_corners[corner_index];
    const float2 pixel = float2(
        mask.rect.x + mask.rect.width * corner.x,
        mask.rect.y + mask.rect.height * corner.y
    );

    ZPUIMaskVertexOut out;
    out.position = zpui_pixel_position(pixel, frame.drawable_size);
    out.uv = float2(
        mask.atlas_rect.x + mask.atlas_rect.width * corner.x,
        mask.atlas_rect.y + mask.atlas_rect.height * corner.y
    );
    out.color = mask.color;
    return out;
}

fragment float4 zpui_mask_fragment(ZPUIMaskVertexOut in [[stage_in]],
                                   texture2d<float> atlas [[texture(4)]],
                                   sampler atlas_sampler [[sampler(0)]]) {
    const float coverage = atlas.sample(atlas_sampler, in.uv).r;
    const float alpha = in.color.a * coverage;
    return float4(in.color.rgb * alpha, alpha);
}
