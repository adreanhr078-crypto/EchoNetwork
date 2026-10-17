shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled,shadows_disabled;
uniform float local_time = 0.0;
void fragment() {
    float core = pow(abs(dot(normalize(NORMAL),normalize(VIEW))),3.0);
    float packet = pow(max(0.0,1.0-abs(fract(UV.y*2.0-local_time*0.12)-0.5)*2.0),12.0);
    ALBEDO = mix(vec3(0.65,0.035,0.025),vec3(1.0,0.42,0.21),core);
    ALPHA = 0.1+core*0.48+packet*0.12;
}
