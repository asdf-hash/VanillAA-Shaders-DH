#version 120
#define DISTANT_HORIZONS
#ifdef GLSLANG
#extension GL_GOOGLE_include_directive : enable
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform mat4 dhProjection;

varying vec4 fragColor;
varying vec2 texCoord1;
flat varying float materialId;
varying vec3 viewPos;
varying vec3 playerPos;

uniform int frameCounter;
uniform float viewWidth, viewHeight;

#include "bsl_lib/util/jitter.glsl"

void main()
{
    materialId = dhMaterialId;
    
    vec4 viewSpace = gl_ModelViewMatrix * gl_Vertex;
    viewPos = viewSpace.xyz;
    
    playerPos = (gbufferModelViewInverse * viewSpace).xyz;
    
    gl_Position = dhProjection * gbufferModelView * gbufferModelViewInverse * viewSpace;
    
    vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
    vec3 worldNormal = (gbufferModelViewInverse * vec4(normal, 0.0)).xyz;
    
    float lightIntensity = min(
        worldNormal.x * worldNormal.x * 0.6 + 
        worldNormal.y * worldNormal.y * 0.25 * (3.0 + worldNormal.y) + 
        worldNormal.z * worldNormal.z * 0.8, 
        1.0
    );
    
    fragColor = vec4(gl_Color.rgb * lightIntensity, gl_Color.a);
    
    texCoord1 = (gl_TextureMatrix[1] * gl_MultiTexCoord2).xy;
    
    gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
}