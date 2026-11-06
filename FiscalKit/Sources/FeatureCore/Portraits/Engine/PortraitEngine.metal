#include <metal_stdlib>
using namespace metal;

struct PortraitUniforms {
    float2 scale;
    float2 offset;
};

struct PortraitPaint {
    float4 from;
    float4 to;
    float2 start;
    float2 end;
    float opacity;
};

struct PortraitVertexOut {
    float4 position [[position]];
    float2 rig;
};

vertex PortraitVertexOut portraitVertex(uint id [[vertex_id]],
                                        const device float2 *points [[buffer(0)]],
                                        constant PortraitUniforms &uniforms [[buffer(1)]]) {
    PortraitVertexOut out;
    float2 point = points[id];
    out.position = float4(point * uniforms.scale + uniforms.offset, 0.0, 1.0);
    out.rig = point;
    return out;
}

fragment float4 portraitSolid(PortraitVertexOut in [[stage_in]],
                              constant PortraitPaint &paint [[buffer(0)]]) {
    float alpha = paint.from.a * paint.opacity;
    return float4(paint.from.rgb * alpha, alpha);
}

fragment float4 portraitGradient(PortraitVertexOut in [[stage_in]],
                                 constant PortraitPaint &paint [[buffer(0)]]) {
    float2 axis = paint.end - paint.start;
    float amount = clamp(dot(in.rig - paint.start, axis) / max(dot(axis, axis), 1e-6), 0.0, 1.0);
    float4 color = mix(paint.from, paint.to, amount);
    float alpha = color.a * paint.opacity;
    return float4(color.rgb * alpha, alpha);
}
