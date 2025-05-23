#version 450

/*
   Trilinear LUT shader for LUTs produced by gamutthingy's `--lutmode postgammaunlimited` mode.
   Shader input is console's gamma-space RGB output before being handed off to CRT.
   Shader performs CRT simulation, then uses LUT for gamut conversion & compression.
   For this type of LUT, CRT matrix stage low output MUST be clamped, not lower than the level where the EOTF function produces zero light (gamutthingy: --crtclamplowzerolight true).
   High output need not be clamped. But clamping will dedicate more bandwidth to relevant colors.
   LUT input is linear RGB.
   LUT output is gamma-space sRGB.
   Shader output is linear RGB.
   This type of LUT is superior for all use cases.

   
   Copyright (C) 2023-2025 ChthonVII

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

#include "crtparams.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D SamplerLUT;

#include "saturate.inc"
#include "crtsimulation.inc"
#include "sRGBtoLinear.inc"

void main()
{
	vec2 LUT_Size = textureSize(SamplerLUT, 0);
	vec3 imgColor = texture(Source, vTexCoord.xy).rgb;

	// run the full CRT simulation on the input
	imgColor = crtSimulation(imgColor);

	// compute the LUT index by applying the scaling factor
	vec3 indexColor = saturate(imgColor * vec3(global.crtLUT4scale));

	// find rgb values and their ceilings and floors on a scale on 0-63
	vec3 temp = indexColor.rgb  * (vec3(LUT_Size.y - 1.0));
	vec3 floors = floor(indexColor.rgb  * (vec3(LUT_Size.y - 1.0)));
	vec3 ceils = ceil(indexColor.rgb  * (vec3(LUT_Size.y - 1.0)));
	
	// how close are we to the ceiling on a scale of 0-1?
	// unscale and potentially renormalize
	vec3 unscaledfloors = (floors / vec3(LUT_Size.y - 1.0)) / vec3(global.crtLUT4scale);
	vec3 unscaledceils = (ceils / vec3(LUT_Size.y - 1.0)) / vec3(global.crtLUT4scale);
	vec3 unsuperblacktemp = ((imgColor * vec3(global.crtWhiteLevel)) - vec3(global.crtBlackLevel)) / vec3(global.crtWhiteLevel - global.crtBlackLevel);
	vec3 unsuperblackfloors = ((unscaledfloors * vec3(global.crtWhiteLevel)) - vec3(global.crtBlackLevel)) / vec3(global.crtWhiteLevel - global.crtBlackLevel);
	vec3 unsuperblackceils = ((unscaledceils * vec3(global.crtWhiteLevel)) - vec3(global.crtBlackLevel)) / vec3(global.crtWhiteLevel - global.crtBlackLevel);
	vec3 interpolatetemp = mix(imgColor, unsuperblacktemp, vec3(global.crtLUT4renorm));
	vec3 interpolatefloors = mix(unscaledfloors, unsuperblackfloors, vec3(global.crtLUT4renorm));
	vec3 interpolateceils = mix(unscaledceils, unsuperblackceils, vec3(global.crtLUT4renorm));
	vec3 weights = saturate((interpolatetemp - interpolatefloors) / (interpolateceils - interpolatefloors));
	
	// retroarch can't correctly sample a 1.0 coordinate
	// so we are going to add a just-under-half-step offset to red and green, then increase their divisors by 1
	// This should get us a slightly lower coordinate within the same pixel
	// This is where reshade's LUT is slightly inaccurate because it's taking a linearly filtered sample from the wrong spot.
	floors = floors + vec3(0.4999, 0.4999, 0.0);
	ceils = ceils + vec3(0.4999, 0.4999, 0.0);
	floors = floors / vec3((LUT_Size.y * LUT_Size.y), LUT_Size.y, LUT_Size.y);
	ceils = ceils / vec3((LUT_Size.y * LUT_Size.y), LUT_Size.y, LUT_Size.y);
	
	// this would be correct, if retroarch sampled correctly.
	//floors = saturate(floors / vec3(((LUT_Size.y * LUT_Size.y) - 1.0), LUT_Size.y - 1.0, LUT_Size.y));
	//ceils = saturate(ceils / vec3(((LUT_Size.y * LUT_Size.y) - 1.0), LUT_Size.y - 1.0, LUT_Size.y));
	
	// take 8 samples
	vec3 RfGfBf = sRGBtoLinear((texture(SamplerLUT, vec2(floors.b + floors.r, floors.g))).xyz);
	vec3 RfGfBc = sRGBtoLinear((texture(SamplerLUT, vec2(ceils.b + floors.r, floors.g))).xyz);
	vec3 RfGcBf = sRGBtoLinear((texture(SamplerLUT, vec2(floors.b + floors.r, ceils.g))).xyz);
	vec3 RfGcBc = sRGBtoLinear((texture(SamplerLUT, vec2(ceils.b + floors.r, ceils.g))).xyz);
	vec3 RcGfBf = sRGBtoLinear((texture(SamplerLUT, vec2(floors.b + ceils.r, floors.g))).xyz);
	vec3 RcGfBc = sRGBtoLinear((texture(SamplerLUT, vec2(ceils.b + ceils.r, floors.g))).xyz);
	vec3 RcGcBf = sRGBtoLinear((texture(SamplerLUT, vec2(floors.b + ceils.r, ceils.g))).xyz);
	vec3 RcGcBc = sRGBtoLinear((texture(SamplerLUT, vec2(ceils.b + ceils.r, ceils.g))).xyz);
	
	// merge down to 4 samples along blue axis
	vec3 RfGf = saturate(mix(RfGfBf, RfGfBc, vec3(weights.b)));
	vec3 RfGc = saturate(mix(RfGcBf, RfGcBc, vec3(weights.b)));
	vec3 RcGf = saturate(mix(RcGfBf, RcGfBc, vec3(weights.b)));
	vec3 RcGc = saturate(mix(RcGcBf, RcGcBc, vec3(weights.b)));
	
	// merge down to 2 samples along green axis
	vec3 Rf = saturate(mix(RfGf, RfGc, vec3(weights.g)));
	vec3 Rc = saturate(mix(RcGf, RcGc, vec3(weights.g)));
	
	// merge down to one color along red axis
	vec3 finalcolor = saturate(mix(Rf, Rc, vec3(weights.r)));
	
	// output
	FragColor = vec4(finalcolor.rgb, 1.0);

}
