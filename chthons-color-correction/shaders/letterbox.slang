#version 450

/*
   Fullscreen letterbox 4::3 content on 16::9 screen

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
   float newX = (vTexCoord.x - 0.125) / 0.75;
   bool inbounds = ((newX >= 0.0) && (newX < 1.0));
   newX = clamp(newX, 0.0, 1.0);
   vec2 newCoord = vec2(newX, vTexCoord.y);
   vec3 letterboxcolor = vec3(0.0);
   vec3 gamecolor = texture(Source, newCoord).rgb;
   vec3 outcolor = mix(letterboxcolor, gamecolor, bvec3(inbounds));
   FragColor = vec4(outcolor, 1.0);
}
