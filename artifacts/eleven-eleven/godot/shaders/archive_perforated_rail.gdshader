shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 coating:source_color=vec4(.28,.29,.27,1.0);
uniform vec2 cells=vec2(64.0,4.0);
void fragment(){
	vec2 p=abs(fract(UV*cells)-.5);
	float web=max(step(.465,p.x),step(.465,p.y));
	ALBEDO=coating.rgb;METALLIC=.22;ROUGHNESS=.62;
	ALPHA=web;ALPHA_SCISSOR_THRESHOLD=.5;
}
