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
layout(set = 0, binding = 3) uniform sampler2D XbrOutput;
layout(set = 0, binding = 4) uniform sampler2D AnalysisPass;


void main()
{
    vec3 hirescolor = texture(Source, vTexCoord.xy).xyz;
    vec3 xbrcolor = texture(XbrOutput, vTexCoord.xy).xyz;
    float selector = texture(AnalysisPass, vTexCoord.xy).w;

    vec3 diff = abs(xbrcolor - hirescolor)/(max(xbrcolor, hirescolor));
    float bdiff = max(diff.x, max(diff.y, diff.z));

    vec3 color = ((selector == 1.0) || (bdiff > 102.85)) ? xbrcolor : mix(hirescolor, vec3(0.0, 0.0, 1.0), 0.0);

    FragColor = vec4(color, 1.0);
}
