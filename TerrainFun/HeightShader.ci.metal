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

extern "C"
coreimage::sample_h
heightShader(coreimage::sample_h inS, coreimage::destination inDest)
{
	coreimage::sample_h r = inS + 0.1;
	return r;
}
