shader_type spatial;
uniform vec4 linen_color : source_color = vec4(0.79,0.8,0.75,1.0);
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_point.xz*440.0;
 float aa=clamp(1.0-max(fwidth(p.x),fwidth(p.y)),0.0,1.0);
 vec2 threads=sin(p*6.2831853);
 float weave=(threads.x+threads.y)*.5*aa;
 ALBEDO=linen_color.rgb*(1.0+weave*.022);
 ROUGHNESS=.9;METALLIC=0.0;
 NORMAL_MAP=vec3(vec2(.5)+threads*.018*aa,1.0);
}
