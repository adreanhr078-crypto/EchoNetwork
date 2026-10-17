shader_type spatial;

// A single opaque surface pass. No new geometry, lights, displacement or TIME.
uniform vec4 base_color : source_color = vec4(0.38,0.46,0.56,1.0);
uniform vec2 panel_pitch = vec2(2.4,1.2);
uniform float metal = 0.22;
uniform float base_roughness = 0.6;
varying vec3 world_point;
varying vec3 world_normal;
void vertex() {
    world_point = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    vec3 n = abs(normalize(world_normal));
    vec2 p = n.y > 0.65 ? world_point.xz : n.x > n.z ? world_point.zy : world_point.xy;
    vec2 cell = fract(p/panel_pitch);
    vec2 edge = min(cell,1.0-cell)*panel_pitch;
    float min_edge = min(edge.x,edge.y);
    float joint = 1.0-smoothstep(0.004,0.012,min_edge);
    float lip = smoothstep(0.012,0.018,min_edge)*(1.0-smoothstep(0.018,0.028,min_edge));
    float stain = 0.5+0.5*sin(p.x*1.7)*sin(p.y*1.1);
    vec3 paint = base_color.rgb*(0.88+stain*0.10);
    ALBEDO = mix(paint*(1.0+lip*0.05),paint*0.78,joint*0.65);
    METALLIC = metal;
    ROUGHNESS = mix(clamp(base_roughness+(stain-0.5)*0.12-lip*0.12,0.38,0.85),0.88,joint);
}
