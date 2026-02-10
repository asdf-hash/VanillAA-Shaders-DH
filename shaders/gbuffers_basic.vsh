#version 120

#ifdef GLSLANG
#extension GL_GOOGLE_include_directive : enable
#endif

// Model-view matrix and its inverse
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

// Pass vertex information to fragment shader
varying vec4 color;

uniform int frameCounter;
uniform float viewWidth, viewHeight;

#include "bsl_lib/util/jitter.glsl"

void main()
{
    // Transform vertex position to world space using inverse model-view matrix
    vec3 worldPos = (gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz;

    // Calculate clip position using transformed world position
    gl_Position = gl_ProjectionMatrix * gbufferModelView * vec4(worldPos, 1.0);
    gl_FogFragCoord = length(worldPos);

    // Pass vertex color to fragment shader
    color = gl_Color;

    // Apply temporal anti-aliasing jitter
    gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
}