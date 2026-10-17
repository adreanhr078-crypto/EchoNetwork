shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled,shadows_disabled;
uniform float age = 10.0;
void fragment() {
    float envelope = smoothstep(0.0,0.15,age)*(1.0-smoothstep(0.45,1.3,age));
    float rim = 1.0-smoothstep(0.008,0.035,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));
    float streak = 1.0-smoothstep(0.008,0.035,abs(UV.x+UV.y*0.22-age*0.9));
    ALBEDO = vec3(0.46,0.3,0.8);
    ALPHA = envelope*(rim*0.48+streak*0.13);
}
