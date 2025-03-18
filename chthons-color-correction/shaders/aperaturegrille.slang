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
    float APERATURE_GRILLE_WIDTH;
    float APERATURE_GRILLE_STRENGTH;
    float MONITOR_SUBPIXELS;
} params;

#pragma parameter APERATURE_GRILLE_BREAK "*** APERATURE GRILLE SETTINGS ***" 0.0 0.0 0.0 0.0
#pragma parameter APERATURE_GRILLE_WIDTH "Aperature Grille Width" 4.0 3.0 4.0 1.0
#pragma parameter APERATURE_GRILLE_STRENGTH "Aperature Grille Effect Strength" 1.0 0.0 1.0 0.01
#pragma parameter MONITOR_SUBPIXELS "Your Monitor's Subpixel Layout [0=RGB, 1=BGR]" 0.0 0.0 1.0 1.0

#define APERATURE_GRILLE_WIDTH params.APERATURE_GRILLE_WIDTH
#define APERATURE_GRILLE_STRENGTH params.APERATURE_GRILLE_STRENGTH
#define MONITOR_SUBPIXELS params.MONITOR_SUBPIXELS

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
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;


float reallocatecolors(vec4 colors, vec4 control, int cycleindex){

   // Since we we want to preserve average brightness and average color over the local area,
   // some pixels will "donors" and others "recipients."
   // Figure out how much color each donor pixel has to lose, and how much headroom each recipient pixel has to gain.
   // We will use these to only transfer as much color as we can without incurring clipping,
   // which would mess up preservation of average brightness and average color.

   vec4 gains = (vec4(1.0) - colors) * control;
   vec4 losses = colors * (vec4(1.0) - control);
   float totalgain = gains.x + gains.y + gains.z + gains.w;
   float totalloss = losses.x + losses.y + losses.z + losses.w;
   vec4 gainshare = gains / vec4(totalgain);
   vec4 lossshare = losses / vec4(totalloss);
   float totaltransfer = min(totalgain, totalloss) * APERATURE_GRILLE_STRENGTH;
   // We need this to avoid dividing by zero.
   bool notransfer = totaltransfer <= 0.0;
   float newcolor = notransfer ? colors[cycleindex] : colors[cycleindex] + (totaltransfer * (gains[cycleindex] / totalgain)) - (totaltransfer * (losses[cycleindex] / totalloss));
   return newcolor;
}


void main()
{
   // Figure out which position this pixel has within its group of 3 or 4 pixels
   // (1.0000001 is to avoid potential rounding issues with floor)
   int cycleindex = int(floor(mod(vTexCoord.x * 1.0000001 * params.OutputSize.x, APERATURE_GRILLE_WIDTH)));

   // Sample
   // at 1x scale, we shouldn't need any "snap to center" business.
   // Dummy out the 4th pixel if width is only 3.
   vec3 farleft = texture(Source, vTexCoord + vec2((0.0 - cycleindex) * params.OutputSize.z, 0.0)).xyz;
   vec3 midleft = texture(Source, vTexCoord + vec2((1.0 - cycleindex) * params.OutputSize.z, 0.0)).xyz;
   vec3 midright = texture(Source, vTexCoord + vec2((2.0 - cycleindex) * params.OutputSize.z, 0.0)).xyz;
   vec3 farright = (APERATURE_GRILLE_WIDTH == 4.0) ? texture(Source, vTexCoord + vec2((3.0 - cycleindex) * params.OutputSize.z, 0.0)).xyz : vec3(0.0);

   vec4 reds = vec4(farleft.r, midleft.r, midright.r, farright.r);
   vec4 greens = vec4(farleft.g, midleft.g, midright.g, farright.g);
   vec4 blues = vec4(farleft.b, midleft.b, midright.b, farright.b);


   // Mask is backwards from monitor's subpixels.
   // E.g., if monitor is RGB, first pixel will be recipient for blue.
   // I copied this from Hyllian's CRT, and I'm unsure it's correct.
   // At width 3, doing it this way creates even space between lit R, G, and B subpixels, with a larger gap between groups of 3.
   // The other way around has red and blue adjacent, separated from green by a big gap.
   // So that sounds right.
   // But the width 4 case is less clear.

   // If width is 3, then just blank the last element in the mask so it always drops out.

   vec4 redcontrol = (APERATURE_GRILLE_WIDTH == 4.0) ? ((MONITOR_SUBPIXELS == 1.0) ? vec4(0.0, 0.0, 1.0, 1.0) : vec4(1.0, 1.0, 0.0, 0.0)) : ((MONITOR_SUBPIXELS == 1.0) ? vec4(0.0, 0.0, 1.0, 0.0) : vec4(1.0, 0.0, 0.0, 0.0)) ;
   vec4 greencontrol = (APERATURE_GRILLE_WIDTH == 4.0) ? vec4(0.0, 1.0, 1.0, 0.0) : vec4(0.0, 1.0, 0.0, 0.0);
   vec4 bluecontrol = (APERATURE_GRILLE_WIDTH == 4.0) ? ((MONITOR_SUBPIXELS == 1.0) ? vec4(1.0, 1.0, 0.0, 0.0) : vec4(0.0, 0.0, 1.0, 1.0)) : ((MONITOR_SUBPIXELS == 1.0) ? vec4(1.0, 0.0, 0.0, 0.0) : vec4(0.0, 0.0, 1.0, 0.0));

   float newred = reallocatecolors(reds, redcontrol, cycleindex);
   float newgreen = reallocatecolors(greens, greencontrol, cycleindex);
   float newblue = reallocatecolors(blues, bluecontrol, cycleindex);

   vec3 finalcolor = saturate(vec3(newred, newgreen, newblue));

   FragColor = vec4(finalcolor, 1.0);
}
