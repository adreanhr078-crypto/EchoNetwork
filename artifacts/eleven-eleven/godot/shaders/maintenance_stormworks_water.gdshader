shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Room-owned source time only: this shader intentionally never uses TIME.
uniform float presentation_time = 0.0;
uniform float motion_factor : hint_range(0.0, 1.0) = 1.0;
uniform vec2 water_size = vec2(12.0, 12.0);
uniform vec4 deep_color : source_color = vec4(0.015, 0.105, 0.12, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.055, 0.28, 0.27, 1.0);
uniform vec4 foam_color : source_color = vec4(0.40, 0.66, 0.60, 1.0);
uniform vec4 impact_points[8]; // local x,z; presentation start; physical strength
varying vec2 water_coord;

float hash_water(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float water_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_water(i), hash_water(i + vec2(1.0, 0.0)), f.x),
		mix(hash_water(i + vec2(0.0, 1.0)), hash_water(i + vec2(1.0)), f.x), f.y);
}

float current_height(vec2 p, float t) {
	return sin(p.x * 1.55 + p.y * 0.48 + t * 0.9) * 0.009
		+ sin(p.y * 2.7 - p.x * 0.62 - t * 1.1) * 0.005;
}

void vertex() {
	water_coord = VERTEX.xz;
	VERTEX.y += current_height(VERTEX.xz, presentation_time) * motion_factor;
}

void fragment() {
	vec2 p = water_coord;
	float t = presentation_time;
	float slow = water_noise(p * 0.28 + vec2(t * 0.035, -t * 0.018));
	float detail = water_noise(p * 2.4 + vec2(-t * 0.06, t * 0.035));
	vec2 slope = vec2(
		cos(p.x * 1.55 + p.y * 0.48 + t * 0.9) * 0.12,
		cos(p.y * 2.7 - p.x * 0.62 - t * 1.1) * 0.10);
	float impact_foam = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 event = impact_points[i];
		float age = t - event.z;
		float enabled = step(0.0, age) * (1.0 - step(2.4, age)) * event.w * motion_factor;
		vec2 offset = p - event.xy;
		float distance_from_impact = length(offset);
		float front = distance_from_impact - age * 2.3;
		float envelope = exp(-front * front * 8.0) * exp(-age * 1.2) * enabled;
		slope += offset / max(distance_from_impact, 0.08) * sin(front * 16.0) * envelope * 0.25;
		impact_foam += envelope * (0.5 + 0.5 * cos(front * 14.0));
	}
	float edge_distance = min(water_size.x * 0.5 - abs(p.x), water_size.y * 0.5 - abs(p.y));
	float edge_foam = (1.0 - smoothstep(0.025, 0.22, edge_distance)) * mix(0.2, 0.6, detail);
	float threads = smoothstep(0.78, 0.94, detail) * smoothstep(0.5, 0.82, slow) * 0.13;
	float foam = clamp(edge_foam + threads + impact_foam * 0.48, 0.0, 0.7);
	ALBEDO = mix(mix(deep_color.rgb, shallow_color.rgb, slow * 0.62 + 0.12), foam_color.rgb, foam);
	NORMAL_MAP = normalize(vec3(slope.x, slope.y, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.7;
	ROUGHNESS = mix(0.27, 0.56, foam);
	METALLIC = 0.08;
	SPECULAR = 0.5;
	// Tiny chromatic lift, not a magical emissive pool or a second light owner.
	EMISSION = shallow_color.rgb * 0.018;
}
