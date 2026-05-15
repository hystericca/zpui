#include <metal_stdlib>
using namespace metal;

struct ZPUIVertex {
    float4 position;
    float4 color;
};

struct ZPUIVertexOut {
    float4 position [[position]];
    float4 color;
};

vertex ZPUIVertexOut zpui_vertex(uint vertex_id [[vertex_id]],
                                 constant ZPUIVertex *vertices [[buffer(0)]]) {
    ZPUIVertex vtx = vertices[vertex_id];
    ZPUIVertexOut out;
    out.position = vtx.position;
    out.color = vtx.color;
    return out;
}

fragment float4 zpui_fragment(ZPUIVertexOut in [[stage_in]]) {
    return in.color;
}
