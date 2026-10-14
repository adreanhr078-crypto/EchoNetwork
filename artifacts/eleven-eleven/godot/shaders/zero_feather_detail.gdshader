shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform sampler2D source_albedo : source_color;
uniform sampler2D source_normal : hint_normal;
uniform sampler2D source_roughness;
uniform sampler2D source_metallic;
uniform bool has_normal = false;
uniform bool has_roughness = false;
uniform bool has_metallic = false;
uniform int roughness_channel = 1;
uniform int metallic_channel = 2;
uniform float local_time = 0.0;
uniform float intensity = 0.0;
uniform bool reduced_motion = false;
varying float camera_distance;

float channel_value(vec4 value, int channel) {
    if (channel == 0) { return value.r; }
    if (channel == 1) { return value.g; }
    if (channel == 2) { return value.b; }
    return value.a;
}

void vertex() {
    camera_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
    vec4 painted = texture(source_albedo, UV);
    ALBEDO = max(painted.rgb * vec3(0.90, 0.88, 0.97), vec3(0.030, 0.025, 0.042));
    float roughness_value = has_roughness ? channel_value(texture(source_roughness, UV), roughness_channel) : 0.52;
    float metallic_value = has_metallic ? channel_value(texture(source_metallic, UV), metallic_channel) : 0.14;
    ROUGHNESS = clamp(roughness_value, 0.43, 0.78);
    METALLIC = clamp(metallic_value, 0.0, 0.22);
    if (has_normal) {
        NORMAL_MAP = texture(source_normal, UV).rgb;
        NORMAL_MAP_DEPTH = 0.62;
    }
    float purple = smoothstep(0.015, 0.08, painted.b - painted.r * 1.12);
    float strands = 0.96 + 0.04 * sin(local_time * 1.8 + UV.y * 7.0);
    float breath = reduced_motion ? 1.0 : strands;
    float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.5);
    EMISSION = ALBEDO * 0.10 + vec3(0.20, 0.025, 0.39) * (purple * 0.36 + rim * 0.028) * intensity * breath;
    // Camera proximity affects this presentation only. It cannot hide a wall,
    // collider, or actor, and prevents a close gameplay camera entering feathers.
    ALPHA = painted.a * smoothstep(0.10, 0.38, camera_distance);
}
