shader_type spatial;
render_mode cull_back;

// ── 11.11 Flooded Subterranean Laboratory Floor Shader ────────────────────────
// Intel UHD / Compatibility Mode Optimized:
// Produces a dark glistening obsidian floor with shallow water ripples,
// dynamic view-Fresnel sheen, and procedural neon reflections without Forward+ compute.

group_uniforms FloorColors;
uniform vec4 floor_color : source_color = vec4(0.035, 0.045, 0.065, 1.0);
uniform vec4 water_tint : source_color = vec4(0.0, 0.42, 0.58, 1.0);
uniform vec4 neon_reflection_color : source_color = vec4(0.0, 0.85, 1.0, 1.0);
uniform vec4 emergency_red_tint : source_color = vec4(0.95, 0.12, 0.22, 1.0);
uniform float emergency_pulse_speed : hint_range(0.0, 10.0) = 0.0;

group_uniforms SurfaceProperties;
uniform float roughness : hint_range(0.0, 1.0) = 0.06;
uniform float metallic : hint_range(0.0, 1.0) = 0.4;
uniform float specular : hint_range(0.0, 1.0) = 0.9;
uniform float fresnel_power : hint_range(1.0, 8.0) = 3.6;

group_uniforms WaterRipples;
uniform float ripple_speed : hint_range(0.1, 4.0) = 1.2;
uniform float ripple_scale : hint_range(1.0, 60.0) = 22.0;
uniform float ripple_intensity : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	// Dual scrolling wave UV coordinates
	vec2 uv1 = UV * ripple_scale + vec2(TIME * ripple_speed * 0.04, TIME * ripple_speed * 0.025);
	vec2 uv2 = UV * (ripple_scale * 1.35) - vec2(TIME * ripple_speed * 0.03, TIME * ripple_speed * 0.045);
	
	// Fast analytical trigonometric wave ripples (zero texture fetches)
	float wave1 = sin(uv1.x * 2.5 + uv1.y * 1.8);
	float wave2 = cos(uv2.x * 2.1 - uv2.y * 2.4);
	float ripple_height = (wave1 + wave2) * 0.5;
	
	// Perturb normal for water reflection shimmer
	vec3 perturbed_normal = normalize(NORMAL + vec3(wave1 * ripple_intensity * 0.15, 0.0, wave2 * ripple_intensity * 0.15));
	NORMAL = perturbed_normal;
	
	// View Fresnel term for glistening wet reflection
	float NdotV = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - NdotV, fresnel_power);
	
	// Mix base dark metallic floor with water sheet tint
	vec3 base_color = mix(floor_color.rgb, water_tint.rgb, 0.35);
	
	// Emergency warning strobe pulse (if active)
	vec3 warning_strobe = emergency_red_tint.rgb * (sin(TIME * emergency_pulse_speed) * 0.5 + 0.5);
	vec3 final_neon = mix(neon_reflection_color.rgb, warning_strobe, clamp(emergency_pulse_speed * 0.15, 0.0, 0.85));
	
	ALBEDO = base_color;
	METALLIC = metallic;
	ROUGHNESS = roughness + (1.0 - (ripple_height * 0.5 + 0.5)) * 0.04;
	SPECULAR = specular;
	EMISSION = final_neon * fresnel * 0.65;
}
