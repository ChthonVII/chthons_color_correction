layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    float crtBlackLevel;
    float crtWhiteLevel;
    float crtConstantB;
    float crtConstantK;
    float crtConstantS;
    float crtGammaKnob;
    float crtMatrixRR;
    float crtMatrixRG;
    float crtMatrixRB;
    float crtMatrixGR;
    float crtMatrixGG;
    float crtMatrixGB;
    float crtMatrixBR;
    float crtMatrixBG;
    float crtMatrixBB;
    float crtLowClamp;
    float crtHighClampEnable;
    float crtHighClamp;
    float crtBlackCrush;
    float crtBlackCrushAmount;
    float crtSuperBlackEnable;
} global;

// Black and white levels are in units of 100x cd/m^2. E.g., 1.71 means 171 cd/m^2
// (Defaults to 0.01 to 171 cd/m^2)
#pragma parameter crtBlackLevel "CRT Black Level (requires LUT recomputation)" 0.0001 0.0 1.0 0.0001
#pragma parameter crtWhiteLevel "CRT White Level (requires LUT recomputation)" 1.71 0.0 100.0 0.01

// EOTF function from BT.1886 Appendix 1 constants
// B is calibrated so that input of 0 yeilds output at black level
// The others can be calculated from B, but are precomputed here for performance
// (Defaults to 0.01 to 171 cd/m^2)
#pragma parameter crtConstantB "CRT Constant B (requires LUT recomputation)" 0.0352201203161258 0.0 1.0 0.0001
#pragma parameter crtConstantK "CRT Constant K (requires LUT recomputation)" 1.5628276249141149 0.0 10.0 0.0001
#pragma parameter crtConstantS "CRT Constant S (requires LUT recomputation)" 1.4645911818943733 0.0 10.0 0.0001

// CRT gamma knob
#pragma parameter crtGammaKnob "CRT Gamma Adjustment Knob (requires LUT recomputation)" 1.0 0.01 10.0 0.01

// CRT matrix values need to be precomputed by gamutthingy
// Rolls together CRT "color correction" behavior, hue knob, and saturation knob
// Default is...
#pragma parameter crtMatrixRR "CRT Matrix RR (requires LUT recomputation)" 1.2903583403 -2.0 2.0 0.01
#pragma parameter crtMatrixRG "CRT Matrix RG (requires LUT recomputation)" -0.1862128636 -2.0 2.0 0.01
#pragma parameter crtMatrixRB "CRT Matrix RB (requires LUT recomputation)" -0.1041454767 -2.0 2.0 0.01
#pragma parameter crtMatrixGR "CRT Matrix GR (requires LUT recomputation)" 0.0133998891 -2.0 2.0 0.01
#pragma parameter crtMatrixGG "CRT Matrix GG (requires LUT recomputation)" 0.9814911231 -2.0 2.0 0.01
#pragma parameter crtMatrixGB "CRT Matrix GB (requires LUT recomputation)" 0.0051089878 -2.0 2.0 0.01
#pragma parameter crtMatrixBR "CRT Matrix BR (requires LUT recomputation)" 0.0 -2.0 2.0 0.01
#pragma parameter crtMatrixBG "CRT Matrix BG (requires LUT recomputation)" 0.0 -2.0 2.0 0.01
#pragma parameter crtMatrixBB "CRT Matrix BB (requires LUT recomputation)" 1.0 -2.0 2.0 0.01

// Black pedestal crushing
#pragma parameter crtBlackCrush "CRT Black Pedestal Crush (requires LUT recomputation)" 0.0 0.0 1.0 1.0
#pragma parameter crtBlackCrushAmount "CRT Black Pedestal Crush Amount (ditto)" 0.075 0.0 1.0 0.001
// Super blacks can go with pedestal
#pragma parameter crtSuperBlackEnable "CRT Show Super Blacks (requires LUT recomputation)" 0.0 0.0 1.0 1.0



// CRT clamping
// Low is required to match gamutthingy's behavior (which clamps low b/c the Jzazbz PQ function can't handle certain negatives)
#pragma parameter crtLowClamp "CRT Matrix Output Low Clamp (requires LUT recomputation)" -0.1 -0.2 0.0 0.01
#pragma parameter crtHighClampEnable "CRT Matrix Output Enable High Clamp (ditto)" 1.0 0.0 1.0 1.0
#pragma parameter crtHighClamp "CRT Matrix Output High Clamp (requires LUT recomputation)" 1.1 1.0 10.0 0.01


