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
// ticketPaper — the whole physical sheet in one pass.
//
// Pulp mottle, fibre flecks, tooth speckle, a braided two-bundle sine
// guilloche underprint (the security engraving on real MARS stock),
// and cut-edge darkening. `tint` is the operator's lattice colour
// (alpha = print strength); `fiberAxis` > 0.5 biases the grain
// horizontally (edmondson card).
// ---------------------------------------------------------------------------

[[ stitchable ]] half4 ticketPaper(float2 position, half4 color, float2 size,
                                   half4 tint, float seed, float fiberAxis) {
    if (color.a <= 0.001h) { return color; }
    float2 uv = position / size;
    float sd = fract(seed * 0.0731) * 19.7;

    // Pulp density mottle — broad, irregular.
    float mottle = fbm(uv * float2(8.0, 6.5) + sd) - 0.5;
    half3 paper = color.rgb + half3(mottle * 0.020);

    // Tooth speckle — fine grain.
    float tooth = (valueNoise(uv * float2(size.x, size.y) * 1.35 + sd * 3.1) - 0.5) * 0.026;
    paper += half3(tooth);

    // Sparse fibre flecks, elongated along the grain axis.
    float2 fibreFreq = fiberAxis > 0.5
        ? float2(26.0, 210.0)
        : float2(150.0, 190.0);
    float fibre = valueNoise(uv * fibreFreq + sd * 5.7);
    paper -= half3(smoothstep(0.80, 0.94, fibre) * 0.045);

    // Guilloche: two counter-phase sine line bundles braid into the
    // classic engraved net. Phase is the ticket's own.
    if (tint.a > 0.001h) {
        float phase = fract(seed * 0.1234) * 6.28318;
        float rows = 30.0;
        float c1 = uv.y * rows + 0.52 * sin(uv.x * 9.8 + phase);
        float c2 = uv.y * rows + 0.52 * sin(uv.x * 9.8 + phase + 3.14159) + 0.5;
        float l1 = smoothstep(0.105, 0.060, abs(fract(c1) - 0.5));
        float l2 = smoothstep(0.105, 0.060, abs(fract(c2) - 0.5));
        float net = max(l1, l2);
        // Impression varies faintly with pulp density.
        net *= 0.78 + 0.22 * mottle * 2.0;
        paper = mix(paper, half3(tint.rgb), half(net) * tint.a);
    }

    // Cut-edge darkening + breath of corner vignette.
    float ex = min(uv.x, 1.0 - uv.x);
    float ey = min(uv.y, 1.0 - uv.y);
    float edge = 1.0 - smoothstep(0.0, 0.022, min(ex, ey));
    paper *= (1.0h - half(edge) * 0.055h);

    return half4(paper, color.a);
}

// ---------------------------------------------------------------------------
// inkPress — letterpress relief. Light falls from the top: the leading
// edge of every glyph pools a little darker, the paper just past its
// trailing edge catches a hairline of light. Sampled at ±1.4px.
// ---------------------------------------------------------------------------

[[ stitchable ]] half4 inkPress(float2 position, SwiftUI::Layer layer,
                                float2 size, float strength) {
    half4 c = layer.sample(position);
    if (c.a <= 0.001h) { return c; }
    half4 up = layer.sample(position + float2(0.0, -1.4));
    float lc = dot(float3(c.rgb), float3(0.299, 0.587, 0.114));
    float lu = dot(float3(up.rgb), float3(0.299, 0.587, 0.114));
    float d = lu - lc;
    half3 rgb = c.rgb;
    rgb -= half3(max(d, 0.0) * strength);
    rgb += half3(max(-d, 0.0) * strength * 0.85);
    return half4(rgb, c.a);
}

// ---------------------------------------------------------------------------
// studioLight — the dark room. A warm elliptical pool of light around
// the exhibit, deep falloff, blue-less shadow, and a hash dither so the
// falloff never bands.
// ---------------------------------------------------------------------------

[[ stitchable ]] half4 studioLight(float2 position, half4 color, float2 size,
                                   float2 center, float radius, float warmth) {
    float2 uv = position / max(size, float2(1.0));
    float2 d2 = (uv - center) * float2(size.x / size.y, 1.0);
    float d = length(d2) / max(radius, 0.001);
    float pool = exp(-d * d * 1.85);
    float rim = exp(-d * 5.5) * 0.5;            // hot core right under the lamp

    half3 deep = half3(0.040, 0.033, 0.026);
    half3 warm = half3(0.115, 0.095, 0.072) * (1.0 + warmth * 0.35);
    half3 col = mix(deep, warm, half(saturate(pool + rim)));

    float n = hash21(position * 0.7) - 0.5;
    col += half3(n / 255.0 * 2.4);
    return half4(col, 1.0h);
}

// ---------------------------------------------------------------------------
// studioAir — the lamp's cone has air in it. A handful of dust motes
// drift up through the pool of light, each a soft gaussian point on its
// own slow sinusoid, lit only where the pool is lit and never brighter
// than a breath. Layered over studioLight on the stage.
// ---------------------------------------------------------------------------

[[ stitchable ]] half4 studioAir(float2 position, half4 color, float2 size,
                                 float2 center, float radius, float time) {
    float2 uv = position / max(size, float2(1.0));
    float2 d2 = (uv - center) * float2(size.x / size.y, 1.0);
    float pool = exp(-dot(d2, d2) / max(radius * radius, 0.001) * 1.85);
    if (pool < 0.05) { return color; }

    float glow = 0.0;
    const float motes = 11.0;
    for (float i = 0.0; i < motes; i += 1.0) {
        float seed = i * 17.13 + 4.7;
        float speed = 0.014 + fract(seed * 0.311) * 0.020;
        // Each mote climbs slowly, wrapping through the frame, swaying.
        float y = fract(fract(seed * 0.777) - time * speed);
        float x = fract(seed * 0.531)
                + sin(time * (0.10 + fract(seed * 0.213) * 0.16) + seed) * 0.055;
        float2 p = float2(x, y);
        float2 dm = (uv - p) * float2(size.x / size.y, 1.0);
        float dist2 = dot(dm, dm);
        // Size and twinkle are the mote's own.
        float sz = 7.0e-6 + fract(seed * 0.157) * 1.3e-5;
        float tw = 0.60 + 0.40 * sin(time * (0.5 + fract(seed * 0.371)) + seed * 3.1);
        glow += exp(-dist2 / sz) * tw;
    }

    half3 warmDust = half3(1.0, 0.90, 0.72);
    half3 col = color.rgb + warmDust * half(glow * pool * 0.16);
    return half4(col, color.a);
}

// ---------------------------------------------------------------------------
// holoSheen — anisotropic paper gloss that answers the hand.
// A soft white gloss band sweeps with tilt; only at strong angles do
// faint spectral fringes bloom at the band's edges. Calm by default.
// ---------------------------------------------------------------------------

static inline half3 spectral(float t) {
    float3 c = 0.5 + 0.5 * cos(6.28318 * (t + float3(0.00, 0.33, 0.67)));
    return half3(mix(float3(1.0), c, 0.6));
}

[[ stitchable ]] half4 holoSheen(float2 position, half4 color, float2 size,
                                 float2 tilt, float strength) {
    if (color.a <= 0.001h || strength <= 0.001) { return color; }
    float2 uv = position / size;
    float mag = length(tilt);

    float axis = dot(uv - 0.5, normalize(float2(1.0, 0.55)));
    float band = axis * 1.6 - tilt.x * 0.9 - tilt.y * 0.45;
    float gloss = exp(-band * band * 22.0);

    // White gloss, gently.
    half3 rgb = color.rgb + half3(gloss * strength * 0.16);

    // Spectral fringes at the gloss edges, only under real tilt.
    float fringe = exp(-pow(abs(band) - 0.12, 2.0) * 90.0) * saturate(mag * 1.2 - 0.15);
    rgb += spectral(axis * 2.0 + tilt.x) * half(fringe * strength * 0.18);

    return half4(clamp(rgb, 0.0h, 1.0h), color.a);
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
// shredFall — the gate takes the ticket back. The card tears into vertical
// strips; each waits its hashed turn, then falls under gravity with a
// flutter and a slight shear, its torn top edge inked, fading as it goes.
// progress 0→1.
// ---------------------------------------------------------------------------

[[ stitchable ]] half4 shredFall(float2 position, SwiftUI::Layer layer,
                                 float2 size, float progress, float seed) {
    if (progress <= 0.001) { return layer.sample(position); }

    float stripCount = 13.0;
    float stripW = max(size.x / stripCount, 1.0);
    float idx = floor(position.x / stripW);
    float h = hash21(float2(idx * 7.31 + seed, seed * 0.77 + idx * 1.13));

    float delay = h * 0.42;
    float p = clamp((progress - delay) / 0.58, 0.0, 1.0);
    if (p <= 0.0) { return layer.sample(position); }

    // Gravity, flutter, and a hash-signed shear (the strip tips as it falls).
    float fall = p * p * size.y * 1.5;
    float sway = sin(p * 9.0 + h * 6.28318) * stripW * 0.6 * p;
    float yNorm = position.y / max(size.y, 1.0);
    float shear = (h - 0.5) * 40.0 * p * (yNorm - 0.5);

    float2 src = float2(position.x - sway - shear, position.y - fall);
    float minX = idx * stripW;
    float maxX = (idx + 1.0) * stripW;
    if (src.x < minX || src.x >= maxX || src.y < 0.0) { return half4(0.0); }

    half4 c = layer.sample(src);
    // Torn leading edge picks up ink for its last moment.
    float edge = smoothstep(24.0, 0.0, src.y);
    half3 ink = half3(0.16, 0.13, 0.10) * c.a;
    c.rgb = mix(c.rgb, ink, half(edge * 0.8));

    float fade = 1.0 - smoothstep(0.55, 1.0, p);
    return c * half(fade);
}

// ---------------------------------------------------------------------------
// gateSquish — distortion as the ticket feeds through the gate slot.
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

// ---------------------------------------------------------------------------
// paperGrain — kept for light-touch grain on non-plate surfaces.
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
