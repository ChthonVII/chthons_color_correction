#version 450

/*
   Aperature grille implementation that preserves average brightness and average color over the local area.

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
    float MODE7_SCALE_FACTOR;
} params;

#pragma parameter MODE7_SCALE_FACTOR "Mode7 Scale Factor in BSNES" 8.0 1.0 8.0 1.0

#define MODE7_SCALE_FACTOR params.MODE7_SCALE_FACTOR

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;



#define saturate(c) clamp(c, 0.0, 1.0)

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



void main()
{
   // Figure out which position this pixel has within its group of 3 or 4 pixels
   // (1.0000001 is to avoid potential rounding issues with floor)
   int cycleindexx = int(floor(mod(vTexCoord.x * 1.0000001 * params.OutputSize.x, MODE7_SCALE_FACTOR)));
   int cycleindexy = int(floor(mod(vTexCoord.y * 1.0000001 * params.OutputSize.y, MODE7_SCALE_FACTOR)));

   bool lowres = true;
   vec3 lastcolor = vec3(0.0);
   //float offsetx = 0.0;
   float offsety = 0.0;

//
   //for (int i=0; i<1/*int(MODE7_SCALE_FACTOR)*/; i++){
//      for (int j=0; j<int(MODE7_SCALE_FACTOR); j++){

         //vec3 newcolor = texture(Source, vTexCoord + vec2((offsetx - cycleindexx) * params.OutputSize.z, (offsety - cycleindexy) * params.OutputSize.w)).xyz;
//         vec3 newcolor = texture(Source, vTexCoord + vec2(0.0, (offsety - cycleindexy) * params.OutputSize.w)).xyz;
//         lowres = (/*(i == 0) &&*/ (j==0)) ? true : (lowres && (newcolor.x == lastcolor.x) && (newcolor.y == lastcolor.y) && (newcolor.z == lastcolor.z));
//         lastcolor = newcolor;
//         offsety += 1.0;
//      }
     // offsetx += 1.0;
  // }

  vec3 colora = texture(Source, vTexCoord + vec2((0.0 - cycleindexx) * params.OutputSize.z, (0.0 - cycleindexy) * params.OutputSize.w)).xyz;
  vec3 colorb = texture(Source, vTexCoord + vec2(((MODE7_SCALE_FACTOR - 1.0) - cycleindexx) * params.OutputSize.z, ((MODE7_SCALE_FACTOR - 1.0) - cycleindexy) * params.OutputSize.w)).xyz;

  lowres = ((colora.x == colorb.x) && (colora.y == colorb.y) && (colora.z == colorb.z));


   // Force lowres on if screensize tells us we're not scaled
   // todo fix for highres case after full scale logic
   lowres = lowres || (params.SourceSize.x < (256.0 * MODE7_SCALE_FACTOR)) || (MODE7_SCALE_FACTOR == 1.0);

   vec3 inputcolor = texture(Source, vTexCoord).xyz;
   //vec3 inputcolor = vec3(1.0/cycleindexx);
   //inputcolor = lowres ? inputcolor : mix(inputcolor, vec3(0.0, 0.0, 1.0), 0.7);

   FragColor = vec4(inputcolor, lowres ? 1.0: 0.0);
}
