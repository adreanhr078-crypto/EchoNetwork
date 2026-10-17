shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float motion_time = 0.0;
uniform float direction = 1.0;
uniform float phase_offset = 0.0;
void fragment() {
	float arc = fract(UV.x * 5.0 - motion_time * direction * 0.08 + phase_offset);
	float flow = smoothstep(0.08, 0.20, arc) * (1.0 - smoothstep(0.55, 0.95, arc));
	ALBEDO = mix(vec3(0.08,0.32,0.42),vec3(0.40,0.88,0.98),0.25+flow*0.75)*1.25;
}
