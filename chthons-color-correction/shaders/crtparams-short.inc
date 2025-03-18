layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    float crtBlackLevel;
    float crtWhiteLevel;
    float crtConstantB;
    float crtConstantK;
    float crtConstantS;
    float crtGammaKnob;
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
