shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;

uniform sampler2D source_albedo : source_color, filter_linear_mipmap;
uniform float local_time = 0.0;
uniform float intensity = 0.0;
uniform bool reduced_motion = false;

void fragment() {
    vec3 painted = texture(source_albedo, UV).rgb;
    float highest = max(painted.r, max(painted.g, painted.b));
    float lowest = min(painted.r, min(painted.g, painted.b));
    float saturation = (highest - lowest) / max(highest, 0.001);
    float cyan = smoothstep(0.025, 0.10, min(painted.b - painted.r, painted.g - painted.r));
    float iris = cyan * smoothstep(0.40, 0.65, saturation);
    float detail = dot(painted, vec3(0.2126, 0.7152, 0.0722));
    vec3 violet = vec3(0.115, 0.012, 0.265) * (0.45 + detail * 1.8);
    ALBEDO = violet;
    float breath = reduced_motion ? 1.0 : 0.97 + 0.03 * sin(local_time * 1.7);
    EMISSION = violet * 0.09 * clamp(intensity, 0.0, 1.8) * breath;
    ROUGHNESS = 0.43;
    METALLIC = 0.0;
    // Source dark pupil, whites, skin, hair and eyelids receive no overlay.
    ALPHA = iris * clamp(intensity, 0.0, 1.0);
}
