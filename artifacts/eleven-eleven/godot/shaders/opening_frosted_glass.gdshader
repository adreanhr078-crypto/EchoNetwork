shader_type spatial;
render_mode cull_back;

// Opaque backed frost: no alpha sorting, screen texture or extra render target.
uniform vec4 glass_tint : source_color = vec4(0.16, 0.28, 0.34, 1.0);
uniform vec4 backing_tint : source_color = vec4(0.25, 0.13, 0.33, 1.0);
uniform float reaction = 0.0;
varying vec3 world_pos;

// Polynomial hash keeps mobile/Compatibility precision from making square blocks.
float hash21(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float noise21(vec2 p) {
    vec2 cell = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(cell), hash21(cell+vec2(1,0)),u.x),
               mix(hash21(cell+vec2(0,1)),hash21(cell+vec2(1,1)),u.x),u.y);
}
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p = world_pos.zy;
    float frost = noise21(p * 6.0);
    float grain = noise21(p * 60.0);
    vec2 grid = p * vec2(15.0,10.0);
    vec2 cell = floor(grid);
    vec2 droplet_center = vec2(hash21(cell), hash21(cell+29.0)) * 0.55 + 0.22;
    vec2 d = fract(grid) - droplet_center;
    float droplets = (1.0-smoothstep(0.055,0.12,length(d * vec2(1.0,0.65)))) * step(0.70,hash21(cell+71.0));
    float droplet_distance = length(d * vec2(1.0,0.65));
    float droplet_aa = max(fwidth(droplet_distance),0.008);
    float droplet_rim = (1.0-smoothstep(0.012,0.012+droplet_aa,abs(droplet_distance-0.08))) * step(0.70,hash21(cell+71.0));
    float drip = exp(-abs(fract(p.x * 9.0)-0.5)*55.0) * noise21(vec2(floor(p.x*9.0), p.y*0.45));
    float diagonal = exp(-pow((p.x * 0.55 + p.y * 0.85 - 0.75),2.0) * 4.0);
    float instrument_shadow = smoothstep(0.37,0.46,noise21(p*vec2(1.8,0.7)));
    float fresnel = pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),3.5);
    vec3 backed = mix(glass_tint.rgb, backing_tint.rgb * 0.7, frost * 0.5);
    backed *= 0.88 + frost*0.22 - instrument_shadow*0.13;
    backed += diagonal * vec3(0.08,0.12,0.14) + droplet_rim*0.035;
    ALBEDO = backed + (grain-0.5)*0.008;
    METALLIC = 0.13;
    ROUGHNESS = clamp(0.40 + frost*0.08 - droplets*0.12,0.28,0.5);
    SPECULAR = 0.45;
    EMISSION = backing_tint.rgb * (0.11 + reaction*0.04) + fresnel*vec3(0.03,0.08,0.09);
    NORMAL_MAP = normalize(vec3(d * droplets * 0.018 + vec2(drip*0.004,0),1.0))*0.5+0.5;
    NORMAL_MAP_DEPTH = 0.16;
}
