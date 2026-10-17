shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 phase_color : source_color = vec4(0.22,0.29,0.32,0.4);
uniform float motion_time = 0.0;
uniform float motion_amount = 0.0;
uniform int hazard_state = 0;
void fragment() {
	vec2 edge=min(UV,1.0-UV);
	float border=1.0-step(0.035,min(edge.x,edge.y));
	float drift=motion_time*motion_amount*0.45;
	float stripe=step(0.70,fract((UV.x+UV.y)*13.0-drift));
	float arc=1.0-smoothstep(0.012,0.030,abs(UV.y-0.5-sin(UV.x*38.0+drift*2.0)*0.17));
	float energy=hazard_state==2 ? max(stripe*0.32,arc*0.75) : stripe*0.22;
	ALBEDO=phase_color.rgb;
	ALPHA=phase_color.a*max(border,energy);
}
