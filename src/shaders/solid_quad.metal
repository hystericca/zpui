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
    float4 color;
};

struct ZPUIFrameData {
    float2 drawable_size;
    uint quad_count;
    uint reserved;
    ZPUIQuad quads[128];
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
};

struct ZPUITextFrameData {
    float2 drawable_size;
    uint glyph_count;
    uint reserved;
    ZPUIGlyph glyphs[4096];
};

struct ZPUIVertexOut {
    float4 position [[position]];
    float4 color;
};

struct ZPUITextVertexOut {
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
    out.color = quad.color;
    return out;
}

fragment float4 zpui_fragment(ZPUIVertexOut in [[stage_in]]) {
    return in.color;
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
    return out;
}

fragment float4 zpui_text_fragment(ZPUITextVertexOut in [[stage_in]],
                                   texture2d<float> atlas [[texture(0)]],
                                   sampler atlas_sampler [[sampler(0)]]) {
    const float coverage = atlas.sample(atlas_sampler, in.uv).r;
    const float alpha = in.color.a * coverage;
    return float4(in.color.rgb * alpha, alpha);
}
