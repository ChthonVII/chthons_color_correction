#version 450



layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float HALATION_STRENGTH;
    float DIFFUSION_STRENGTH;
} params;

#pragma parameter HALATION_STRENGTH "Halation Strength" 0.07 0.0 1.0 0.01
#pragma parameter DIFFUSION_STRENGTH "Diffusion Strength" 0.02 0.0 1.0 0.01

#define HALATION_STRENGTH params.HALATION_STRENGTH
#define DIFFUSION_STRENGTH params.DIFFUSION_STRENGTH

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
layout(set = 0, binding = 3) uniform sampler2D NoBlurSource;
layout(set = 0, binding = 4) uniform sampler2D LightBlurSource;

float luminosity(vec3 colorin){
    return (colorin.x * 0.212649342720653) + (colorin.y * 0.715169135705904) + (colorin.z * 0.0721815215734433);
}



void main()
{
    vec3 blurcolor = texture(Source, vTexCoord.xy).xyz;
    vec3 noblurcolor = texture(NoBlurSource, vTexCoord.xy).xyz;
    vec3 lightblurcolor = texture(LightBlurSource, vTexCoord.xy).xyz;

    float lblur = luminosity(blurcolor);
    float lnoblur = luminosity(noblurcolor);
    float brightnessdelta = max(0.0, lblur - lnoblur);

    vec3 color = mix(noblurcolor, lightblurcolor, vec3(DIFFUSION_STRENGTH));
    color = mix(color, blurcolor, vec3(brightnessdelta * HALATION_STRENGTH));

    FragColor = vec4(color, 1.0);
}
