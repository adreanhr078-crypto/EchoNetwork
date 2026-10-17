shader_type spatial;
render_mode cull_disabled;

// Local finish only: original geometry, UVs and source images stay intact.
uniform sampler2D source_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform bool textured = false;
uniform vec4 tint : source_color = vec4(0.28, 0.34, 0.41, 1.0);
uniform float metal = 0.45;
uniform float base_roughness = 0.6;
// Opt-in connected-route opening in the joined backstop mesh. Bounds are
// supplied by the same adapter that opens its original physics boundary.
uniform bool campaign_aperture = false;
uniform mat4 aperture_room_inverse = mat4(1.0);
uniform vec3 aperture_min;
uniform vec3 aperture_max;
varying vec3 world_point;

void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 room_point = (aperture_room_inverse * vec4(world_point, 1.0)).xyz;
    if (campaign_aperture && all(greaterThanEqual(room_point, aperture_min))
            && all(lessThanEqual(room_point, aperture_max))) {
        discard;
    }
    vec3 base = textured ? texture(source_albedo, UV).rgb * tint.rgb : tint.rgb;
    // Restrained brushed grain and oil variation, no animated noise or screen effects.
    float brush = sin(world_point.y * 140.0 + sin(world_point.x * 37.0) * 0.7);
    float stain = 0.5 + 0.5 * sin(world_point.x * 2.3 + world_point.z * 1.8)
        * sin(world_point.y * 3.7 + world_point.z * 0.6);
    ALBEDO = base * (0.89 + stain * 0.12 + brush * 0.004);
    METALLIC = metal;
    ROUGHNESS = clamp(base_roughness + (stain - 0.5) * 0.16, 0.32, 0.88);
}
