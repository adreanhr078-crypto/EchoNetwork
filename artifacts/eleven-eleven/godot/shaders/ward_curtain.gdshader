shader_type spatial;
render_mode cull_disabled,diffuse_burley,specular_schlick_ggx;
uniform float elapsed=0.0;
uniform float echo_wake=0.0;
varying vec2 fabric_uv;
void vertex(){
 fabric_uv=UV;
 float free_end=pow(1.0-clamp(VERTEX.y/1.75,0.0,1.0),1.7);
 VERTEX.z+=free_end*(sin(elapsed*.71+UV.x*4.0)*.012+sin(elapsed*2.1+UV.y*5.0)*echo_wake*.045);
}
void fragment(){
 vec2 weave_uv=fabric_uv*vec2(120.0,500.0);
 float filter_amount=1.0-clamp(max(fwidth(weave_uv.x),fwidth(weave_uv.y)),0.0,1.0);
 float weave=sin(weave_uv.x*6.283)*sin(weave_uv.y*6.283)*filter_amount;
 float hem=1.0-smoothstep(.006,.012,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));
 ALBEDO=vec3(.20,.25,.19)*(1.0+weave*.055-hem*.12);
 NORMAL_MAP=vec3(.5+weave*.018,.5,1.0);ROUGHNESS=.9;SPECULAR=.23;
}
