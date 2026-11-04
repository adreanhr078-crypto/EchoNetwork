shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
varying vec2 room_p;
void vertex(){room_p=VERTEX.xz+vec2(0.0,-18.0);}
void fragment(){
 vec2 q=room_p/vec2(4.0,6.0);
 vec2 edge=.5-abs(fract(q)-.5);
 float aa=max(max(fwidth(q.x),fwidth(q.y)),.0001);
 float joint=1.0-smoothstep(.0018,.0018+aa,min(edge.x,edge.y));
 float service=1.0-smoothstep(.46,.53,abs(abs(room_p.x)-6.44));
 float slats=.5+.5*cos(room_p.y*54.0);
 vec3 plate=mix(vec3(.10,.115,.13),vec3(.042,.052,.063)*( .82+slats*.14),service);
 ALBEDO=mix(plate,vec3(.024,.03,.04),joint*.8);
 METALLIC=mix(.22,.5,service);ROUGHNESS=mix(.73,.63,service);SPECULAR=.5;
}
