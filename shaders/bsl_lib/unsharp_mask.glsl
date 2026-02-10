// Precalculated constant
const float SHARP_STRENGTH = 0.125;

void SharpenFilter(inout vec3 color, vec2 coord) {
    // Precalculate view-dependent values
    vec2 view = 1.0 / vec2(viewWidth, viewHeight);
    float mult = MC_RENDER_QUALITY * SHARP_STRENGTH;
    
    // Apply center pixel scaling
    color *= MC_RENDER_QUALITY * 0.5 + 1.0;

    // Unrolled loop with optimized texture sampling and vector operations
    color -= texture2DLod(colortex1, coord + vec2( view.x,  0.0), 0.0).rgb * mult;
    color -= texture2DLod(colortex1, coord + vec2( 0.0,  view.y), 0.0).rgb * mult;
    color -= texture2DLod(colortex1, coord + vec2(-view.x,  0.0), 0.0).rgb * mult;
    color -= texture2DLod(colortex1, coord + vec2( 0.0, -view.y), 0.0).rgb * mult;
}