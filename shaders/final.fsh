#version 130

#ifdef GLSLANG
#extension GL_GOOGLE_include_directive : enable
#endif

#include "settings.glsl"

uniform sampler2D colortex1;
uniform float viewWidth;
uniform float viewHeight;

in vec2 coord0;
out vec4 fragColor;

#if SHARPENING == 0
// Off
void SharpenFilter(inout vec3 color, vec2 coord) {}
#elif SHARPENING == 1
#include "bsl_lib/unsharp_mask.glsl"
#elif SHARPENING == 2

void SharpenFilter(inout vec3 color, vec2 textureCoord) {
    vec2 texOffset = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    
    vec3 a = texture(colortex1, textureCoord + texOffset * vec2(-1, -1)).rgb;
    vec3 b = texture(colortex1, textureCoord + texOffset * vec2(0, -1)).rgb;
    vec3 c = texture(colortex1, textureCoord + texOffset * vec2(1, -1)).rgb;
    vec3 d = texture(colortex1, textureCoord + texOffset * vec2(-1, 0)).rgb;
    vec3 e = color;
    vec3 f = texture(colortex1, textureCoord + texOffset * vec2(1, 0)).rgb;
    vec3 g = texture(colortex1, textureCoord + texOffset * vec2(-1, 1)).rgb;
    vec3 h = texture(colortex1, textureCoord + texOffset * vec2(0, 1)).rgb;
    vec3 i = texture(colortex1, textureCoord + texOffset * vec2(1, 1)).rgb;

    vec3 mnRGB = min(min(min(d, e), min(f, b)), h) + min(min(min(a, g), c), i);
    vec3 mxRGB = max(max(max(d, e), max(f, b)), h) + max(max(max(a, g), c), i);

    vec3 rcpMxRGB = 1.0 / mxRGB;
    vec3 ampRGB = clamp(min(mnRGB, 2.0 - mxRGB) * rcpMxRGB, 0.0, 1.0);

    ampRGB = inversesqrt(ampRGB);
    float peak = 8.0 - 3.0 * CAS_AMOUNT;
    vec3 wRGB = -1.0 / (ampRGB * peak);
    vec3 rcpWeightRGB = 1.0 / (1.0 + 4.0 * wRGB);

    color = clamp(((b + d + f + h) * wRGB + e) * rcpWeightRGB, 0.0, 1.0);
}
#endif

void main() {
    vec3 color = texture(colortex1, coord0).rgb; // Direct texture fetching
    SharpenFilter(color, coord0);
    fragColor = vec4(color, 1.0);
}
