/*
   The EOTF function from BT.1886 Appendix 1 for approximating the behavior of CRT televisions.
    The function from Appendix 1 is more faithful than the fairly useless Annex 1 function, which is just 2.4 gamma
    The function has been modified to handle negative inputs in the same fashion as IEC 61966-2-4 (a.k.a. xvYCC)
    (BT.1361 does something similar.)
    Dynamic range is restored in a post-processing step that chops off the black lift and then normalizes to 0-1.

   Copyright (C) 2025 ChthonVII

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

#include "gammaknob.inc"

vec3 linearizeBT1886appx1(vec3 colorin){

    // if input is within 0-1 range, remember that fact
    bvec3 inlow = greaterThanEqual(colorin.rgb, vec3(0.0));
    bvec3 inhigh = lessThanEqual(colorin.rgb, vec3(1.0));

    // add B
    colorin = colorin + vec3(global.crtConstantB);

    // if negative, flip sign
    bvec3 flipsign = lessThan(colorin.rgb, vec3(0.0));
    vec3 flipped = colorin * vec3(-1.0);
    colorin = mix(colorin, flipped, flipsign);

    // EOTF
    bvec3 cutoff = lessThan(colorin.rgb, vec3(0.35 + global.crtConstantB));
    vec3 higher = pow(colorin, vec3(2.6)) * vec3(global.crtConstantK);
    vec3 lower = pow(colorin, vec3(3.0)) * vec3(global.crtConstantK) * vec3(global.crtConstantS);
    vec3 outcolor = mix(higher, lower, cutoff);

    // if input was negative, flip it back
    vec3 flipout = outcolor * vec3(-1.0);
    outcolor = mix(outcolor, flipout, flipsign);

    // renormalize
    outcolor = outcolor - vec3(global.crtBlackLevel);
    outcolor = outcolor / vec3(global.crtWhiteLevel - global.crtBlackLevel);

    // if input was in 0-1 range, clamp to correct floating point errors
    vec3 lowclamp = max(outcolor, vec3(0.0));
    outcolor = mix(outcolor, lowclamp, inlow);
    vec3 highclamp = min(outcolor, 1.0);
    outcolor = mix(outcolor, highclamp, inhigh);

    return outcolor;
}

vec3 crtEOTF(vec3 colorin){
    vec3 colorout = adjustgamma(colorin);
    colorout = linearizeBT1886appx1(colorout);
    return colorout;
}
