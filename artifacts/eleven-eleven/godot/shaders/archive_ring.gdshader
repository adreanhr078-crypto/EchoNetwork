shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform float motion_time = 0.0;
uniform float direction = 1.0;
uniform vec4 ring_color : source_color = vec4(0.78,0.6,0.3,0.45);
void fragment() {
    float phase = fract(UV.x-motion_time*0.055*direction);
    float arc = smoothstep(0.0,0.09,phase)*(1.0-smoothstep(0.32,0.55,phase));
    ALBEDO = ring_color.rgb;
    ALPHA = ring_color.a*(0.16+arc*0.65);
}
