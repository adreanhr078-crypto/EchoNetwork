shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float motion_time = 0.0;
uniform float direction = 1.0;
uniform float phase_offset = 0.0;
void fragment() {
	float arc = fract(UV.x * 5.0 - motion_time * direction * 0.08 + phase_offset);
	float flow = smoothstep(0.08, 0.20, arc) * (1.0 - smoothstep(0.55, 0.95, arc));
	// Keep the original direction/phase/clock. A lit tube cross-section reads
	// as contained plasma instead of a clipped,flat white outline under ACES.
	float rim = pow(1.0-clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),1.6);
	float tube = .48+.30*max(NORMAL.y,0.0)+.22*rim;
	ALBEDO = mix(vec3(.018,.15,.21),vec3(.11,.57,.68),.25+flow*.75)*tube;
}
