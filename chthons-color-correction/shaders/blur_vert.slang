#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float GLOW_FALLOFF;
    float GLOW_TAPS;
} params;

// Higher value, more centered glow.
// Lower values might need more taps.
#pragma parameter GLOW_FALLOFF "Halation Glow Falloff" 0.35 0.0 1.0 0.01
#pragma parameter GLOW_TAPS "Halation Glow Taps" 4.0 1.0 10.0 1.0

#define GLOW_FALLOFF params.GLOW_FALLOFF
#define TAPS int(params.GLOW_TAPS)

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;


#define kernel(x) exp(-GLOW_FALLOFF * (x) * (x))

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

void main()
{
	vec3 col = vec3(0.0);
	float dy = params.SourceSize.w;

	float k_total = 0.0;
	for (int i = -TAPS; i <= TAPS; i++)
		{
		float k = kernel(i);
		k_total += k;
		col += k * texture(Source, vTexCoord + vec2(0.0, float(i) * dy)).rgb;
		}
   FragColor = vec4(col / k_total, 1.0);
}
