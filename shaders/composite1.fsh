#version 120
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#extension GL_ARB_shader_texture_lod : enable
#ifdef GLSLANG
#extension GL_GOOGLE_include_directive : enable
#endif

uniform sampler2D texture;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex1;
uniform sampler2D dhDepthTex0;

uniform float viewWidth, viewHeight, aspectRatio;
uniform vec3 cameraPosition, previousCameraPosition;
uniform mat4 gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferModelViewInverse;

varying vec4 color;
varying vec2 texCoord;

#include "/bsl_lib/antialiasing/taa.glsl"

// ========== SSAO Blur Configuration ==========
const int BLUR_SAMPLES = 2;
const float BLUR_RADIUS = 2.0;

// Bilateral blur for SSAO - preserves edges based on depth
float getBlurredAO(vec2 uv) {
    vec2 pixelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    
    float centerDepth = texture2D(dhDepthTex0, uv).r;
    float centerAO = texture2D(colortex2, uv).a;
    
    // If no DH terrain (depth = 1.0), return original AO
    if (centerDepth >= 1.0) {
        return centerAO;
    }
    
    float totalAO = centerAO;
    float totalWeight = 1.0;
    
    // Horizontal and vertical blur pattern
    for (int i = 1; i <= BLUR_SAMPLES; i++) {
        float offset = float(i) * BLUR_RADIUS * pixelSize.x;
        
        // Horizontal samples
        vec2 offsetH1 = vec2(offset, 0.0);
        vec2 offsetH2 = vec2(-offset, 0.0);
        
        // Vertical samples
        vec2 offsetV1 = vec2(0.0, offset);
        vec2 offsetV2 = vec2(0.0, -offset);
        
        // Sample depths and AO values
        float depthH1 = texture2D(dhDepthTex0, uv + offsetH1).r;
        float depthH2 = texture2D(dhDepthTex0, uv + offsetH2).r;
        float depthV1 = texture2D(dhDepthTex0, uv + offsetV1).r;
        float depthV2 = texture2D(dhDepthTex0, uv + offsetV2).r;
        
        float aoH1 = texture2D(colortex2, uv + offsetH1).a;
        float aoH2 = texture2D(colortex2, uv + offsetH2).a;
        float aoV1 = texture2D(colortex2, uv + offsetV1).a;
        float aoV2 = texture2D(colortex2, uv + offsetV2).a;
        
        // Depth-aware weights (reject samples with large depth difference)
        float depthThreshold = 0.02;
        float weightH1 = (abs(depthH1 - centerDepth) < depthThreshold && depthH1 < 1.0) ? 1.0 : 0.0;
        float weightH2 = (abs(depthH2 - centerDepth) < depthThreshold && depthH2 < 1.0) ? 1.0 : 0.0;
        float weightV1 = (abs(depthV1 - centerDepth) < depthThreshold && depthV1 < 1.0) ? 1.0 : 0.0;
        float weightV2 = (abs(depthV2 - centerDepth) < depthThreshold && depthV2 < 1.0) ? 1.0 : 0.0;
        
        // Gaussian falloff
        float gaussianWeight = exp(-float(i * i) / (2.0 * float(BLUR_SAMPLES * BLUR_SAMPLES)));
        
        totalAO += aoH1 * weightH1 * gaussianWeight;
        totalAO += aoH2 * weightH2 * gaussianWeight;
        totalAO += aoV1 * weightV1 * gaussianWeight;
        totalAO += aoV2 * weightV2 * gaussianWeight;
        
        totalWeight += weightH1 * gaussianWeight;
        totalWeight += weightH2 * gaussianWeight;
        totalWeight += weightV1 * gaussianWeight;
        totalWeight += weightV2 * gaussianWeight;
    }
    
    return totalAO / totalWeight;
}

void main()
{
    vec3 sampledColor = texture2DLod(colortex1, texCoord, 0.0).rgb;
    float prevAlpha = texture2DLod(colortex2, texCoord, 0.0).a;
    
    // Apply SSAO blur
    float blurredAO = getBlurredAO(texCoord);
    
    vec4 prev = TemporalAA(sampledColor, prevAlpha);
    
    // Store blurred AO in the alpha channel
    prev.a = blurredAO;
    
    /*DRAWBUFFERS:12*/
    gl_FragData[0] = vec4(sampledColor, 1.0);
    gl_FragData[1] = prev;
}