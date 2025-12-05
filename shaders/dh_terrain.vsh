#version 120
#define DISTANT_HORIZONS
#ifdef GLSLANG
#extension GL_GOOGLE_include_directive : enable
#endif

// Note: dhMaterialId is automatically declared by Iris

// Model-view matrix and its inverse
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

// Distant Horizons projection matrices
uniform mat4 dhProjection;

// Pass vertex information to fragment shader
varying vec4 fragColor;
varying vec2 texCoord1;
varying float materialId;
varying vec3 viewPos;
varying vec3 viewSpacePosition;
varying vec3 playerPos;  // Added for noise sampling

uniform int frameCounter;
uniform float viewWidth, viewHeight;

#include "bsl_lib/util/jitter.glsl"

void main()
{
    // Get material ID
    materialId = dhMaterialId;
    
    // Transform vertex position to view space
    vec4 viewSpace = gl_ModelViewMatrix * gl_Vertex;
    viewPos = viewSpace.xyz;
    viewSpacePosition = viewSpace.xyz;
    
    // Transform to world/player space for noise sampling
    playerPos = (gbufferModelViewInverse * viewSpace).xyz;
    
    // Calculate clip position using DH projection matrix
    gl_Position = dhProjection * gbufferModelView * gbufferModelViewInverse * viewSpace;
    
    // Calculate view space normal for lighting
    vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
    vec3 worldNormal = (gbufferModelViewInverse * vec4(normal, 0.0)).xyz;
    
    // Calculate simple directional lighting similar to textured shader
    float lightIntensity = min(
        worldNormal.x * worldNormal.x * 0.6 + 
        worldNormal.y * worldNormal.y * 0.25 * (3.0 + worldNormal.y) + 
        worldNormal.z * worldNormal.z * 0.8, 
        1.0
    );
    
    // Pass vertex color with lighting to fragment shader
    fragColor = vec4(gl_Color.rgb * lightIntensity, gl_Color.a);
    
    // Pass lightmap coordinates
    texCoord1 = (gl_TextureMatrix[1] * gl_MultiTexCoord2).xy;
    
    // Apply temporal anti-aliasing jitter
    gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
}