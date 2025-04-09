#version 450

/*
   Scanline implementation that preserves average brightness and average color over the local area.
   ***Expects input Y has been upscaled to 10x original Y.***

   General concept of a brightness-preserving scanline implementation shamelessly stolen from crt-beans.

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
    float SCANLINE_THETA;
    float SCANLINE_THETA_NORM;
    float SCANLINE_STRENGTH;
    float SCANLINES_CUTOFF;
    float SCANLINE_WHITE_LVL;
} params;

#pragma parameter SCANLINE_BREAK "*** SCANLINE SETTINGS ***" 0.0 0.0 0.0 0.0
#pragma parameter SCANLINE_THETA "Scanline Theta" 2.00 0.50 3.50 0.05
// 0.7 ~= "standard normal"
#pragma parameter SCANLINE_THETA_NORM "Scanline Theta Norm" 0.70 0.10 3.50 0.05
#pragma parameter SCANLINE_STRENGTH "Scanline Effect Strength" 1.0 0.0 1.0 0.01
#pragma parameter SCANLINES_CUTOFF "Disable Scanlines for Y Resolution Above" 300.0 0.0 1000.0 1.0
#pragma parameter SCANLINE_WHITE_LVL "Scanline White Level" 1.0 0.0 1.0 0.001

#define SCANLINE_THETA params.SCANLINE_THETA
#define SCANLINE_THETA_NORM params.SCANLINE_THETA_NORM
#define SCANLINE_STRENGTH params.SCANLINE_STRENGTH
#define SCANLINES_CUTOFF params.SCANLINES_CUTOFF
#define SCANLINE_WHITE_LVL params.SCANLINE_WHITE_LVL

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;



#include "saturate.inc"
#include "pi.inc"


#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float w0;
layout(location = 2) out float w1;
layout(location = 3) out float w2;
layout(location = 4) out float w3;
layout(location = 5) out float w4;


// Fast approximate erf() function
// Shamelessly ripped off from this reddit post: https://www.reddit.com/r/vulkan/comments/c4r7qx/comment/esnvdnf/
float fast_erf(float x){

   // To handle the negative case, takes abs(x) then flip sign on the output.
   // *Not* doing that here b/c we know our input will always be positive.

   float y = x * (x * (x * 0.0038004543 + 0.020338153) + 0.03533611) + 1.0000062;

   // y = y^32
   y = y*y;
   y = y*y;
   y = y*y;
   y = y*y;
   y = y*y;

   y = 1.0 - (1.0/y);

   return y;
}

// Gaussian function without the 1/(theta*sqrt(2pi)) "squashing" factor
float linestrength(float pos){
   return exp(-1.0 * ((pos * pos) / (2.0 * SCANLINE_THETA * SCANLINE_THETA)));
}


void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;

   // The weight calculations go in the vertex shader since they don't depend on TexCoord,
   // and they're substantial enough that the cost of passing their output to the fragment shader is probably less
   // than the cost of computing them over and over in the fragment shader.

   // We are going to calculate the avergage value of the Gaussian function across each pixel
   // by subtracting the erf() at the near end from the erf() at the far end, then dividing by 2.

   // "erf()" is defined only for theta = 1/sqrt2
   // But we can define erf-alike(x, theta) for arbitrary theta as erf(k) where k = (x/theta)/sqrt2
   // See https://stackoverflow.com/questions/66632786/estimate-how-many-values-fall-below-a-specific-deviation-using-the-empirical-rul/66633497#66633497
   // So express pixel distances in terms of theta/sqrt2
   float d1 = (1.0 / SCANLINE_THETA) / sqrt(2.0);
   float d2 = (2.0 / SCANLINE_THETA) / sqrt(2.0);
   float d3 = (3.0 / SCANLINE_THETA) / sqrt(2.0);
   float d4 = (4.0 / SCANLINE_THETA) / sqrt(2.0);
   float d5 = (5.0 / SCANLINE_THETA) / sqrt(2.0);
   float d6 = (6.0 / SCANLINE_THETA) / sqrt(2.0);
   float d7 = (7.0 / SCANLINE_THETA) / sqrt(2.0);
   float d8 = (8.0 / SCANLINE_THETA) / sqrt(2.0);
   float d9 = (9.0 / SCANLINE_THETA) / sqrt(2.0);
   float d10 = (10.0 / SCANLINE_THETA) / sqrt(2.0);

   // Now run them through erf()
   float erf0 = 0.0;
   float erf1 = fast_erf(d1);
   float erf2 = fast_erf(d2);
   float erf3 = fast_erf(d3);
   float erf4 = fast_erf(d4);
   float erf5 = fast_erf(d5);
   float erf6 = fast_erf(d6);
   float erf7 = fast_erf(d7);
   float erf8 = fast_erf(d8);
   float erf9 = fast_erf(d9);
   float erf10 = fast_erf(d10);

   // Get the average across each pixel
   float w0to1 = (erf1 - erf0) * 0.5;
   float w1to2 = (erf2 - erf1) * 0.5;
   float w2to3 = (erf3 - erf2) * 0.5;
   float w3to4 = (erf4 - erf3) * 0.5;
   float w4to5 = (erf5 - erf4) * 0.5;
   float w5to6 = (erf6 - erf5) * 0.5;
   float w6to7 = (erf7 - erf6) * 0.5;
   float w7to8 = (erf8 - erf7) * 0.5;
   float w8to9 = (erf9 - erf8) * 0.5;
   float w9to10 = (erf10 - erf9) * 0.5;

   // Gaussian function gets squatter the bigger theta is.
   // We need to normalize this so that the function for a user-selected theta covers the whole 0-1 range, and higher thetas are squatter.
   // We also need to normalize again so that adding the tail from the adjacent scanline doesn't put us over 1.0 at the middle of the scanline.
   float normfactor_unsquash = SCANLINE_THETA * sqrt(2.0 * PI);
   float normfactor_theta = SCANLINE_THETA_NORM / SCANLINE_THETA;
   float normfactor_neighbor = 1.0 / (1.0 + linestrength(10.0));
   float normfactor_all = normfactor_unsquash * normfactor_theta * normfactor_neighbor;

   // Add the tail from the adjacent scanline and normalize.
   w0 = normfactor_all * (w0to1 + w9to10);
   w1 = normfactor_all * (w1to2 + w8to9);
   w2 = normfactor_all * (w2to3 + w7to8);
   w3 = normfactor_all * (w3to4 + w6to7);
   w4 = normfactor_all * (w4to5 + w5to6);

   // Shift the whole Gaussian down by the average of the weights so that they sum to zero.
   // To a first approximation, this preserves average brightness and average color over the local area.
   // We will improve upon this later.
   float w_ave = (w0 + w1 + w2 + w3 + w4) * 0.2;
   w0 -= w_ave;
   w1 -= w_ave;
   w2 -= w_ave;
   w3 -= w_ave;
   w4 -= w_ave;

}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float w0;
layout(location = 2) in float w1;
layout(location = 3) in float w2;
layout(location = 4) in float w3;
layout(location = 5) in float w4;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

vec2 gainlosshelper(float color, float weight){
   float gain = (1.0 - color) * weight;
   float loss = -1.0 * color * weight;
   vec2 outval = weight >= 0.0 ? vec2(gain, 0.0) : vec2(0.0, loss);
   return outval;
}

float reallocatecolors(float colors[10], int cycleindex){

   // (Weight calculation is done in the vertex shader.)

   // Make a mask from the weights
   // it hurts that we don't have a vec10 type...
   float mask[10] = float[10](w4, w3, w2, w1, w0, w0, w1, w2, w3, w4);

   // Since we shifted the Guassian to make the weights sum to zero, some pixels will "donors" and others "recipients."
   // Figure out how much color each donor pixel has to lose, and how much headroom each recipient pixel has to gain.
   // We will use these to only transfer as much color as we can without incurring clipping,
   // which would mess up preservation of average brightness and average color over the local area.
   float gains[10];
   float losses[10];
   vec2 tempv2;
   for (int i = 0; i < 10; i++) {
      tempv2 = gainlosshelper(colors[i], mask[i]);
      gains[i] = tempv2.x;
      losses[i] = tempv2.y;
   }
   float totalgain = gains[0] + gains[1] + gains[2] + gains[3] + gains[4] + gains[5] + gains[6] + gains[7] + gains[8] + gains[9];
   float totalloss = losses[0] + losses[1] + losses[2] + losses[3] + losses[4] + losses[5] + losses[6] + losses[7] + losses[8] + losses[9];

   // Transfer the smaller of the total color in the donor pixels or the total headroom in the recipient pixels (scaled by user parameter).
   float totaltransfer = min(totalgain, totalloss) * SCANLINE_STRENGTH;
   // We need this to avoid dividing by zero.
   bool notransfer = totaltransfer <= 0.0;

   // Add or subtract this pixel's share of the total amount transferred.
   float newcolor = notransfer ? colors[cycleindex] : colors[cycleindex] + (totaltransfer * (gains[cycleindex] / totalgain)) - (totaltransfer * (losses[cycleindex] / totalloss));

   return newcolor;

}


void main()
{
    vec3 whitelvl = vec3(SCANLINE_WHITE_LVL);
    vec3 finalcolor;
    if (params.OriginalSize.y > SCANLINES_CUTOFF){
      finalcolor = whitelvl * texture(Source, vTexCoord).xyz;
    }
    else {
      // Figure out which position this pixel has within its group of 10 pixels
      // (1.0000001 is to avoid potential rounding issues with floor)
      int cycleindex = int(floor(mod(vTexCoord.y * 1.0000001 * params.OutputSize.y, 10.0)));

      // Sample
      // At 1x scale, we shouldn't need any "snap to center" business.
      vec3 pixm4 = whitelvl * texture(Source, vTexCoord + vec2(0.0, (0.0 - cycleindex) * params.OutputSize.w)).xyz;
      vec3 pixm3 = whitelvl * texture(Source, vTexCoord + vec2(0.0, (1.0 - cycleindex) * params.OutputSize.w)).xyz;
      vec3 pixm2 = whitelvl * texture(Source, vTexCoord + vec2(0.0, (2.0 - cycleindex) * params.OutputSize.w)).xyz;
      vec3 pixm1 = whitelvl * texture(Source, vTexCoord + vec2(0.0, (3.0 - cycleindex) * params.OutputSize.w)).xyz;
      vec3 pixm0 = whitelvl * texture(Source, vTexCoord + vec2(0.0, (4.0 - cycleindex) * params.OutputSize.w)).xyz;
      vec3 pixp0 = whitelvl * texture(Source, vTexCoord + vec2(0.0, (5.0 - cycleindex) * params.OutputSize.w)).xyz;
      vec3 pixp1 = whitelvl * texture(Source, vTexCoord + vec2(0.0, (6.0 - cycleindex) * params.OutputSize.w)).xyz;
      vec3 pixp2 = whitelvl * texture(Source, vTexCoord + vec2(0.0, (7.0 - cycleindex) * params.OutputSize.w)).xyz;
      vec3 pixp3 = whitelvl * texture(Source, vTexCoord + vec2(0.0, (8.0 - cycleindex) * params.OutputSize.w)).xyz;
      vec3 pixp4 = whitelvl * texture(Source, vTexCoord + vec2(0.0, (9.0 - cycleindex) * params.OutputSize.w)).xyz;

      // Collect all the red/green/blue values together into arrays of 10.
      // b/c there is no vec10 :(
      float reds[10] = float[10](pixm4.r, pixm3.r, pixm2.r, pixm1.r, pixm0.r, pixp0.r, pixp1.r, pixp2.r, pixp3.r, pixp4.r);
      float greens[10] = float[10](pixm4.g, pixm3.g, pixm2.g, pixm1.g, pixm0.g, pixp0.g, pixp1.g, pixp2.g, pixp3.g, pixp4.g);
      float blues[10] = float[10](pixm4.b, pixm3.b, pixm2.b, pixm1.b, pixm0.b, pixp0.b, pixp1.b, pixp2.b, pixp3.b, pixp4.b);

      // Process red, then green, then blue
      float newred = reallocatecolors(reds, cycleindex);
      float newgreen = reallocatecolors(greens, cycleindex);
      float newblue = reallocatecolors(blues, cycleindex);

      finalcolor = saturate(vec3(newred, newgreen, newblue));
    }

    FragColor = vec4(finalcolor, 1.0);
}
