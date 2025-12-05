#version 120

// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "/settings.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;      // Regular terrain depth
uniform sampler2D dhDepthTex0;    // DH terrain depth

uniform mat4 dhProjectionInverse;
uniform mat4 dhProjection;

uniform float viewWidth;
uniform float viewHeight;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform int frameCounter;

varying vec4 color;
varying vec2 coord0;

const bool colortex2Clear = false;

// ========== SSAO Configuration ==========
const float SSAO_RADIUS = 0.7; 
const float SSAO_BIAS = 0.025;
const float SSAO_INTENSITY = 1.0;

// Sample kernel - spiral pattern for better distribution
const vec2 sampleKernel[16] = vec2[16](
    vec2(0.2343, 0.8765), vec2(-0.5432, 0.3456), vec2(0.7654, -0.2341),
    vec2(-0.3214, -0.7632), vec2(0.5678, 0.4321), vec2(-0.8765, -0.1234),
    vec2(0.1234, -0.5678), vec2(-0.6543, 0.7654), vec2(0.8765, 0.1234),
    vec2(-0.2345, -0.4567), vec2(0.4567, -0.8765), vec2(-0.7654, 0.5432),
    vec2(0.3456, 0.6543), vec2(-0.4567, -0.3456), vec2(0.6543, -0.6543),
    vec2(-0.1234, 0.2345)
);

// Improved noise function with better distribution
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Linearize depth
float linearizeDepth(float depth, float near, float far) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

// Reconstruct view space position from depth
vec3 getViewPosition(vec2 uv, float depth) {
    vec4 clipSpace = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewSpace = dhProjectionInverse * clipSpace;
    return viewSpace.xyz / viewSpace.w;
}

// Calculate normal from depth using screen-space derivatives
vec3 reconstructNormal(vec2 uv, float depth) {
    vec2 pixelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    
    float depthR = texture2D(dhDepthTex0, uv + vec2(pixelSize.x, 0.0)).r;
    float depthU = texture2D(dhDepthTex0, uv + vec2(0.0, pixelSize.y)).r;
    
    vec3 posC = getViewPosition(uv, depth);
    vec3 posR = getViewPosition(uv + vec2(pixelSize.x, 0.0), depthR);
    vec3 posU = getViewPosition(uv + vec2(0.0, pixelSize.y), depthU);
    
    vec3 dx = posR - posC;
    vec3 dy = posU - posC;
    
    return normalize(cross(dx, dy));
}

// Rotate 2D vector
vec2 rotate2D(vec2 v, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

// Calculate SSAO for DH terrain only
float calculateSSAO(vec2 uv, float depth) {
    // Get view space position
    vec3 position = getViewPosition(uv, depth);
    
    // Reconstruct normal
    vec3 normal = reconstructNormal(uv, depth);
    
    // Scale radius based on depth (smaller radius for distant terrain)
    float depthLinear = linearizeDepth(depth, dhNearPlane, dhFarPlane);
    float radiusScale = SSAO_RADIUS * (1.0 - depthLinear * 0.8);
    
    // High-frequency noise with temporal variation
    vec2 noiseCoord = uv * vec2(viewWidth, viewHeight);
    float noise1 = hash(noiseCoord * 0.1 + float(frameCounter % 64) * 0.01);
    float noise2 = hash(noiseCoord * 0.37 + float(frameCounter % 64) * 0.03);
    float noiseAngle = noise1 * 6.28318;
    
    // Create tangent space basis for proper hemisphere sampling
    vec3 randomVec = normalize(vec3(noise1 * 2.0 - 1.0, noise2 * 2.0 - 1.0, 0.0));
    vec3 tangent = normalize(randomVec - normal * dot(randomVec, normal));
    vec3 bitangent = cross(normal, tangent);
    mat3 TBN = mat3(tangent, bitangent, normal);
    
    float occlusion = 0.0;
    int validSamples = 0;
    
    // Sample around the point
    for (int i = 0; i < SSAO_SAMPLES; i++) {
        // Rotate sample in 2D
        vec2 rotatedSample = rotate2D(sampleKernel[i], noiseAngle);
        
        // Convert to 3D hemisphere sample
        float scale = float(i + 1) / float(SSAO_SAMPLES);
        vec3 sampleOffset = vec3(rotatedSample * scale, scale * 0.5);
        
        // Transform by TBN to orient around normal
        sampleOffset = TBN * normalize(sampleOffset);
        vec3 samplePos = position + sampleOffset * radiusScale;
        
        // Project sample back to screen space
        vec4 offset = dhProjection * vec4(samplePos, 1.0);
        offset.xyz /= offset.w;
        offset.xy = offset.xy * 0.5 + 0.5;
        
        // Check if sample is on screen
        if (offset.x < 0.0 || offset.x > 1.0 || offset.y < 0.0 || offset.y > 1.0) {
            continue;
        }
        
        // Sample depth at offset position
        float sampleDepth = texture2D(dhDepthTex0, offset.xy).r;
        vec3 sampleWorldPos = getViewPosition(offset.xy, sampleDepth);
        
        // Range check and accumulate
        float rangeCheck = smoothstep(0.0, 1.0, radiusScale / abs(position.z - sampleWorldPos.z));
        occlusion += (sampleWorldPos.z >= samplePos.z + SSAO_BIAS ? 1.0 : 0.0) * rangeCheck;
        validSamples++;
    }
    
    if (validSamples == 0) return 1.0;
    
    occlusion = 1.0 - (occlusion / float(validSamples));
    return pow(occlusion, SSAO_INTENSITY);
}

void main()
{
    float temporalData = 0.0;
    vec3 temporalColor = texture2D(colortex2, coord0).rgb;
    
    // Get base color
    vec3 baseColor = (color * texture2D(colortex0, coord0)).rgb;
    
    // Sample both depth buffers
    float regularDepth = texture2D(depthtex0, coord0).r;
    float dhDepth = texture2D(dhDepthTex0, coord0).r;
    
    float ao = 1.0;
    
    // Only apply SSAO to DH terrain (depth < 1.0 means DH terrain is present)
    // Skip if regular terrain is closer (vanilla terrain already has good voxel AO)
    if (dhDepth < 1.0 && regularDepth >= 1.0) {
        // Only DH terrain visible - apply SSAO
        ao = calculateSSAO(coord0, dhDepth);
        
        // Apply distance-based falloff using fog start and fog start + 0.1
        float depthLinear = linearizeDepth(dhDepth, dhNearPlane, dhFarPlane);
        float falloffStart = 0.1;
        float falloffEnd = 0.15;
        float falloff = 1.0 - smoothstep(falloffStart, falloffEnd, depthLinear);
        ao = mix(1.0, ao, falloff);
    }
    
    // Apply SSAO to color
    vec3 finalColor = baseColor * ao;

    /*DRAWBUFFERS:12*/
    gl_FragData[0] = vec4(finalColor, 1.0);
    gl_FragData[1] = vec4(temporalColor, temporalData);
}