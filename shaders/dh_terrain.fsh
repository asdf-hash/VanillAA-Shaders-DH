#version 120
#define DISTANT_HORIZONS
#include "/settings.glsl"
uniform sampler2D lightmap;
uniform sampler2D noisetex;
// Standard uniforms
uniform float viewWidth;
uniform float viewHeight;
uniform sampler2D depthtex0;
uniform int dhRenderDistance;
uniform vec3 fogColor;
uniform vec3 cameraPosition;
uniform int isEyeInWater;
uniform float far;
varying vec4 fragColor;
varying vec2 texCoord1;
varying vec3 viewPos;
in vec3 viewSpacePosition;
in vec3 playerPos;

float Noise3D(vec3 p) {
    p.z = fract(p.z) * 32.0;
    float iz = floor(p.z);
    float fz = fract(p.z);
    vec2 a_off = vec2(23.0, 29.0) * (iz) / 128.0;
    vec2 b_off = vec2(23.0, 29.0) * (iz + 1.0) / 128.0;
    float a = texture2D(noisetex, p.xy + a_off).r;
    float b = texture2D(noisetex, p.xy + b_off).r;
    return mix(a, b, fz);
}

float max0(float x) {
    return max(x, 0.0);
}

void main() {
if(isEyeInWater != 0){discard;}
    vec2 texCoord = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    float depth = texture(depthtex0, texCoord).r;
    
    if (depth != 1.0) {
        discard;
    }
    
    vec4 color = fragColor * texture2D(lightmap, texCoord1);
    
    // Apply 3D noise for visual detail
    vec3 noisePos = floor((playerPos + cameraPosition) * 4.0 + 0.001) / 32.0;
    float noiseTexture = Noise3D(noisePos) + 0.5;
    float noiseFactor = max0(1.0 - 0.3 * dot(color.rgb, color.rgb));
    color.rgb *= pow(noiseTexture, 0.35 * noiseFactor);
    
    // Fog with configurable start distance
    float distanceFromCamera = distance(vec3(0), viewSpacePosition);
    float maxFogDistance = float(dhRenderDistance);    
    float minFogDistance = float(dhRenderDistance) * DH_FOG_START;
    float fogBlendValue = clamp((distanceFromCamera - minFogDistance) / (maxFogDistance - minFogDistance), 0.0, 1.0);
    
    color = mix(color, vec4(fogColor, 1.0), fogBlendValue);
    
    gl_FragData[0] = color;
}