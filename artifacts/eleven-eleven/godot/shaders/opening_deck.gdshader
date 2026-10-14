shader_type spatial;
render_mode cull_back;

// Metre-scaled ceramic deck. No screen reads; works on Compatibility.
uniform vec4 floor_color : source_color = vec4(0.26, 0.30, 0.35, 1.0);
uniform vec4 water_tint : source_color = vec4(0.035, 0.15, 0.19, 1.0);
uniform float motion_time = 0.0;
uniform float ripple_amount = 1.0;
uniform float reaction = 0.0;
uniform vec2 reaction_origin = vec2(-1.85, 1.8);
uniform float reaction_age = 0.0;
uniform float power_state = 0.0;
varying vec3 world_pos;

float hash21(vec2 p) {
    vec3 q = fract(vec3(p.xyx)*0.1031);
    q += dot(q,q.yzx+33.33);
    return fract((q.x+q.y)*q.z);
}
float noise21(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), u.x),
               mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), u.x), u.y);
}
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 p = world_pos.xz;
    vec2 tile = p / vec2(1.5, 2.4);
    vec2 edge = min(fract(tile), 1.0 - fract(tile));
    vec2 edge_m = edge * vec2(1.5, 2.4);
    float seam_distance = min(edge_m.x, edge_m.y);
    float aa = max(fwidth(seam_distance), 0.002);
    float seam = 1.0 - smoothstep(0.004 - aa, 0.009 + aa, seam_distance);
    float grime = 1.0 - smoothstep(0.015, 0.13, seam_distance);
    float tile_tone = hash21(floor(tile));
    float grain_fade = 1.0-smoothstep(0.006,0.025,length(fwidth(p)));
    float grain = mix(0.5,noise21(p * 95.0),grain_fade);
    float wear = noise21(p * 3.5);
    vec3 ceramic = floor_color.rgb * (0.88 + tile_tone * 0.20 + (grain - 0.5) * 0.06);
    ceramic = mix(ceramic, ceramic * 0.65, grime * 0.28);
    ceramic = mix(ceramic, vec3(0.09, 0.115, 0.145), seam * 0.40);

    // The capsule coolant leak has a visible source, unlike room-wide water.
    float leak_area = 1.0 - smoothstep(1.2, 4.8, length((p - vec2(-2.5, 2.8)) * vec2(0.9, 1.2)));
    float drip_area = 1.0 - smoothstep(0.35, 2.2, length(p - vec2(6.6, -5.5)));
    float puddle_noise = noise21(p * 0.85) * 0.7 + noise21(p * 2.1) * 0.3;
    float wet = smoothstep(0.44, 0.60, puddle_noise) * max(leak_area, drip_area * 0.7);
    float damp = smoothstep(0.32, 0.56, puddle_noise) * leak_area;
    vec3 damp_color = mix(ceramic * 0.7, water_tint.rgb, 0.35);
    ALBEDO = mix(ceramic, damp_color, damp * 0.5 + wet * 0.5);
    METALLIC = 0.10;
    ROUGHNESS = mix(0.55 + (wear - 0.5) * 0.12, 0.14, wet);
    SPECULAR = mix(0.32, 0.58, wet);

    vec2 normal_ripple = vec2(0.0);
    if (wet > 0.01 && ripple_amount > 0.0) {
        float dist = length(p - vec2(6.6, -5.5));
        float circular_wave = sin(dist * 15.0 - mod(motion_time*1.4,6.2831853)) * exp(-dist * 1.1);
        normal_ripple = vec2(sin(p.x*22.0+mod(motion_time*0.6,6.2831853)),cos(p.y*24.0-mod(motion_time*0.45,6.2831853)));
        normal_ripple += circular_wave * vec2(0.7, 0.9);
    }
    NORMAL_MAP = normalize(vec3(normal_ripple * wet * 0.022 * ripple_amount, 1.0)) * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = 0.22;

    // Local, soft practical-light sheen; no fabricated SSR mirror.
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
    float cyan_rail = exp(-abs(abs(p.x) - 7.7) * 1.8);
    float amber_clock = exp(-length((p - vec2(-1.85, 1.8)) * vec2(0.8, 0.35)) * 1.2);
    float violet_glass = exp(-length((p - vec2(8.0, -6.0)) * vec2(1.0, 0.35)) * 0.9);
    vec3 sheen = vec3(0.035, 0.30, 0.40) * cyan_rail + vec3(0.30, 0.11, 0.025) * amber_clock;
    sheen += vec3(0.16, 0.06, 0.28) * violet_glass;
    EMISSION = sheen * fresnel * (0.12 + wet * 0.35) * (1.0 + reaction * 0.15);
    // A physical feed from the real conduit to the door, kept below foot level.
    float across = (1.0-smoothstep(0.045,0.095,abs(p.y+4.0))) * step(-3.5,p.x) * step(p.x,0.0);
    float toward_gate = (1.0-smoothstep(0.045,0.095,abs(p.x))) * step(-17.2,p.y) * step(p.y,-4.0);
    float path_distance = p.y > -4.08 ? p.x+3.5 : 3.5+(-4.0-p.y);
    float packet = pow(max(0.0,cos(path_distance*3.2-motion_time*4.0)),10.0);
    float flow = max(across,toward_gate)*power_state;
    EMISSION += vec3(0.04,0.65,0.88)*flow*(0.38+packet*1.5*ripple_amount);
    // One bounded discovery wave per real inspection; no autonomous progress.
    float ring_distance = abs(length(p-reaction_origin)-(0.35+reaction_age*1.5));
    float ring = 1.0-smoothstep(0.025,0.075,ring_distance);
    EMISSION += vec3(0.16,0.70,0.82)*ring*reaction*1.25*ripple_amount;
}
