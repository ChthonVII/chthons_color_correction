/*
   Simulation of CRT matrix and knobs.
   Matrix values need to be precomputed by gamutthingy.
   Matrix rolls together CRT "color correction" behavior, hue knob, and saturation knob.
   Then matrix output may be clamped.
   Gamma adjustment knob and EOTF function (which reflects brightness and contrast knobs) are applied elsewhere.

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

vec3 crtMatrixAndKnobs(vec3 colorin){

    // crush black pedestal
    vec3 crushed = (colorin - vec3(global.crtBlackCrushAmount)) / vec3(1.0 - global.crtBlackCrushAmount);
    crushed = max(crushed, vec3(0.0));
    colorin = mix(colorin, crushed, global.crtBlackCrush);

    // flip matrix b/c slang is column-major
    mat3 crtMatrix = mat3(
        global.crtMatrixRR, global.crtMatrixGR, global.crtMatrixBR,
        global.crtMatrixRG, global.crtMatrixGG, global.crtMatrixBG,
        global.crtMatrixRB, global.crtMatrixGB, global.crtMatrixBB
    );

    // multiply matrix by input
    vec3 colorout = crtMatrix * colorin;

    // clamp
    colorout = max(colorout, vec3(global.crtLowClamp));
    vec3 highclamp = min(colorout, global.crtHighClamp);
    colorout = mix(colorout, highclamp, vec3(global.crtHighClampEnable));

    return colorout;
}
