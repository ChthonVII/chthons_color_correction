#version 450

layout(set = 0, binding = 0, std140) uniform UBO {
    mat4 MVP;
};

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
    float MaxSpotSize;
    float MinSpotSize;
} params;
#pragma parameter MaxSpotSize "Maximum spot size (proportion of scanline)" 0.95 0.6 1.0 0.05
#pragma parameter MinSpotSize "Minimum spot size (proportion of maximum)" 0.4 0.3 1.0 0.1

#pragma format R16G16B16A16_SFLOAT

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float delta;

void main() {
    // aspect ratio is already corrected by earlier shader
    // overscan is cropped by core
    gl_Position = MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(binding = 1) uniform sampler2D Source;
layout(binding = 2) uniform sampler2D UnsquashedSource;

// moved calculate_widths.slang
vec3 compute_rcp(vec3 sample_value) {
    vec3 width_rcp =  1.0 / (params.MinSpotSize * params.MaxSpotSize - sqrt(sample_value) * (params.MinSpotSize * params.MaxSpotSize - params.MaxSpotSize));
    return width_rcp;
}

vec3 spot(vec3 sample_value, vec3 width_rcp, float distance_y) {
    vec3 y = clamp(abs(distance_y) * width_rcp, 0.0, 1.0);
    return sample_value * width_rcp * ((y * y) * ((2.0 * y) - 3.0) + 1.0);
    //return y;
}

void main() {
    // Sample locations in Source texel space: [0, SourceSize.y), snapped to the
    // middle of a texel.
    float upper_sample_y, lower_sample_y;
    // Distance units are *scanlines heights*.
    float upper_distance_y, lower_distance_y;

    // Cut interlacing support; just grab the two closest lines.
    // This is buggy -- use Hyllian's implementation instead
    //upper_sample_y = round(vTexCoord.y * params.SourceSize.y) + 0.5;
    //lower_sample_y = upper_sample_y - 1.0;
    //upper_distance_y = upper_sample_y - vTexCoord.y * params.SourceSize.y;
    //lower_distance_y = 1.0 - upper_distance_y; //upper_distance_y - 1.0;

    //upper_sample_y = vTexCoord.y;
    //lower_sample_y = vTexCoord.y + params.SourceSize.w;
    //upper_distance_y = fract(upper_sample_y * params.SourceSize.y);
    //lower_distance_y = 1.0 - upper_distance_y;

    lower_sample_y = floor(vTexCoord.y * params.SourceSize.y) + 0.5;
    upper_sample_y = lower_sample_y + 1.0;
    //upper_distance_y = upper_sample_y - vTexCoord.y * params.SourceSize.y;
    //lower_distance_y = 1.0 - upper_distance_y; //upper_distance_y - 1.0;
    lower_distance_y = fract(lower_sample_y);
    upper_distance_y = 1.0 - lower_distance_y;

    // Transform *_sample_y into [0,1] coordinate space. We need them for the
    // texture sampling below.
    upper_sample_y *= params.SourceSize.w;
    lower_sample_y *= params.SourceSize.w;

    vec3 value = vec3(0.0);

    // We are only scaling along the y axis, so remove looping over x
    //
    vec3 real_sample = texture(UnsquashedSource, vTexCoord).xyz;
    //vec3 upper_sample = textureLod(Source, vec2(sample_x, upper_sample_y), 0.0).rgb;

    //vec3 squashed_upper_sample = textureLod(Source, vec2(vTexCoord.x, upper_sample_y), 0.0).xyz;
    vec3 squashed_upper_sample = texture(Source, vec2(vTexCoord.x, upper_sample_y)).xyz;
    vec3 upper_width_rcp = compute_rcp(squashed_upper_sample);
    //vec3 upper_width_rcp = textureLod(Source, vec2(sample_x, upper_sample_y), 0.0).rgb;

    //vec3 lower_sample = texture(UnsquashedSource, vec2(vTexCoord.x, lower_sample_y)).xyz;
    //vec3 lower_sample = textureLod(, vec2(sample_x, lower_sample_y), 0.0).rgb;

    //vec3 squashed_lower_sample = textureLod(Source, vec2(vTexCoord.x, lower_sample_y), 0.0).xyz;
    vec3 squashed_lower_sample = texture(Source, vec2(vTexCoord.x, lower_sample_y)).xyz;
    vec3 lower_width_rcp = compute_rcp(squashed_lower_sample);
    //vec3 lower_width_rcp = textureLod(Source, vec2(sample_x, lower_sample_y), 0.0).rgb;

    value += spot(real_sample, upper_width_rcp, upper_distance_y);
    value += spot(real_sample, lower_width_rcp, lower_distance_y);

    value = clamp(value, 0.0, 1.0);

    FragColor = vec4(value, 1.0);
    //FragColor = vec4(lower_width_rcp, 1.0);
}
