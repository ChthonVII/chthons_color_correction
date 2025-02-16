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
   float maxoffset = ((params.SourceSize.y - params.OutputSize.y) / 2.0) * (1.0 / (params.SourceSize.y - 1.0));
   float offset = mix(maxoffset, -1.0 * maxoffset, vTexCoord.y);
   float newY = clamp(vTexCoord.y + offset, 0.0, 1.0);
   vec2 newCoord = vec2(vTexCoord.x, newY);
   FragColor = vec4(texture(Source, newCoord).rgb, 1.0);
}
