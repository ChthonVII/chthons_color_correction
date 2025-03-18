/*
   Gamma function specified by the IEC61966-2-1 specification (sRGB).
   Converts gamma-space RGB to linear RGB.
   This is the correct function to use for a modern sRGB computer monitor,
   definitely more accurate than just using a pure power function.

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

#include "saturate.inc"

vec3 sRGBtoLinear(vec3 colorin){
    bvec3 cutoff = lessThanEqual(colorin.rgb, vec3(0.04045));
    vec3 higher = pow(((colorin.rgb + vec3(0.055))/vec3(1.055)), vec3(2.4));
    vec3 lower = colorin.rgb / vec3(12.92);
    vec3 colorout = saturate(mix(higher, lower, cutoff));
    return colorout;
}
