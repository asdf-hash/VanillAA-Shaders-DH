#version 120

// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

uniform float dhNearPlane;
uniform float dhFarPlane;

varying vec4 color;
varying vec2 coord0;
varying float constantPart;
varying float farMinusNear;
varying float farPlusNear;

void main()
{
    gl_Position = ftransform();

    color = gl_Color;
    coord0 = (gl_MultiTexCoord0).xy;

    constantPart = log2(2.0 * dhNearPlane * dhFarPlane);
    farMinusNear = dhFarPlane - dhNearPlane;
    farPlusNear = dhFarPlane + dhNearPlane;
}
