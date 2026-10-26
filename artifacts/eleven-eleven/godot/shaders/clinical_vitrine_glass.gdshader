shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

// Quiet clear glass: preserve complete Canon screens behind the surface.
varying vec3 local_point;
void vertex(){ local_point=VERTEX; }
void fragment(){
    float edge=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),3.0);
    float seam=1.0-smoothstep(.001,.004,abs(fract(local_point.y*2.0)-.5));
    ALBEDO=mix(vec3(.08,.20,.23),vec3(.42,.72,.78),edge);
    ROUGHNESS=.09;
    METALLIC=.08;
    SPECULAR=.7;
    ALPHA=.022+edge*.20+seam*.015;
}
