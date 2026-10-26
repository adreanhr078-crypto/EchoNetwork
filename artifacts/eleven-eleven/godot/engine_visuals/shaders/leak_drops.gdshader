shader_type spatial;
render_mode unshaded, cull_disabled;
global uniform float hyper_visual_time;
uniform float height=2.5;
void vertex(){ VERTEX.y-=pow(fract(hyper_visual_time*0.6+INSTANCE_CUSTOM.r),1.7)*height; }
void fragment(){ ALBEDO=vec3(0.28,0.5,0.59); }
