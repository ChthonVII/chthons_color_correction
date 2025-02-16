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
   // Find top-left corner of output pixel
   vec2 topleft = floor(vTexCoord * vec2(1.0000001) * params.OutputSize.xy);
   // back to 0-1 scale
   topleft /= params.OutputSize.xy;

   // figure out the Y scale factor
   int scaley = int(params.SourceSize.y / params.OutputSize.y);

   vec3 accumulator = vec3(0.0);
   for (int i = 0; i < scaley; i++){
      vec3 newsample = texture(Source, topleft + vec2(0.5 * params.SourceSize.z, (i + 0.5) * params.SourceSize.w)).xyz;
      accumulator += newsample;
   }
   accumulator /= vec3(float(scaley));

   accumulator = saturate(accumulator);

   FragColor = (scaley == 0.0) ? texture(Source, vTexCoord) : vec4(accumulator, 1.0);
   //FragColor = vec4(1.0/scalex, 1.0/scalex, 1.0/scalex, 1.0);
}
