/* 
BSL Shaders v7.2.01 by Capt Tatsu/Recomposed by 1Xayd1
https://bitslablab.com 
*/ 
// Neighborhood offsets for sampling
vec2 neighbourhoodOffsets[8] = vec2[8](
    vec2(-1.0, -1.0),
    vec2( 0.0, -1.0),
    vec2( 1.0, -1.0),
    vec2(-1.0,  0.0),
    vec2( 1.0,  0.0),
    vec2(-1.0,  1.0),
    vec2( 0.0,  1.0),
    vec2( 1.0,  1.0)
);
// Reproject previous frame's position
vec2 Reprojection(vec3 pos) {
    pos = pos * 2.0 - 1.0; // Transform to NDC
    vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0);
    viewPosPrev /= viewPosPrev.w; // Homogeneous divide
    viewPosPrev = gbufferModelViewInverse * viewPosPrev;
    // Calculate camera offset only if z is significant
    vec3 cameraOffset = (pos.z > 0.56) ? (cameraPosition - previousCameraPosition) : vec3(0.0);

    // Transform previous position
    vec4 previousPosition = gbufferPreviousProjection * gbufferPreviousModelView * (viewPosPrev + vec4(cameraOffset, 0.0));

    return (previousPosition.xy / previousPosition.w) * 0.5 + 0.5; // Normalize to [0, 1]
}
// Clamp the temporary color based on neighborhood
vec3 NeighbourhoodClamping(vec3 color, vec3 tempColor, vec2 viewInv) {
    vec3 minclr = color;
    vec3 maxclr = color;
    for (int i = 0; i < 8; i++) {
        vec3 clr = texture2DLod(colortex1, texCoord + neighbourhoodOffsets[i] * viewInv, 0.0).rgb;
        minclr = min(minclr, clr);
        maxclr = max(maxclr, clr);
    }
    return clamp(tempColor, minclr, maxclr);
}
// Perform Temporal Anti-Aliasing
vec4 TemporalAA(inout vec3 color, float tempData) {
    vec3 coord = vec3(texCoord, texture2DLod(depthtex1, texCoord, 0.0).r);
    vec2 prvCoord = Reprojection(coord);

    vec3 tempColor = texture2DLod(colortex2, prvCoord, 0.0).rgb;
    if (tempColor == vec3(0.0)) return vec4(color, tempData); // Early exit if no valid tempColor

    vec2 viewInv = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    tempColor = NeighbourhoodClamping(color, tempColor, viewInv);

    // Calculate velocity and blend factor
    vec2 velocity = (texCoord - prvCoord) * vec2(viewWidth, viewHeight);
    float blendFactor = (prvCoord.x > 0.0 && prvCoord.x < 1.0 && prvCoord.y > 0.0 && prvCoord.y < 1.0) ? 
                        exp(-length(velocity)) * 0.6 + 0.3 : 0.0;
    color = mix(color, tempColor, blendFactor);
    return vec4(color, tempData); // Return final color with tempData
}