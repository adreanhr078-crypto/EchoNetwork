shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform float elapsed=0.0;
uniform float motion=1.0;
uniform float detail=1.0;
uniform vec4 ripples[4];
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	vec2 p=UV*2.0-1.0;
	float outline=length(p)+.045*sin(p.x*17.0+p.y*11.0)+.025*sin(p.y*31.0);
	if(outline>.97){discard;}
	vec2 slope=vec2(sin(world_pos.x*8.0+elapsed*1.1),cos(world_pos.z*7.0+elapsed))*.024*motion;
	float crest=0.0;
	for(int i=0;i<4;i++){
		float age=elapsed-ripples[i].z;
		vec2 offset=world_pos.xz-ripples[i].xy;
		float radius=length(offset);
		float live=step(0.0,age)*(1.0-step(1.8,age))*ripples[i].w*motion;
		float ring=exp(-pow((radius-age*.95)*19.0,2.0))*exp(-age*2.2)*live;
		slope+=offset/max(radius,.01)*ring*.28;crest+=ring;
	}
	float drip=fract(elapsed*.46);
	float ring=exp(-pow((length(p*vec2(1.0,1.6))-drip)*23.0,2.0))*(1.0-drip)*motion*detail;
	slope+=p*ring*.06;
	float fresnel=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),4.0);
	ALBEDO=mix(vec3(.055,.073,.082),vec3(.19,.24,.26),fresnel*.65)+(crest+ring)*.024;
	ROUGHNESS=.11+smoothstep(.67,.97,outline)*.30;
	METALLIC=.03;SPECULAR=.78;
	NORMAL_MAP=normalize(vec3(slope.x,slope.y,1.0))*.5+.5;
}
