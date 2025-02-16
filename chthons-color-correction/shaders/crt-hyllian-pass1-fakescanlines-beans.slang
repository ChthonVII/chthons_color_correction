#version 450

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float BEAM_MIN_WIDTH;
    float BEAM_MAX_WIDTH;
} params;


#pragma parameter BEAM_MIN_WIDTH "MIN BEAM WIDTH" 0.72 0.0 1.0 0.01
#pragma parameter BEAM_MAX_WIDTH "MAX BEAM WIDTH" 1.0 0.0 1.0 0.01


#define BEAM_MIN_WIDTH params.BEAM_MIN_WIDTH
#define BEAM_MAX_WIDTH params.BEAM_MAX_WIDTH


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
layout(location = 1) in vec2 FragCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D UnsquashedSource;


vec3 get_scanlines_new(vec3 color0, vec3 color1, vec3 realcolor, float pos0, float pos1){
   vec3 rcp0 = 1.0 / ((BEAM_MIN_WIDTH * BEAM_MAX_WIDTH) - (sqrt(color0) * ((BEAM_MIN_WIDTH * BEAM_MAX_WIDTH) - BEAM_MAX_WIDTH)));
   vec3 rcp1 = 1.0 / ((BEAM_MIN_WIDTH * BEAM_MAX_WIDTH) - (sqrt(color1) * ((BEAM_MIN_WIDTH * BEAM_MAX_WIDTH) - BEAM_MAX_WIDTH)));
   vec3 rcpr = 1.0 / ((BEAM_MIN_WIDTH * BEAM_MAX_WIDTH) - (sqrt(realcolor) * ((BEAM_MIN_WIDTH * BEAM_MAX_WIDTH) - BEAM_MAX_WIDTH)));

   vec3 y0 = saturate(vec3(pos0) * rcp0);
   vec3 y1 = saturate(vec3(pos1) * rcp1);
   vec3 yr0 = saturate(vec3(pos0) * rcpr);
   vec3 yr1 = saturate(vec3(pos1) * rcpr);

   vec3 w0 = rcp0 * ((y0 * y0 * ((2.0 * y0) - 3.0)) + 1.0);
   vec3 w1 = rcp1 * ((y1 * y1 * ((2.0 * y1) - 3.0)) + 1.0);
   vec3 wr0 = rcpr * ((yr0 * yr0 * ((2.0 * yr0) - 3.0)) + 1.0);
   vec3 wr1 = rcpr * ((yr1 * yr1 * ((2.0 * yr1) - 3.0)) + 1.0);

   vec3 wsum = w0 + w1;
   vec3 wrsum = wr0 + wr1;

   bvec3 isgain = greaterThan(wsum, vec3(1.0));
   vec3 cap = min(wsum, wrsum);
   vec3 floor = max(wsum, wrsum);
   vec3 finalsum = mix(floor, cap, isgain);

   vec3 newcolor = saturate(realcolor * finalsum);
   return newcolor;
}

void main()
{
    vec3 color;
    vec2 dy = vec2(0.0, 1.0/params.SourceSize.y);

    vec2 pix_coord = (vTexCoord.xy * params.SourceSize.xy) + vec2(0.0, -0.5);

    vec2 tc = ((floor(pix_coord) + vec2(0.5,0.5)) )/params.SourceSize.xy;

    vec2 fp = fract(pix_coord);

    vec3 color0 = texture(Source, tc     ).xyz;
    vec3 color1 = texture(Source, tc + dy).xyz;
    vec3 realcolor = texture(UnsquashedSource, vTexCoord.xy).xyz;

    float pos0 = fp.y;
    float pos1 = 1 - fp.y;

    color = get_scanlines_new(color0, color1, realcolor, pos0, pos1);

    FragColor = vec4(color, 1.0);
}
