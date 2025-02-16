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

#define PI 3.1415926535897932384626433832795
#define saturate(c) clamp(c, 0.0, 1.0)


bool wave (int p, int color)
{
   return ((color + p + 8) % 12 < 6);
}


vec3 NEStoYIQ(vec3 in_data){

   // Extract the chroma, level, and emphasis from the normalized RGB triplet
   int color =    int(floor((in_data.r * 15.0) + 0.5));
   int level =    int(floor((in_data.g *  3.0) + 0.5));
   int emphasis = int(floor((in_data.b *  7.0) + 0.5));

   // Color 0xE and 0xF are black
   level = (color < 14) ? level : 1;

   float y = 0.0;
   float i = 0.0;
   float q = 0.0;

   // Voltage levels, relative to sync voltage
   float black = 0.518;
   float white = 1.962;
   float attenuation = 0.746;
   const float levels[8] = float[] (   0.350 , 0.518, 0.962, 1.550,
                                       1.094, 1.506, 1.962, 1.962);
   float low  = levels[level + 4 * int(color == 0)];
   float high = levels[level + 4 * int(color < 13)];

   // Calculate the luma and chroma by emulating the relevant circuits:
   for(int p = 0; p < 12; p++) // 12 clock cycles per pixel.
   {
      // NES NTSC modulator (square wave between two voltage levels):
      float spot = wave(p, color) ? high : low;

      // De-emphasis bits attenuate a part of the signal:
      if ((bool(emphasis & 1) && wave(p, 12)) ||
          (bool(emphasis & 2) && wave(p, 4)) ||
          (bool(emphasis & 4) && wave(p, 8)))
      {
          spot *= attenuation;
      }

      // Normalize:
      float v = (spot - black) / (white - black);

      v *= (1.0 / 12.0);

      y += v;
      i += v * cos((PI / 6.0) * p);
      q += v * sin((PI / 6.0) * p);

   }

   return vec3(y, i, q);

}

// Attempt to clamp signal
vec3 ClampYIQ(vec3 yiqin){
   float y = yiqin.x;
   float i = yiqin.y;
   float q = yiqin.z;

   // TV will always clamp Y
   y = saturate(y);


   // Theoretically, the combined amplitude of Y and C is clamped at -1/3 and 4/3.
   float theta = atan(q, i); // q is "blue" and should therefore be the "x" axis
   // might need to consider working around shitty atan implementations? https://stackoverflow.com/questions/26070410/robust-atany-x-on-glsl-for-converting-xy-coordinate-to-angle
   float c = sqrt((i*i)+(q*q));
   float newc = (y + (0.5 * c) > 4.0/3.0) ? 2.0 * ((4.0/3.0) - y) : c;
   newc = (y - (0.5 * c) < -1.0/3.0) ? 2.0 * (y + (1.0/3.0)) : newc;
   float newq = newc * cos(theta);
   float newi = newc * sin(theta);
   i = (newc == c) ? i : newi;
   q = (newc == c) ? q : newq;


   // do we want to reduce c here when i or q is too big, or clamp R-Y B-Y later?

   return vec3(y, i ,q);
}

vec3 YIQtoRGB(vec3 yiqin){

   /*
   mat3 idealizedDecoder = mat3(
      1.0, 1.0, 1.0,
      0.955986344139148, -0.271148256073374, -1.10674021717667,
      0.620824790877091, -0.648927833767348, 1.70423048447489
   );

   return idealizedDecoder * yiqin;
   */

   // Y'IQ to Y'UV (this matrix is its own inverse)
   mat3 YIQtoYUV = mat3(
      1.0, 0.0, 0.0,
      0.0, -1.0 * sin(radians(33)), cos(radians(33)),
      0.0, cos(radians(33)), sin(radians(33))
   );

   vec3 yuv = YIQtoYUV * yiqin;

   vec3 ypbpr = vec3(yuv.x, yuv.y * (1.0/0.492111), yuv.z * (1.0/0.877283));

   ypbpr.y = clamp(ypbpr.y, -0.885522376675926, 0.885522376675926);
   ypbpr.z = clamp(ypbpr.z, -0.701088342072943, 0.701088342072943);

   mat3 YPbPrtoRGB = mat3(
      1.0, 1.0, 1.0,
      0.0, -0.195150923202074, 1.0,
      1.0, -0.509557102135092, 0.0
   );

   return YPbPrtoRGB * ypbpr;

}




void main()
{
   vec3 nesdata = texture(Source, vTexCoord.xy).xyz;

   vec3 yiq = NEStoYIQ(nesdata);

   yiq = ClampYIQ(yiq);

   vec3 rgbout = YIQtoRGB(yiq);

   rgbout = saturate(rgbout);
   //rgbout = max(rgbout, vec3(0.0));

   //bool oob = (rgbout.x > 1.0) || (rgbout.x < 0.0) || (rgbout.y > 1.) || (rgbout.y < 0.0) || (rgbout.z > 1.0) || (rgbout.z < 0.0);
   //rgbout = mix(rgbout, vec3(1.0, 1.0, 1.0), vec3(oob));

   //rgbout = max(vec3(0.0), rgbout - vec3(1.0));

   //vec3 flasher = mix(vec3(0.0), vec3(1.0), params.FrameCount % 2);

   //rgbout = mix(vec3(0.0), vec3(1.0), greaterThan(rgbout, vec3(1.0 + (25.0/255.0))));
   //rgbout = mix(vec3(0.0), vec3(1.0), greaterThan(rgbout, vec3(1.0)));
   //rgbout = mix(rgbout, flasher, greaterThan(rgbout, vec3(1.0)));

   FragColor = vec4(rgbout, 1.0);
}
