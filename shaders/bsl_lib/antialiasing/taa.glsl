/* BSL Shaders v7.2.01 by Capt Tatsu/Recomposed by 1Xayd1
Optimized by Gemini
https://bitslablab.com 
*/ 
vec2 Reprojection(vec3 pos) {
    vec4 viewPos = gbufferProjectionInverse * vec4(pos * 2.0 - 1.0, 1.0);
    viewPos /= viewPos.w;
    viewPos = gbufferModelViewInverse * viewPos;

    if (pos.z > 0.56) {
        viewPos.xyz += cameraPosition - previousCameraPosition;
    }

    vec4 prevPos = gbufferPreviousProjection * gbufferPreviousModelView * viewPos;
    return (prevPos.xy / prevPos.w) * 0.5 + 0.5;
}

vec4 TemporalAA(inout vec3 color, float tempData) {
    float depth = texture2DLod(depthtex1, texCoord, 0.0).r;
    vec2 prvCoord = Reprojection(vec3(texCoord, depth));

    if (prvCoord.x < 0.0 || prvCoord.x > 1.0 || prvCoord.y < 0.0 || prvCoord.y > 1.0) {
        return vec4(color, tempData);
    }

    vec3 tempColor = texture2DLod(colortex2, prvCoord, 0.0).rgb;
    vec2 viewInv = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    vec3 minColor = color;
    vec3 maxColor = color;

    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            if(x == 0 && y == 0) continue;
            
            vec2 sampleOffset = vec2(float(x), float(y)) * viewInv;
            vec3 neighbor = texture2DLod(colortex1, texCoord + sampleOffset, 0.0).rgb;
            
            minColor = min(minColor, neighbor);
            maxColor = max(maxColor, neighbor);
        }
    }
    
    tempColor = clamp(tempColor, minColor, maxColor);

    vec2 velocity = (texCoord - prvCoord) * vec2(viewWidth, viewHeight);
    float blendFactor = mix(0.3, 0.9, 1.0 / (1.0 + length(velocity)));
    
    color = mix(color, tempColor, blendFactor);
    return vec4(color, tempData);
}