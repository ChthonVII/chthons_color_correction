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
} params;



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
   if (params.SourceSize.x == params.OutputSize.x){
      FragColor = texture(Source, vTexCoord);
   }
   else {
      // Find top-left corner of output pixel
      vec2 topleftout = floor(vTexCoord * vec2(1.0000001) * params.OutputSize.xy);
      // back to 0-1 scale
      topleftout /= params.OutputSize.xy;

      // Find the bottom right corner of the output pixel
      vec2 bottomrightout = topleftout + params.OutputSize.zw;

      // Find the top-left corner of the input pixel that contains the top-left corner of the output pixel
      vec2 topleftin = floor(topleftout * params.SourceSize.xy);
      // back to 0-1 scale
      topleftin /= params.SourceSize.xy;

      vec3 accumulator = vec3(0.0);
      float weightsum = 0.0;
      float currentx = topleftin.x;

      while (currentx < bottomrightout.x){
         float weight = (currentx >= topleftout.x) ? ((currentx + params.SourceSize.z < bottomrightout.x) ? 1.0 : saturate((bottomrightout.x - currentx) / params.SourceSize.z)) : 1.0 - saturate((topleftout.x - currentx) / params.SourceSize.z);

         weightsum += weight;

         vec3 newsample = texture(Source, vec2(currentx + (0.5 * params.SourceSize.z), topleftin.y + (0.5 * params.SourceSize.w))).xyz;

         accumulator += (newsample * vec3(weight));

         // advance loop
         currentx += params.SourceSize.z;
      }

      accumulator /= vec3(weightsum);

      accumulator = saturate(accumulator);

      FragColor = vec4(accumulator, 1.0);
   }
}
