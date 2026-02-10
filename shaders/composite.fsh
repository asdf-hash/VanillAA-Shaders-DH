#version 120

#include "/settings.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;      
uniform sampler2D dhDepthTex0;    

uniform mat4 dhProjectionInverse;
uniform mat4 dhProjection;
uniform mat4 gbufferProjection; 

uniform float viewWidth;
uniform float viewHeight;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform int dhRenderDistance;    
uniform int frameCounter;

varying vec4 color;
varying vec2 coord0;
varying float constantPart;
varying float farMinusNear;
varying float farPlusNear;

const bool colortex2Clear = false;
const vec2 sampleKernel[12] = vec2[12](
    vec2(0.2343, 0.8765), vec2(-0.5432, 0.3456), vec2(0.7654, -0.2341),
    vec2(-0.3214, -0.7632), vec2(0.5678, 0.4321), vec2(-0.8765, -0.1234),
    vec2(0.1234, -0.5678), vec2(-0.6543, 0.7654), vec2(0.8765, 0.1234),
    vec2(-0.2345, -0.4567), vec2(0.4567, -0.8765), vec2(-0.7654, 0.5432)
);

float hash(vec2 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * (p.x + p.y));
}

float linearizeDepth(float depth, float near, float far) {
    return (2.0 * near * far) / (far + near - depth * (far - near));
}

vec3 getViewPosition(vec2 uv, float depth) {
    vec4 clipSpace = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewSpace = dhProjectionInverse * clipSpace;
    return viewSpace.xyz / viewSpace.w;
}

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

vec2 rotate2D(vec2 v, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

float calculateSSAO(vec2 uv, float depth, vec3 viewPos) {
    float depthLinear = linearizeDepth(depth, dhNearPlane, dhFarPlane);
    vec3 position = getViewPosition(uv, depth);
    vec3 normal = reconstructNormal(uv, depth);

    float logScale = log2(depthLinear);
    float radius = SSAO_RADIUS + max(logScale-8.6,0.0)*1.2;
    
    vec2 noiseCoord = uv * vec2(viewWidth, viewHeight);
    float noise = hash(noiseCoord * 0.1 + float(frameCounter % 64) * 0.01);
    float noiseAngle = noise * 6.28318;
    
    vec3 randomVec = normalize(vec3(noise * 2.0 - 1.0, hash(noiseCoord * 0.37) * 2.0 - 1.0, 0.0));
    vec3 tangent = normalize(randomVec - normal * dot(randomVec, normal));
    vec3 bitangent = cross(normal, tangent);
    mat3 TBN = mat3(tangent, bitangent, normal);
    
    float occlusion = 0.0;
    int validSamples = 0;
    
    for (int i = 0; i < SSAO_SAMPLES; i++) {
        vec2 rotatedSample = rotate2D(sampleKernel[i], noiseAngle);
        
        float scale = float(i + 1) / 12.0;
        vec3 sampleOffset = vec3(rotatedSample * scale, scale * 0.6); 
        
        sampleOffset = TBN * normalize(sampleOffset);
        vec3 samplePos = position + sampleOffset * radius;
        
        vec4 offset = dhProjection * vec4(samplePos, 1.0);
        offset.xyz /= offset.w;
        offset.xy = offset.xy * 0.5 + 0.5;
        
        if (offset.x < 0.0 || offset.x > 1.0 || offset.y < 0.0 || offset.y > 1.0) {
            continue;
        }
        
        float sampleDepth = texture2D(dhDepthTex0, offset.xy).r;
        vec3 sampleWorldPos = getViewPosition(offset.xy, sampleDepth);
        
        float delta = sampleWorldPos.z - samplePos.z;
        float rangeCheck = smoothstep(0.0, 1.0, radius / (abs(position.z - sampleWorldPos.z) + 0.001));
        
        occlusion += (delta >= SSAO_BIAS ? 1.0 : 0.0) * rangeCheck;
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
    
    vec3 baseColor = (color * texture2D(colortex0, coord0)).rgb;
    
    float regularDepth = texture2D(depthtex0, coord0).r;
    float dhDepth = texture2D(dhDepthTex0, coord0).r;
    
    float ao = 1.0;
    
    if (dhDepth < 1.0 && regularDepth >= 1.0) {
        vec3 viewPos = getViewPosition(coord0, dhDepth);
        ao = calculateSSAO(coord0, dhDepth, viewPos);
        
        float distanceFromCamera = length(viewPos);
        float maxFogDistance = float(dhRenderDistance);
        float minFogDistance = float(dhRenderDistance) * (DH_FOG_START);
        float fogBlendValue = clamp((distanceFromCamera - minFogDistance) / (maxFogDistance - minFogDistance), 0.0, 1.0);
        
        ao = mix(ao, 1.0, fogBlendValue);
    }
    
    vec3 finalColor = baseColor * ao;

    /*DRAWBUFFERS:12*/
    gl_FragData[0] = vec4(finalColor, 1.0);
    gl_FragData[1] = vec4(temporalColor, temporalData);
}