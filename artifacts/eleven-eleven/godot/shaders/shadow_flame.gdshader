shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 dark_core_color : source_color = vec4(0.01, 0.015, 0.025, 1.0);
uniform vec4 flame_rim_color : source_color = vec4(0.0, 0.85, 1.0, 1.0);
uniform vec4 shadow_purple_color : source_color = vec4(0.18, 0.02, 0.35, 1.0);
uniform float flame_speed : hint_range(0.5, 6.0) = 2.8;
uniform float flame_intensity : hint_range(0.5, 4.0) = 2.2;
uniform float rim_sharpness : hint_range(0.5, 8.0) = 3.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// Slight subtle pulsing displacement along flame flow
	vec2 n_uv = UV * 4.0 + vec2(0.0, -TIME * flame_speed * 0.4);
	float disp = (noise(n_uv) - 0.5) * 0.025;
	VERTEX += NORMAL * disp;
}

void fragment() {
	vec2 uv_flame = UV * vec2(3.0, 6.0) + vec2(0.0, -TIME * flame_speed);
	float n1 = noise(uv_flame);
	float n2 = noise(uv_flame * 2.1 + vec2(TIME * 0.5, 0.0));
	float combined_noise = (n1 * 0.6 + n2 * 0.4);

	// Fresnel edge calculation
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_sharpness);

	// Blend dark core with shadow purple and cyan rim
	vec3 base_color = mix(dark_core_color.rgb, shadow_purple_color.rgb, combined_noise * 0.5);
	vec3 emissive = flame_rim_color.rgb * fresnel * flame_intensity + shadow_purple_color.rgb * combined_noise * 0.8;

	ALBEDO = base_color;
	EMISSION = emissive;
	METALLIC = 0.9;
	ROUGHNESS = 0.2;
	ALPHA = 1.0;
}
