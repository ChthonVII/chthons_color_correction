#version 450

/*
   Halation/Diffusion shader.
   In order to better preserve color and brightness, halation scales with luminosity difference.
   I.e., white bleeds onto black at full strength, but colors of similar brightness barely bleed at all.

   Copyright (C) 2024 ChthonVII

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
    float HALATION_STRENGTH;
    float DIFFUSION_STRENGTH;
} params;

#pragma parameter HALATION_STRENGTH "Halation Strength" 0.07 0.0 1.0 0.01
#pragma parameter DIFFUSION_STRENGTH "Diffusion Strength" 0.02 0.0 1.0 0.01

#define HALATION_STRENGTH params.HALATION_STRENGTH
#define DIFFUSION_STRENGTH params.DIFFUSION_STRENGTH

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;



#include "saturate.inc"



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
layout(location = 1) in vec2 FragCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D NoBlurSource;
layout(set = 0, binding = 4) uniform sampler2D LightBlurSource;

#include "sRGBLuminosity.inc"

void main()
{
    vec3 blurcolor = texture(Source, vTexCoord.xy).xyz;
    vec3 noblurcolor = texture(NoBlurSource, vTexCoord.xy).xyz;
    vec3 lightblurcolor = texture(LightBlurSource, vTexCoord.xy).xyz;

    float lblur = sRGBluminosity(blurcolor);
    float lnoblur = sRGBluminosity(noblurcolor);
    float brightnessdelta = max(0.0, lblur - lnoblur);

    vec3 color = mix(noblurcolor, lightblurcolor, vec3(DIFFUSION_STRENGTH));
    color = mix(color, blurcolor, vec3(brightnessdelta * HALATION_STRENGTH));

    FragColor = vec4(color, 1.0);
}
