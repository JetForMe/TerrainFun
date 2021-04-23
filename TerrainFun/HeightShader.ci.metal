//
//  HeightShader.ci.metal
//  TerrainFun
//
//  Created by Rick Mann on 2021-04-20.
//  Copyright © 2021 Latency: Zero, LLC. All rights reserved.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>

using namespace metal;


float4 HSVtoRGB(float4 HSV)
{
    float4 hue;
    HSV.x = HSV.x / 60.0;
    hue.x = abs(HSV.x - 3.0) - 1.0;
    hue.y = 2.0 - abs(HSV.x - 2.0);
    hue.z = 2.0 - abs(HSV.x - 4.0);
    return ((clamp(hue,0.0,1.0) - 1.0) * HSV.y + 1.0) * HSV.z;
}

float4 Hue(float H)
{
    float R = abs(H * 6 - 3) - 1;
    float G = 2 - abs(H * 6 - 2);
    float B = 2 - abs(H * 6 - 4);
    return saturate(float4(R,G,B, 1));
}

float4 HSVtoRGB2(float4 HSV)
{
    float4 v = ((Hue(HSV.x) - 1) * HSV.y + 1) * HSV.z;
    v.w = HSV.w;
    return v;
}


extern "C"
coreimage::sample_t
heightShader(coreimage::sample_t inS, coreimage::destination inDest)
{
//	if (inS[0] < 0.25)
//	{
//		return coreimage::sample_h(1.0, 0.0, 0.0, 1.0);
//	}
//	else if (inS[0] < 0.5)
//	{
//		return coreimage::sample_h(0.0, 1.0, 0.0, 1.0);
//	}
//	else if (inS[0] < 0.75)
//	{
//		return coreimage::sample_h(0.0, 0.0, 1.0, 1.0);
//	}
//	else if (inS[0] < 1.0)
//	{
//		return coreimage::sample_h(0.0, 1.0, 1.0, 1.0);
//	}
//	return coreimage::sample_h(1.0, 1.0, 1.0, 1.0);
	
	if (inS[0] == inS[1] && inS[1] == inS[2])
	{
		return coreimage::sample_t(0.0, 1.0, 0.0, 1.0);
	}
	else
	{
		return inS;
//		return coreimage::sample_t(1.0, 0.0, 0.0, 1.0);
	}
	
//	return HSVtoRGB2(float4(inS[0], 1, 1, 1));
}

