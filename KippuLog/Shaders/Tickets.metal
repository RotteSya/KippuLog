#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ---------------------------------------------------------------------------
// Noise toolkit
// ---------------------------------------------------------------------------

static inline float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static inline float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1));
    float d = hash21(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static inline float fbm(float2 p) {
    float v = 0.0;
    float amp = 0.55;
    for (int i = 0; i < 3; i++) {
        v += amp * valueNoise(p);
        p = p * 2.07 + 11.5;
        amp *= 0.5;
    }
    return v;
}

// ---------------------------------------------------------------------------
// paperGrain — the tooth of ticket stock.
// Fine speckle + faint horizontal fibre, ±3% luminance. Alpha untouched.
// ---------------------------------------------------------------------------

[[ stitchable ]] half4 paperGrain(float2 position, half4 color, float2 size, float seed) {
    if (color.a <= 0.001h) { return color; }
    float2 uv = position / max(size.x, 1.0);
    float speckle = valueNoise(uv * 420.0 + seed * 7.31) - 0.5;
    float fibre = valueNoise(float2(uv.x * 26.0, uv.y * 240.0) + seed * 3.7) - 0.5;
    float tone = speckle * 0.040 + fibre * 0.022;
    half3 rgb = clamp(color.rgb + half3(tone), 0.0h, 1.0h);
    return half4(rgb, color.a);
}

// ---------------------------------------------------------------------------
// holoSheen — angle-dependent iridescent band, like a security foil.
// `tilt` is the device/drag attitude in [-1, 1]²; `strength` 0…1.
// ---------------------------------------------------------------------------

static inline half3 spectral(float t) {
    // Soft pastel rainbow, not laser-disc gaudy.
    float3 c = 0.5 + 0.5 * cos(6.28318 * (t + float3(0.00, 0.33, 0.67)));
    return half3(mix(float3(1.0), c, 0.85));
}

[[ stitchable ]] half4 holoSheen(float2 position, half4 color, float2 size,
                                 float2 tilt, float strength) {
    if (color.a <= 0.001h || strength <= 0.001) { return color; }
    float2 uv = position / max(size.x, 1.0);
    float axis = dot(uv, normalize(float2(1.0, 0.42)));
    float band = axis * 2.2 - tilt.x * 1.4 - tilt.y * 0.6;
    float mask = exp(-pow((fract(band) - 0.5) * 3.2, 2.0));
    half3 tint = spectral(axis * 1.6 + tilt.x * 0.8);
    float gleam = mask * strength * 0.34;
    half3 rgb = clamp(color.rgb + tint * half(gleam), 0.0h, 1.0h);
    return half4(rgb, color.a);
}

// ---------------------------------------------------------------------------
// scanSweep — OCR reading light. A warm band sweeps top→bottom as
// `progress` runs 0→1; faint afterglow above the band.
// ---------------------------------------------------------------------------

[[ stitchable ]] half4 scanSweep(float2 position, half4 color, float2 size, float progress) {
    if (color.a <= 0.001h) { return color; }
    float y = position.y / max(size.y, 1.0);
    float band = y - (progress * 1.3 - 0.15);
    float core = exp(-pow(band * 26.0, 2.0));
    float tail = band < 0.0 ? exp(band * 9.0) * 0.18 : 0.0;
    half3 warm = half3(1.0, 0.93, 0.78);
    half3 rgb = clamp(color.rgb + warm * half(core * 0.5 + tail), 0.0h, 1.0h);
    return half4(rgb, color.a);
}

// ---------------------------------------------------------------------------
// inkDissolve — the ticket scatters into sumi dust. progress 0→1.
// Pixels vanish in noise order; the dissolving edge tints to ink.
// ---------------------------------------------------------------------------

[[ stitchable ]] half4 inkDissolve(float2 position, half4 color, float2 size,
                                   float progress, float seed) {
    if (progress <= 0.001) { return color; }
    if (color.a <= 0.001h) { return color; }
    float2 uv = position / max(size.x, 1.0);
    float n = fbm(uv * 9.0 + seed * 13.7);
    float p = progress * 1.15;
    float keep = smoothstep(p - 0.06, p + 0.02, n + 0.08);
    float edge = smoothstep(p - 0.16, p - 0.02, n + 0.08) * (1.0 - keep);
    half3 ink = half3(0.13, 0.11, 0.09);
    half3 rgb = mix(ink, color.rgb, half(saturate(1.0 - edge * 1.6)));
    return half4(rgb, color.a * half(keep));
}

// ---------------------------------------------------------------------------
// gateSquish — distortion as the ticket feeds through the gate slot.
// progress 0→1 squeezes x around the slot line and adds a paper bow.
// ---------------------------------------------------------------------------

[[ stitchable ]] float2 gateSquish(float2 position, float2 size, float progress) {
    if (progress <= 0.001) { return position; }
    float2 uv = position / size;
    float pinch = progress * 0.18;
    float cx = uv.x - 0.5;
    float bow = sin(uv.x * 3.14159) * pinch * 14.0;
    return float2(position.x - cx * pinch * size.x * 0.6,
                  position.y + bow * (uv.y - 0.5) * 2.0);
}
