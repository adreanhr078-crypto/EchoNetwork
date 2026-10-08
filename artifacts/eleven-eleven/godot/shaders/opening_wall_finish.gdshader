shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(0.16,0.19,0.25,1.0);
uniform float metalness = 0.26;
varying vec3 world_pos;
varying vec3 world_normal;
float hash21(vec2 p) {
    vec3 q = fract(vec3(p.xyx)*0.1031);
    q += dot(q,q.yzx+33.33);
    return fract((q.x+q.y)*q.z);
}
void vertex() {
    world_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    // Per-metre painted enamel band, brushed substrate and contact dirt.
    vec3 facing = abs(world_normal);
    vec2 p = facing.x > max(facing.y,facing.z) ? world_pos.zy : (facing.y > facing.z ? world_pos.xz : world_pos.xy);
    float grain_fade = 1.0-smoothstep(0.004,0.018,length(fwidth(p)));
    float grain = mix(0.5,hash21(floor(p*140.0)),grain_fade);
    float brush_phase = p.y*440.0;
    float brush = sin(brush_phase)*0.008*(1.0-smoothstep(0.7,2.0,fwidth(brush_phase)));
    float band = smoothstep(1.3,1.34,world_pos.y)*(1.0-smoothstep(1.49,1.53,world_pos.y));
    float footing = 1.0-smoothstep(0.05,0.75,world_pos.y);
    vec3 enamel = base_color.rgb*(0.94+grain*0.10+brush);
    enamel = mix(enamel,vec3(0.13,0.24,0.30),band*0.60);
    ALBEDO = enamel*(1.0-footing*0.26);
    METALLIC = metalness;
    ROUGHNESS = 0.58+(grain-0.5)*0.07;
    SPECULAR = 0.3;
}
