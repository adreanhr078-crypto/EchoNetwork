shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float presentation_time = 0.0;
uniform float motion_factor : hint_range(0.0, 1.0) = 1.0;
uniform float phase = 0.0;
uniform bool pressure_indicator = false;
uniform float pressure : hint_range(0.0, 1.0) = 0.65;
uniform vec4 steam_color : source_color = vec4(0.43, 0.63, 0.62, 1.0);
uniform vec4 amber_color : source_color = vec4(0.83, 0.35, 0.065, 1.0);

float hash_wind(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float wind_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_wind(i), hash_wind(i + vec2(1.0, 0.0)), f.x),
		mix(hash_wind(i + vec2(0.0, 1.0)), hash_wind(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	float t = presentation_time;
	if (pressure_indicator) {
		vec2 p = UV * 2.0 - 1.0;
		float radius = length(p);
		float ring = smoothstep(0.66, 0.72, radius) * (1.0 - smoothstep(0.83, 0.90, radius));
		float angle = atan(p.y, p.x) + 3.14159265;
		float ticks = step(0.22, fract(angle * 8.0 / 6.2831853));
		float gauge = 1.0 - smoothstep(pressure * 6.2831853 - 0.08, pressure * 6.2831853 + 0.08, angle);
		float pulse = 1.0 + sin(t * 1.5) * 0.035 * motion_factor;
		ALBEDO = amber_color.rgb;
		EMISSION = amber_color.rgb * 0.24;
		ALPHA = ring * ticks * mix(0.18, 0.75, gauge) * pulse;
	} else {
		// Crossed soft sheets: a readable physical plume without particle clocks.
		float height = 1.0 - UV.y;
		float center = 0.5 + sin(height * 5.0 + t * 0.65 + phase) * 0.065 * height;
		float width = mix(0.10, 0.43, height);
		float side = 1.0 - smoothstep(width * 0.25, width, abs(UV.x - center));
		float vertical = smoothstep(0.0, 0.08, height) * (1.0 - smoothstep(0.55, 1.0, height));
		float cloud = wind_noise(vec2(UV.x * 5.0 + phase, height * 4.0 - t * 0.7));
		float fine = wind_noise(vec2(UV.x * 11.0 - phase, height * 8.0 - t * 1.15));
		float streak = pow(max(0.0, sin(height * 18.0 - t * 4.0 + phase)), 10.0) * 0.10;
		ALBEDO = steam_color.rgb;
		EMISSION = steam_color.rgb * 0.025;
		ALPHA = side * vertical * (0.08 + cloud * 0.11 + fine * 0.035 + streak) * mix(0.3, 1.0, motion_factor);
	}
}
