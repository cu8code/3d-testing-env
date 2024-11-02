shader_type spatial;
render_mode depth_prepass_alpha, cull_disabled;

instance uniform float instance_custom_data;

uniform int shell_count : hint_range(1, 100) = 32;
uniform float shell_height : hint_range(0.0, 2.0) = 0.2;
uniform sampler2D noise_texture : hint_default_white;
uniform vec4 fur_color : source_color = vec4(0.43, 0.32, 0.2, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float fur_length : hint_range(0.0, 2.0) = 0.3;
uniform float gravity = -0.1;
uniform vec2 wind_direction = vec2(0.0, 1.0);
uniform float wind_strength = 0.1;
uniform float time_scale = 1.0;

void vertex() {
    float shell_index = instance_custom_data;
    vec3 normal = NORMAL;
    float displacement = shell_index * shell_height;

    vec3 gravity_vec = vec3(0.0, gravity, 0.0);
    vec3 wind = vec3(wind_direction.x, 0.0, wind_direction.y) * wind_strength * sin(TIME * time_scale);

    VERTEX += normal * displacement;
    VERTEX += gravity_vec * displacement * displacement;
    VERTEX += wind * displacement;
}

void fragment() {
    float shell_index = instance_custom_data;
    vec2 uv = UV * 10.0;
    float noise = texture(noise_texture, uv).r;
    float fur_mask = step(noise, density);

    float tip_strength = pow(shell_index, 3.0);
    float alpha = fur_mask * (1.0 - tip_strength);

    if (alpha < 0.01) {
        discard;
    }

    ALBEDO = fur_color.rgb;
    ALPHA = alpha;
    ROUGHNESS = 0.8;
    SPECULAR = 0.2;
}