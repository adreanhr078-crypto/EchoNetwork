shader_type spatial;
render_mode cull_back;

// ── 11.11 Flooded Subterranean Laboratory Floor Shader ────────────────────────
// High-Fidelity NPR/PBR hybrid floor with procedural puddles & Screen-Space Reflections (SSR).
// Features:
// 1. Analytical Procedural FBM Noise Puddle Mask (Zero texture fetches needed).
// 2. Mirror-smooth puddles (ROUGHNESS = 0.02 - 0.04, SPECULAR = 0.95) with animated micro-ripples.
// 3. Dark obsidian slate substrate (ROUGHNESS = 0.45 - 0.55) with tactile micro-grain.
// 4. Physical Wetness Color Darkening on damp perimeter and puddle bed.
// 5. Full Screen-Space Reflections (SSR) Forward+ support & View-Fresnel sheen fallback.

group_uniforms FloorColors;
uniform vec4 floor_color : source_color = vec4(0.035, 0.045, 0.065, 1.0); // Dark Obsidian Slate
uniform vec4 water_tint : source_color = vec4(0.015, 0.28, 0.38, 1.0);     // Subterranean Teal/Cyan tint
uniform vec4 neon_reflection_color : source_color = vec4(0.0, 0.85, 1.0, 1.0); // Signal Cyan
uniform vec4 emergency_red_tint : source_color = vec4(0.95, 0.12, 0.22, 1.0);
uniform float emergency_pulse_speed : hint_range(0.0, 10.0) = 0.0;
uniform float wet_darkening : hint_range(0.2, 0.9) = 0.55;                 // Physical darkening factor when wet

group_uniforms ProceduralPuddles;
uniform float puddle_scale : hint_range(0.02, 1.0) = 0.18;                 // Puddle distribution frequency
uniform float puddle_coverage : hint_range(0.0, 1.0) = 0.52;              // Floor surface area covered in water
uniform float puddle_edge_softness : hint_range(0.01, 0.25) = 0.06;        // Shoreline transition softness
uniform float wet_edge_width : hint_range(0.01, 0.35) = 0.14;             // Damp perimeter width around puddles
uniform float water_depth_tint_mix : hint_range(0.0, 1.0) = 0.40;          // Deep water tint blend amount

group_uniforms SurfaceProperties;
uniform float roughness : hint_range(0.0, 1.0) = 0.50;                     // Base / dry slate roughness (0.45 - 0.55)
uniform float metallic : hint_range(0.0, 1.0) = 0.22;                      // Base / dry floor metallic
uniform float specular : hint_range(0.0, 1.0) = 0.30;                      // Base / dry floor specular
uniform float puddle_roughness : hint_range(0.01, 0.1) = 0.03;             // Mirror-smooth puddle roughness (0.02 - 0.04)
uniform float puddle_specular : hint_range(0.5, 1.0) = 0.95;               // High-clarity specular inside puddles
uniform float puddle_metallic : hint_range(0.0, 0.5) = 0.05;               // Dielectric water surface metallic
uniform float fresnel_power : hint_range(1.0, 8.0) = 4.0;

group_uniforms WaterRipples;
uniform float ripple_speed : hint_range(0.1, 4.0) = 1.2;
uniform float ripple_scale : hint_range(1.0, 60.0) = 24.0;
uniform float ripple_intensity : hint_range(0.0, 1.0) = 0.25;

// --- Procedural FBM Gradient Noise (Zero Texture Fetches) ---
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float gradient_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
	               dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
	           mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
	               dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (int i = 0; i < 4; i++) {
		value += gradient_noise(p * frequency) * amplitude;
		frequency *= 2.02;
		amplitude *= 0.5;
	}
	return value * 0.5 + 0.5;
}

void fragment() {
	// Base procedural coordinates
	vec2 coords = UV * 10.0;
	
	// Evaluate analytical FBM procedural puddle noise
	float noise_val = fbm(coords * puddle_scale);
	
	// Puddle shoreline & damp edge thresholds
	float puddle_thresh = 1.0 - puddle_coverage;
	float puddle_factor = smoothstep(puddle_thresh - puddle_edge_softness, puddle_thresh + puddle_edge_softness, noise_val);
	
	// Damp rim around puddle border where ground is wet before standing water forms
	float wet_thresh = puddle_thresh - wet_edge_width;
	float wet_factor = smoothstep(wet_thresh - puddle_edge_softness, puddle_thresh, noise_val);
	
	// Fine tactile grain for dry obsidian slate
	float dry_grain = gradient_noise(coords * 8.0) * 0.04;
	
	// Water micro-ripples (dual-scrolling waves animated in time)
	vec2 wave_uv1 = coords * ripple_scale * 0.1 + vec2(TIME * ripple_speed * 0.035, TIME * ripple_speed * 0.022);
	vec2 wave_uv2 = coords * (ripple_scale * 0.135) - vec2(TIME * ripple_speed * 0.028, TIME * ripple_speed * 0.042);
	
	float wave1 = sin(wave_uv1.x * 2.6 + wave_uv1.y * 1.9);
	float wave2 = cos(wave_uv2.x * 2.3 - wave_uv2.y * 2.7);
	float wave3 = sin((wave_uv1.x - wave_uv2.y) * 3.2 + TIME * ripple_speed * 0.7);
	
	// Normal perturbation:
	// - Dry floor: subtle slate micro-grain
	// - Puddles: dynamic liquid micro-ripples
	vec3 dry_normal_perturb = vec3(dry_grain, 1.0, dry_grain * 0.8);
	vec3 water_ripple_perturb = vec3(
		(wave1 * 0.55 + wave3 * 0.45) * ripple_intensity * 0.15,
		1.0,
		(wave2 * 0.55 + wave3 * 0.45) * ripple_intensity * 0.15
	);
	
	vec3 local_perturb = mix(dry_normal_perturb, water_ripple_perturb, puddle_factor);
	NORMAL = normalize(mix(NORMAL, NORMAL + vec3(local_perturb.x, 0.0, local_perturb.z), mix(0.3, 1.0, puddle_factor)));
	
	// Physical Wetness Color Darkening:
	// - Dry floor: authored Obsidian Slate
	// - Damp rim: darkened due to reduced microscopic light backscattering
	// - Submerged puddle floor: darkened substrate mixed with subterranean teal water tint
	vec3 dry_floor_col = floor_color.rgb;
	vec3 wet_floor_col = dry_floor_col * wet_darkening;
	vec3 submerged_col = mix(wet_floor_col, water_tint.rgb, water_depth_tint_mix);
	
	vec3 final_albedo = mix(dry_floor_col, wet_floor_col, wet_factor);
	final_albedo = mix(final_albedo, submerged_col, puddle_factor);
	
	// Surface PBR Properties:
	// Dry floor: balanced tactile roughness (0.45 - 0.55), moderate specular (~0.30)
	// Inside puddles: mirror-smooth (0.02 - 0.04), pristine specular (0.95) for crystal-clear SSR
	float dry_rough = (roughness > 0.08) ? roughness : 0.50;
	float dry_spec = specular;
	
	float damp_rough = mix(dry_rough, 0.28, wet_factor);
	ROUGHNESS = mix(damp_rough, puddle_roughness, puddle_factor);
	SPECULAR = mix(mix(dry_spec, 0.65, wet_factor), puddle_specular, puddle_factor);
	METALLIC = mix(metallic, puddle_metallic, puddle_factor);
	ALBEDO = final_albedo;
	
	// View Fresnel term for glistening wet reflection & glancing brilliance
	float NdotV = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - NdotV, fresnel_power);
	
	// Emergency warning strobe pulse (if active)
	vec3 warning_strobe = emergency_red_tint.rgb * (sin(TIME * emergency_pulse_speed) * 0.5 + 0.5);
	vec3 active_neon = mix(neon_reflection_color.rgb, warning_strobe, clamp(emergency_pulse_speed * 0.15, 0.0, 0.85));
	
	// Enhanced glancing reflection glow:
	// Accentuates neon reflections on puddles and wet rims
	EMISSION = active_neon * fresnel * (puddle_factor * 0.40 + wet_factor * 0.06);
}
