shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_disabled;
uniform float elapsed=0.0;
uniform float motion=1.0;
uniform float moisture=1.0;
void fragment(){
	float lane=floor(UV.x*48.0);
	float seed=fract(sin(lane*91.37)*1531.73);
	float travel=fract(UV.y*2.5+elapsed*.045*motion+seed);
	float thread=exp(-pow((fract(UV.x*48.0)-.5)/.12,2.0));
	float drop=thread*(1.0-smoothstep(.0,.10,travel))*step(.65,seed)*moisture;
	float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),3.0);
	ALBEDO=vec3(.20,.40,.44);
	ROUGHNESS=.18;METALLIC=0.0;
	ALPHA=.045+rim*.09+drop*.12;
}
