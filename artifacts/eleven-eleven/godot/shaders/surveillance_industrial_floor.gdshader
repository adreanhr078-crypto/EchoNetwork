shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform sampler2D grain:repeat_enable,filter_linear_mipmap;
varying vec3 room_pos;
// The native campaign places this room at a nonzero world origin. The floor
// body is centered at localZ=-18;service channels must follow the room.
void vertex(){room_pos=VERTEX+vec3(0.0,0.0,-18.0);}
void fragment(){
 vec2 p=room_pos.xz;
 vec2 q=p*.5;
 vec2 edge=.5-abs(fract(q)-.5);
 vec2 aa=max(fwidth(q),vec2(.0001));
 float seam=1.0-smoothstep(.0015,.0015+max(aa.x,aa.y)*.75,min(edge.x,edge.y));
 float channel=1.0-smoothstep(.13,.16,min(abs(abs(p.x)-2.8),abs(abs(p.x)-12.6)));
 float cross_lane=1.0-smoothstep(.10,.14,min(min(abs(p.y+4.0),abs(p.y+10.0)),min(abs(p.y+24.0),abs(p.y+32.0))));
 float grate=max(channel,cross_lane);
 float slats=.5+.5*cos((p.x+p.y)*62.0);
 float wear=texture(grain,p*.28).r;
 ALBEDO=mix(vec3(.22,.215,.20)*( .92+wear*.12),vec3(.033,.043,.052)*( .76+slats*.22),max(seam*.65,grate));
 ROUGHNESS=mix(.38+wear*.12,.61,grate);METALLIC=mix(.08,.55,grate);SPECULAR=.5;
}
