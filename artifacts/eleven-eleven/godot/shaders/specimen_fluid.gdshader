shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

uniform float motion_time = 0.0;
uniform vec4 fluid_color : source_color = vec4(0.08, 0.30, 0.37, 0.45);
uniform float fill_height = 3.8;
varying float fill_axis;
void vertex() { fill_axis = clamp(0.5+VERTEX.y/fill_height,0.0,1.0); }

void fragment() {
    // Slow circulation within the physical tank, with a quiet meniscus.
    // A room-owned clock preserves pause and Reduced Motion.
    float flow = sin(fill_axis * 13.0 - motion_time * 0.55
        + sin(UV.x * 6.283185 + motion_time * 0.18) * 0.7);
    float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
    float meniscus = smoothstep(0.92,0.99,fill_axis);
    ALBEDO = fluid_color.rgb * (0.86 + flow * 0.08);
    EMISSION = fluid_color.rgb * (0.40 + edge * 0.60 + meniscus * 0.48);
    ROUGHNESS = 0.42;
    METALLIC = 0.0;
    ALPHA = fluid_color.a + edge * 0.12 + meniscus * 0.08;
}
