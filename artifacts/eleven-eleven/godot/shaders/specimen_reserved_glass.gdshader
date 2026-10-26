shader_type spatial;
render_mode blend_mix,depth_prepass_alpha,cull_back;
// Sparse physical edge reflection makes empty glass readable without
// suggesting the reserved vessel contains extra fluid or a specimen.
void fragment(){
    float edge=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),3.0);
    ALBEDO=vec3(.12,.21,.25);
    ALPHA=.045+edge*.20;
    ROUGHNESS=.16;
    SPECULAR=.65;
    EMISSION=vec3(.012,.025,.030)*edge;
}
