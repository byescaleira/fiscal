#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float labHash(float value) {
    return fract(sin(value) * 43758.5453);
}

static float labHash2(float2 value) {
    return fract(sin(dot(value, float2(12.9898, 78.233))) * 43758.5453);
}

static float labNoise(float2 value) {
    float2 cell = floor(value);
    float2 local = fract(value);
    float2 blend = local * local * (3.0 - 2.0 * local);
    float a = labHash2(cell);
    float b = labHash2(cell + float2(1.0, 0.0));
    float c = labHash2(cell + float2(0.0, 1.0));
    float d = labHash2(cell + float2(1.0, 1.0));
    return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}

[[ stitchable ]] half4 labRipple(
    float2 position, SwiftUI::Layer layer, float2 origin, float time,
    float amplitude, float frequency, float decay, float speed
) {
    float distance = length(position - origin);
    float elapsed = max(0.0, time - distance / speed);
    float wave = amplitude * sin(frequency * elapsed) * exp(-decay * elapsed);
    float2 direction = distance > 0.0 ? (position - origin) / distance : float2(0.0);
    half4 color = layer.sample(position + wave * direction);
    color.rgb += half(0.2 * wave / amplitude) * color.a;
    return color;
}

[[ stitchable ]] half4 labBurst(
    float2 position, half4 color, float2 size, float time, float duration, half4 tint
) {
    if (time <= 0.0 || time >= duration) {
        return half4(0.0);
    }
    float progress = time / duration;
    float travel = 1.0 - pow(1.0 - progress, 3.0);
    float2 center = size * 0.5;
    half4 result = half4(0.0);
    for (int index = 0; index < 14; index++) {
        float seed = float(index);
        float angle = seed / 14.0 * 6.2831853 + labHash(seed) * 0.45;
        float reach = mix(0.26, 0.48, labHash(seed + 7.0)) * size.x;
        float2 spot = center + float2(cos(angle), sin(angle)) * reach * travel;
        float radius = mix(1.6, 3.8, labHash(seed + 3.0)) * (1.0 - progress * 0.6);
        float coverage = 1.0 - smoothstep(radius - 0.8, radius + 0.8, length(position - spot));
        result = max(result, tint * half(coverage * (1.0 - progress)));
    }
    return result;
}

[[ stitchable ]] half4 labPaper(
    float2 position, half4 color, float2 size, float scale,
    float grain, float fiber, float2 light
) {
    float2 pixel = floor(position * scale);
    float speck = labHash2(pixel) - 0.5;
    float strands = labNoise(position * float2(0.035, 0.22)) + 0.5 * labNoise(position * float2(0.09, 0.5));
    float2 uv = position / size;
    float edge = smoothstep(0.35, 0.95, length((uv - 0.5) * float2(1.0, 1.15)) * 1.35);
    float glow = 1.0 - clamp(length(uv - light) * 1.1, 0.0, 1.0);
    half shade = half(1.0 - 0.1 * edge + 0.07 * glow);
    half texture = half(speck * grain + (strands - 0.75) * fiber);
    half3 rgb = color.rgb * shade + texture * color.a;
    return half4(clamp(rgb, half3(0.0), half3(color.a)), color.a);
}

[[ stitchable ]] half4 labSheen(
    float2 position, half4 color, float2 size, float2 tilt, float strength, float iridescent
) {
    float2 uv = position / size;
    float band = dot(uv - 0.5, normalize(float2(1.0, 0.65))) + tilt.x * 0.55 + tilt.y * 0.35;
    float glow = exp(-band * band * 38.0) * strength;
    half3 light = half3(glow);
    if (iridescent > 0.5) {
        float hue = band * 2.6 + tilt.x * 1.4;
        float3 spectrum = 0.5 + 0.5 * cos(6.2831853 * (hue + float3(0.0, 0.33, 0.67)));
        light = half3(spectrum * glow * 0.85);
    }
    return half4(min(color.rgb + light * color.a, half3(color.a)), color.a);
}

[[ stitchable ]] half4 labCollectible(
    float2 position, half4 color, float2 size, float2 tilt,
    float strength, float sparkle, float metal
) {
    float2 uv = position / size;
    float diagonal = dot(uv - 0.5, normalize(float2(1.0, 0.7)));
    float sweep = tilt.x * 0.6 + tilt.y * 0.4;
    float cosmos = labNoise(position * 0.045) * 0.6 + labNoise(position * 0.12) * 0.4;
    float lines = 0.5 + 0.5 * sin((position.x + position.y) * 1.6);
    float texture = mix(cosmos, lines, 0.18);
    float hue = diagonal * 1.8 + texture * 0.45 + tilt.x * 0.9 - tilt.y * 0.6;
    float3 rainbow = 0.5 + 0.5 * cos(6.2831853 * (hue + float3(0.0, 0.33, 0.67)));
    float shift = diagonal - sweep;
    float sheen = 0.3 + 0.7 * exp(-shift * shift * 9.0);
    float3 foil = rainbow * sheen * (0.55 + 0.45 * texture) * strength;
    float2 cell = floor(position / 9.0);
    float seed = labHash2(cell);
    float2 spot = (cell + 0.2 + 0.6 * float2(labHash2(cell + 3.1), labHash2(cell + 7.7))) * 9.0;
    float glint = pow(max(0.0, cos(6.2831853 * seed + tilt.x * 5.0 + tilt.y * 4.0)), 24.0);
    float shape = 1.0 - smoothstep(0.4, 1.6, length(position - spot));
    float3 sparkles = float3(glint * shape * sparkle * step(0.55, seed));
    float3 base = float3(0.62, 0.63, 0.66) * (0.75 + 0.25 * sheen) * metal;
    return half4(half3(min(base + foil + sparkles, float3(1.0))), 1.0h);
}
