shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float event_age = 4.0;
uniform vec4 tint : source_color = vec4(0.12,0.72,0.9,1.0);
varying float fade;
void vertex() {
    float age = event_age-INSTANCE_CUSTOM.x*0.16;
    float active = step(0.0,age)*step(age,1.8);
    float progress = clamp(age/1.8,0.0,1.0);
    float radius = 0.7+progress*2.0;
    VERTEX.xz *= radius;
    VERTEX.y += 0.14+INSTANCE_CUSTOM.x*0.22+progress*0.12;
    fade = active*(1.0-progress)*(1.0-progress);
}
void fragment() {
    ALBEDO = tint.rgb;
    EMISSION = tint.rgb*2.2;
    ALPHA = fade*0.42;
}
