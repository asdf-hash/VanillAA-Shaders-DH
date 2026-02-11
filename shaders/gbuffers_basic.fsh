#version 120

uniform int fogMode;
const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int isEyeInWater;

varying vec4 color;

void main()
{
    vec4 col = color;

    float fogIntensity;
    if (fogMode == GL_LINEAR) {
        fogIntensity = clamp((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0);
    } else if (fogMode == GL_EXP || isEyeInWater >= 1) {
        fogIntensity = 1.0 - clamp(exp(-gl_FogFragCoord * gl_Fog.density), 0.0, 1.0);
    }

    col.rgb = mix(col.rgb, gl_Fog.color.rgb, fogIntensity);

    gl_FragData[0] = col;
}