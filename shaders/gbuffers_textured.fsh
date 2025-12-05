#version 120

// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. 
// If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/

uniform sampler2D texture;
uniform sampler2D lightmap;

uniform vec4 entityColor;

uniform int fogMode;
const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int isEyeInWater;

varying vec4 fragColor;
varying vec2 texCoord0;
varying vec2 texCoord1;

void main() {
    vec4 color = fragColor * texture2D(lightmap, texCoord1) * texture2D(texture, texCoord0);

    color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);

    float fogFactor;
    if (fogMode == GL_LINEAR) {
        fogFactor = clamp((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0);
    } else if (fogMode == GL_EXP || isEyeInWater >= 1) {
        fogFactor = 1.0 - clamp(exp(-gl_FogFragCoord * gl_Fog.density), 0.0, 1.0);
    }
    color.rgb = mix(color.rgb, gl_Fog.color.rgb, fogFactor);

    gl_FragData[0] = color;
}