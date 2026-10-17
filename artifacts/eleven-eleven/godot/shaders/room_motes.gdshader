shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float motion_time = 0.0;
uniform vec4 mote_color : source_color = vec4(0.52,0.73,0.8,0.25);
uniform bool release_mode = false;
uniform float release_start = 0.0;
varying float age;
void vertex() {
    age = max(0.0,motion_time-release_start);
    float phase = INSTANCE_CUSTOM.x*6.283185;
    vec3 drift = vec3(sin(motion_time*0.23+phase)*0.22,
        sin(motion_time*0.16+phase)*0.3,cos(motion_time*0.19+phase)*0.18);
    if(release_mode) {
        drift = vec3(cos(phase)*age*0.55,age*(0.28+INSTANCE_CUSTOM.y*0.25),sin(phase)*age*0.55);
    }
    vec4 center = MODEL_MATRIX*vec4(drift,1.0);
    float size = length(MODEL_MATRIX[0].xyz);
    MODELVIEW_MATRIX = VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*size,INV_VIEW_MATRIX[1]*size,INV_VIEW_MATRIX[2]*size,center);
}
void fragment() {
    float distance = length(UV-vec2(0.5))*2.0;
    float soft = 1.0-smoothstep(0.12,1.0,distance);
    float envelope = release_mode ? 1.0-smoothstep(0.4,1.6,age) : 1.0;
    ALBEDO = mote_color.rgb;
    ALPHA = soft*soft*mote_color.a*envelope;
}
