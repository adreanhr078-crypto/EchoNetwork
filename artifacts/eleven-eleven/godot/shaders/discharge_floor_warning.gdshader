shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 phase_color : source_color = vec4(0.22,0.29,0.32,0.4);
void fragment() {
	vec2 edge=min(UV,1.0-UV);
	float border=1.0-step(0.035,min(edge.x,edge.y));
	float stripe=step(0.70,fract((UV.x+UV.y)*13.0));
	ALBEDO=phase_color.rgb;
	ALPHA=phase_color.a*max(border,stripe*0.22);
}
