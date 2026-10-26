shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float local_time = 0.0;
uniform float intensity = 0.0;
uniform bool reduced_motion = false;
uniform float root_pulse = 0.0;
varying float camera_distance;
void vertex() { camera_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz); }
void fragment() {
	float t = reduced_motion ? 0.0 : local_time;
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float thread = pow(0.5 + 0.5 * sin(UV.x * 37.7 + UV.y * 12.0 - t * 2.0), 9.0);
	float pulse = reduced_motion ? 0.0 : root_pulse;
	vec3 violet = mix(vec3(0.22, 0.025, 0.55), vec3(0.64, 0.16, 1.0), thread);
	// Unshaded shells carry their visible radiance in ALBEDO as well;
	// Compatibility does not display an emission-only luminous surface.
	ALBEDO = violet * (0.9 + thread * 0.5 + pulse * 0.3) * intensity;
	EMISSION = violet * (1.15 + thread * 1.35 + pulse * 0.5) * intensity;
	ALPHA = clamp((rim * 0.34 + thread * 0.22 + pulse * rim * 0.08) * intensity, 0.0, 0.48) * smoothstep(0.18, 0.5, camera_distance);
}
