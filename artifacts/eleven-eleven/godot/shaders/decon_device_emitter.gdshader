shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float elapsed=0.0;
uniform float motion=1.0;
uniform float cleared=0.0;
uniform int device_role=0;
void fragment(){
	vec3 color=vec3(.48,.13,.82);
	float strength=.68;
	float pulse=.88+sin(elapsed*2.0)*.12*motion;
	if(device_role==1){color=vec3(.94,.70,.40);strength=1.15;pulse=1.0;}
	if(device_role==2){color=mix(vec3(.72,.025,.045),vec3(.12,.65,.36),cleared);strength=.75;pulse=1.0;}
	ALBEDO=color*.24;
	EMISSION=color*strength*pulse;
	METALLIC=.10;
	ROUGHNESS=.38;
}
