shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

instance uniform float instance_custom_data;

uniform vec4 grass_color : source_color = vec4(0.33, 0.55, 0.24, 1.0);
uniform vec4 grass_color_variation : source_color = vec4(0.1, 0.1, 0.1, 0.0);
uniform float wind_strength : hint_range(0.0, 2.0) = 0.5;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
uniform vec2 wind_direction = vec2(1.0, 0.5);

void vertex() {
    // Add wind movement
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float wind = sin(TIME * wind_speed + world_pos.x + world_pos.z);
    vec3 wind_vec = vec3(wind_direction.x, 0.0, wind_direction.y) * wind * wind_strength;

    // Apply wind based on height of vertex
    float height_factor = VERTEX.y;
    VERTEX += wind_vec * height_factor;
}

void fragment() {
    // Add slight color variation based on position
    vec3 variation = grass_color_variation.rgb * sin(vec3(
        VERTEX.x * 10.0,
        VERTEX.y * 5.0,
        VERTEX.z * 15.0
    ));

    ALBEDO = grass_color.rgb + variation;
    SPECULAR = 0.1;
    ROUGHNESS = 0.9;
}