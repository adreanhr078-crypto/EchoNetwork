shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 beam_color : source_color = vec4(0.0,0.9,1.0,1.0);
uniform float motion_time = 0.0;
uniform float motion_amount = 1.0;
varying float axial;
void vertex() { axial = clamp(0.5-VERTEX.y/8.0,0.0,1.0); }
void fragment() {
    // Fade grazing edges rather than amplifying them with inverse Fresnel.
    float face_fade = pow(abs(dot(normalize(NORMAL),normalize(VIEW))),0.85);
    float ends = smoothstep(0.04,0.24,axial)*(1.0-smoothstep(0.65,0.98,axial));
    float scan = 0.5+0.5*sin(axial*18.0-motion_time*0.9);
    ALBEDO = beam_color.rgb*1.12;
    ALPHA = (0.22+0.08*scan*motion_amount)*face_fade*ends*smoothstep(0.3,0.9,-VERTEX.z);
}
