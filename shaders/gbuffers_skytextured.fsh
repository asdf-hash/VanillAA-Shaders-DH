#version 120
uniform sampler2D texture;

uniform int isEyeInWater;

varying vec4 color;
varying vec2 coord0;

void main()
{
    vec4 col = color * texture2D(texture,coord0);

    //Output the result.
    /*DRAWBUFFERS:0*/
    gl_FragData[0] = col;
}
