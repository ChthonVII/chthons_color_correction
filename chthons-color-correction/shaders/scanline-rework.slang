#version 450

/*
   Scanline implementation that preserves average brightness and average color over the local area.
   Expects input Y has been upscaled to 10x original Y.

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
} params;

#pragma parameter SCANLINE_BREAK "*** SCANLINE SETTINGS ***" 0.0 0.0 0.0 0.0
#pragma parameter SCANLINE_THETA "Scanline Theta" 2.00 0.50 3.50 0.05
#pragma parameter SCANLINE_THETA_NORM "Scanline Theta Norm" 1.00 0.50 3.50 0.05
#pragma parameter SCANLINE_STRENGTH "SCANLINE_STRENGTH" 1.0 0.0 1.0 0.01

#define SCANLINE_THETA params.SCANLINE_THETA
#define SCANLINE_THETA_NORM params.SCANLINE_THETA_NORM
#define SCANLINE_STRENGTH params.SCANLINE_STRENGTH

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;



#define saturate(c) clamp(c, 0.0, 1.0)
#define PI 3.1415926535897932384626433832795


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

float quasirandomdither(float x, float y){
    x = x + 1.0; // avoid x=0
    y = y + 1.0; // avoid y=0
    float dither = fract((x * 0.7548776662) + (y * 0.56984029));
    // triangular wave function to smooth out discontinuty at interger boundary
    if (dither < 0.5){
        dither = 2.0 * dither;
    }
    else if (dither > 0.5) {
        dither = 2.0 - (2.0 * dither);
    }
    // if we ever get exactly 0.5, don't touch it; otherwise we might end up adding 1.0 to a 0.0.

    return dither;
}


float linestrength(float pos){
   return exp(-1.0 * ((pos * pos) / (2.0 * SCANLINE_THETA * SCANLINE_THETA)));
}

vec2 gainlosshelper(float color, float weight){
   float gain = (1.0 - color) * weight;
   float loss = -1.0 * color * weight;
   vec2 outval = weight >= 0.0 ? vec2(gain, 0.0) : vec2(0.0, loss);
   return outval;
}


float reallocatecolors(float colors[10], int cycleindex, bvec2 ditherflip){

   // Gaussian function gets squatter the bigger theta is.
   // Normalize so that when theta = SCANLINE_THETA_NORM, the Guassian's range goes from 0 to 1.
   // (Also consider any long tail from the neighboring scanline that reaches here.)
   float cterm = (SCANLINE_THETA_NORM / SCANLINE_THETA) * (1.0 / (1.0 + linestrength(10.0)));

   // Because Guassian function is non-linear across a given pixel, it's hard to find the average value to use for the whole pixel.
   // Rather than use calculus, we'll dither the position where we compute the Guassian.
   // This should give the correct average over the whole scanline.
   // (If we wanted scanlines with noisy pulsing, we could add a time dimension to the dithering.)
   // We're mirroring the dither values from the top half of the scanline to the bottom, rather than compute both halves. This should be good enough.
   float ditherx = floor((ditherflip.x ? 1.0 - vTexCoord.x : vTexCoord.x) * params.OutputSize.x);
   float dithery0 = floor((ditherflip.y ? 1.0 - (vTexCoord.y + ((4.0 - cycleindex)*params.OutputSize.w)) : vTexCoord.y + ((4.0 - cycleindex)*params.OutputSize.w)) * params.OutputSize.y);
   float dithery1 = floor((ditherflip.y ? 1.0 - (vTexCoord.y + ((3.0 - cycleindex)*params.OutputSize.w)) : vTexCoord.y + ((3.0 - cycleindex)*params.OutputSize.w)) * params.OutputSize.y);
   float dithery2 = floor((ditherflip.y ? 1.0 - (vTexCoord.y + ((2.0 - cycleindex)*params.OutputSize.w)) : vTexCoord.y + ((2.0 - cycleindex)*params.OutputSize.w)) * params.OutputSize.y);
   float dithery3 = floor((ditherflip.y ? 1.0 - (vTexCoord.y + ((1.0 - cycleindex)*params.OutputSize.w)) : vTexCoord.y + ((1.0 - cycleindex)*params.OutputSize.w)) * params.OutputSize.y);
   float dithery4 = floor((ditherflip.y ? 1.0 - (vTexCoord.y + ((0.0 - cycleindex)*params.OutputSize.w)) : vTexCoord.y + ((0.0 - cycleindex)*params.OutputSize.w)) * params.OutputSize.y);

   float dither0 = quasirandomdither(ditherx, dithery0);
   float dither1 = quasirandomdither(ditherx, dithery1);
   float dither2 = quasirandomdither(ditherx, dithery2);
   float dither3 = quasirandomdither(ditherx, dithery3);
   float dither4 = quasirandomdither(ditherx, dithery4);

   // Compute the Gaussian at each pixel (plus any long tail from the neighboring scanline).
   float w0 = cterm * (linestrength(0.0 + dither0) + linestrength(10.0 - dither0));
   float w1 = cterm * (linestrength(1.0 + dither1) + linestrength(9.0 - dither1));
   float w2 = cterm * (linestrength(2.0 + dither2) + linestrength(8.0 - dither2));
   float w3 = cterm * (linestrength(3.0 + dither3) + linestrength(7.0 - dither3));
   float w4 = cterm * (linestrength(4.0 + dither4) + linestrength(6.0 - dither4));

   // Shift down by the average of the weights so that the change in average brightness is zero.
   // Some pixels will gain and some pixels will lose, but the sum and average will be constant.
   float w_ave = (w0 + w1 + w2 + w3 + w4) * 0.2;
   w0 -= w_ave;
   w1 -= w_ave;
   w2 -= w_ave;
   w3 -= w_ave;
   w4 -= w_ave;

   // Make a mask from the weights
   // it hurts that we don't have a vec10 type...
   float mask[10] = float[10](w4, w3, w2, w1, w0, w0, w1, w2, w3, w4);

   // Figure out how much each losing pixel has to lose, and how much headroom each gaining pixel has to gain
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

   // Transfer the smaller of the total color in the losing pixel or the total headroom in the gaining pixels.
   float totaltransfer = min(totalgain, totalloss) * SCANLINE_STRENGTH;
   // We need this to avoid dividing by zero.
   bool notransfer = totaltransfer <= 0.0;

   // Add or subtract this pixel's share of the total amount transferred.
   float newcolor = notransfer ? colors[cycleindex] : colors[cycleindex] + (totaltransfer * (gains[cycleindex] / totalgain)) - (totaltransfer * (losses[cycleindex] / totalloss));

   return newcolor;

}


void main()
{
    // Figure out which position this pixel has within its group of 10 pixels
    int cycleindex = int(floor(mod(vTexCoord.y * params.OutputSize.y, 10.0)));

    // Sample
    // At 1x scale, we shouldn't need any "snap to center" business.
    vec3 pixm4 = texture(Source, vTexCoord + vec2(0.0, (0.0 - cycleindex) * params.OutputSize.w)).xyz;
    vec3 pixm3 = texture(Source, vTexCoord + vec2(0.0, (1.0 - cycleindex) * params.OutputSize.w)).xyz;
    vec3 pixm2 = texture(Source, vTexCoord + vec2(0.0, (2.0 - cycleindex) * params.OutputSize.w)).xyz;
    vec3 pixm1 = texture(Source, vTexCoord + vec2(0.0, (3.0 - cycleindex) * params.OutputSize.w)).xyz;
    vec3 pixm0 = texture(Source, vTexCoord + vec2(0.0, (4.0 - cycleindex) * params.OutputSize.w)).xyz;
    vec3 pixp0 = texture(Source, vTexCoord + vec2(0.0, (5.0 - cycleindex) * params.OutputSize.w)).xyz;
    vec3 pixp1 = texture(Source, vTexCoord + vec2(0.0, (6.0 - cycleindex) * params.OutputSize.w)).xyz;
    vec3 pixp2 = texture(Source, vTexCoord + vec2(0.0, (7.0 - cycleindex) * params.OutputSize.w)).xyz;
    vec3 pixp3 = texture(Source, vTexCoord + vec2(0.0, (8.0 - cycleindex) * params.OutputSize.w)).xyz;
    vec3 pixp4 = texture(Source, vTexCoord + vec2(0.0, (9.0 - cycleindex) * params.OutputSize.w)).xyz;

    // Collect all the red/green/blue values together into arrays of 10.
    // there is no vec10 :(
    float reds[10] = float[10](pixm4.r, pixm3.r, pixm2.r, pixm1.r, pixm0.r, pixp0.r, pixp1.r, pixp2.r, pixp3.r, pixp4.r);
    float greens[10] = float[10](pixm4.g, pixm3.g, pixm2.g, pixm1.g, pixm0.g, pixp0.g, pixp1.g, pixp2.g, pixp3.g, pixp4.g);
    float blues[10] = float[10](pixm4.b, pixm3.b, pixm2.b, pixm1.b, pixm0.b, pixp0.b, pixp1.b, pixp2.b, pixp3.b, pixp4.b);

    // Process red, then green, then blue
    // Invert the dithering coords to decouple the red/green/blue channels.
    float newred = reallocatecolors(reds, cycleindex, bvec2(true, false));
    float newgreen = reallocatecolors(greens, cycleindex, bvec2(false, false));
    float newblue = reallocatecolors(blues, cycleindex, bvec2(false, true));

    vec3 finalcolor = saturate(vec3(newred, newgreen, newblue));

    FragColor = vec4(finalcolor, 1.0);
}
