#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

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
   float newX = (vTexCoord.x - 0.125) / 0.75;
   bool inbounds = ((newX >= 0.0) && (newX < 1.0));
   newX = clamp(newX, 0.0, 1.0);
   vec2 newCoord = vec2(newX, vTexCoord.y);
   vec3 letterboxcolor = vec3(0.0);
   vec3 gamecolor = texture(Source, newCoord).rgb;
   vec3 outcolor = mix(letterboxcolor, gamecolor, bvec3(inbounds));
   FragColor = vec4(outcolor, 1.0);
}
