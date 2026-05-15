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
    uint clip_index;
    uint reserved0;
    uint reserved1;
    uint reserved2;
};

struct ZPUIFrameData {
    float2 drawable_size;
    uint quad_count;
    uint reserved;
    ZPUIQuad quads[128];
};

struct ZPUIVertexOut {
    float4 position [[position]];
    float4 color;
};

vertex ZPUIVertexOut zpui_vertex(uint vertex_id [[vertex_id]],
                                 constant ZPUIFrameData &frame [[buffer(0)]]) {
    constexpr float2 corners[6] = {
        float2(0.0, 0.0),
        float2(0.0, 1.0),
        float2(1.0, 0.0),
        float2(1.0, 0.0),
        float2(0.0, 1.0),
        float2(1.0, 1.0),
    };

    const uint quad_index = vertex_id / 6;
    const uint corner_index = vertex_id - quad_index * 6;
    const ZPUIQuad quad = frame.quads[quad_index];
    const float2 pixel = float2(
        quad.rect.x + quad.rect.width * corners[corner_index].x,
        quad.rect.y + quad.rect.height * corners[corner_index].y
    );
    const float2 clip = float2(
        pixel.x / frame.drawable_size.x * 2.0 - 1.0,
        1.0 - pixel.y / frame.drawable_size.y * 2.0
    );

    ZPUIVertexOut out;
    out.position = float4(clip, 0.0, 1.0);
    out.color = quad.color;
    return out;
}

fragment float4 zpui_fragment(ZPUIVertexOut in [[stage_in]]) {
    return in.color;
}
