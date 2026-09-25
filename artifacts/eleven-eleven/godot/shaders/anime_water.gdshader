shader_type spatial;
render_mode cull_back, depth_draw_always;

// ── 11.11 Stylized Anime Water & Ocean Shader (Genshin Impact Benchmark) ───────
// Features: Dual Gerstner waves, wave crest foam caps, Beer-Lambert depth absorption,
// dynamic shoreline foam, submerged procedural caustics, Fresnel sky sheen,
// stepped anime specular sparkles, and Forward+ Screen-Space Reflection (SSR) compatibility.

group_uniforms WaterColors;
uniform vec4 shallow_color : source_color = vec4(0.06, 0.76, 0.88, 0.85); // Vibrant turquoise
uniform vec4 deep_color : source_color = vec4(0.015, 0.06, 0.22, 0.98);   // Deep abyssal indigo
uniform vec4 sky_reflection_color : source_color = vec4(0.38, 0.68, 0.96, 1.0);
uniform float depth_distance : hint_range(0.5, 30.0) = 7.5;

group_uniforms GerstnerWaves;
uniform vec2 wave_dir_1 = vec2(0.8, 0.6);
uniform vec2 wave_dir_2 = vec2(-0.4, 0.9);
uniform float wave_amplitude_1 : hint_range(0.0, 2.0) = 0.28;
uniform float wave_amplitude_2 : hint_range(0.0, 2.0) = 0.16;
uniform float wave_frequency_1 : hint_range(0.01, 1.0) = 0.18;
uniform float wave_frequency_2 : hint_range(0.01, 1.0) = 0.32;
uniform float wave_speed_1 : hint_range(0.1, 4.0) = 1.1;
uniform float wave_speed_2 : hint_range(0.1, 4.0) = 1.6;
uniform float wave_steepness : hint_range(0.0, 1.0) = 0.45;

group_uniforms ShorelineFoam;
uniform vec4 foam_color : source_color = vec4(0.94, 0.98, 1.0, 1.0);
uniform float foam_depth : hint_range(0.05, 3.0) = 0.70;
uniform float foam_scale : hint_range(1.0, 50.0) = 18.0;
uniform float foam_speed : hint_range(0.1, 5.0) = 1.2;
uniform float crest_foam_threshold : hint_range(0.0, 1.0) = 0.60;

group_uniforms SurfaceLighting;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float metallic : hint_range(0.0, 1.0) = 0.15;
uniform float fresnel_power : hint_range(1.0, 8.0) = 3.5;
uniform float specular_size : hint_range(0.01, 1.0) = 0.72;
uniform float specular_smoothness : hint_range(0.001, 0.2) = 0.04;
uniform float specular_shininess : hint_range(8.0, 256.0) = 96.0;

group_uniforms UnderwaterOptics;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.018;
uniform float caustic_intensity : hint_range(0.0, 2.0) = 0.45;

varying float v_wave_height;
varying vec3 v_world_pos;

// Procedural pseudo-noise for organic shoreline foam edge
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	vec2 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	
	vec2 d1 = normalize(wave_dir_1);
	vec2 d2 = normalize(wave_dir_2);
	
	float phase_1 = dot(d1, world_pos) * wave_frequency_1 + t * wave_speed_1;
	float phase_2 = dot(d2, world_pos) * wave_frequency_2 + t * wave_speed_2;
	
	// Gerstner wave displacement (peaks sharpen, troughs flatten)
	float h1 = sin(phase_1);
	float h2 = sin(phase_2);
	
	float disp_y = h1 * wave_amplitude_1 + h2 * wave_amplitude_2;
	float disp_x = (d1.x * cos(phase_1) * wave_amplitude_1 + d2.x * cos(phase_2) * wave_amplitude_2) * wave_steepness;
	float disp_z = (d1.y * cos(phase_1) * wave_amplitude_1 + d2.y * cos(phase_2) * wave_amplitude_2) * wave_steepness;
	
	VERTEX.x += disp_x;
	VERTEX.y += disp_y;
	VERTEX.z += disp_z;
	v_wave_height = disp_y;
	
	// Analytical Normal approximation from Gerstner slopes
	float wa1 = wave_frequency_1 * wave_amplitude_1;
	float wa2 = wave_frequency_2 * wave_amplitude_2;
	
	float dH_dx = d1.x * wa1 * cos(phase_1) + d2.x * wa2 * cos(phase_2);
	float dH_dz = d1.y * wa1 * cos(phase_1) + d2.y * wa2 * cos(phase_2);
	
	vec3 wave_normal = normalize(vec3(-dH_dx, 1.0, -dH_dz));
	NORMAL = wave_normal;
}

void fragment() {
	// Screen-space Depth & Linearization
	float depth_raw = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 up_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	float scene_depth = -up_pos.z / up_pos.w;
	float surface_depth = -VERTEX.z;
	float depth_diff = max(0.0, scene_depth - surface_depth);
	
	// Beer-Lambert Exponential Depth Absorption (Genshin Standard)
	float depth_factor = 1.0 - exp(-depth_diff / depth_distance);
	vec4 water_col = mix(shallow_color, deep_color, depth_factor);
	
	// Refraction Distortion
	vec2 refract_offset = NORMAL.xz * refraction_strength;
	vec3 scene_color = texture(screen_texture, SCREEN_UV + refract_offset).rgb;
	
	// Submerged Procedural Caustics
	vec2 caustic_uv = v_world_pos.xz * 0.75 + vec2(TIME * 0.22, TIME * 0.14);
	float c1 = sin(caustic_uv.x * 5.0 + sin(caustic_uv.y * 3.5 + TIME * 1.4));
	float c2 = cos(caustic_uv.y * 5.0 + cos(caustic_uv.x * 3.5 + TIME * 1.1));
	float caustic_val = pow(clamp(c1 + c2, 0.0, 2.0) * 0.5, 3.0) * (1.0 - depth_factor) * caustic_intensity;
	scene_color += vec3(caustic_val * 0.7, caustic_val * 0.9, caustic_val);
	
	// Shoreline & Contact Foam
	float foam_noise = noise(UV * foam_scale + vec2(TIME * foam_speed, TIME * foam_speed * 0.7));
	float foam_threshold = foam_depth * (0.6 + 0.4 * foam_noise);
	float shore_foam = 1.0 - smoothstep(0.0, foam_threshold, depth_diff);
	shore_foam = step(0.35, shore_foam * (foam_noise * 0.6 + 0.4));
	
	// Wave Crest Foam (peaks of Gerstner waves produce rolling anime foam caps)
	float max_amp = wave_amplitude_1 + wave_amplitude_2;
	float crest_thresh = max_amp * crest_foam_threshold;
	float crest_foam = smoothstep(crest_thresh, max_amp * 0.95, v_wave_height) * step(0.2, foam_noise);
	
	float combined_foam = clamp(shore_foam + crest_foam, 0.0, 1.0);
	
	// Fresnel Sky Reflection
	float NdotV = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - NdotV, fresnel_power);
	
	// Combine Surface Color
	vec3 final_color = mix(scene_color, water_col.rgb, water_col.a);
	final_color = mix(final_color, sky_reflection_color.rgb, fresnel * 0.65);
	final_color = mix(final_color, foam_color.rgb, combined_foam * foam_color.a);
	
	ALBEDO = final_color;
	ROUGHNESS = mix(roughness, 0.45, combined_foam);
	METALLIC = metallic;
	SPECULAR = 0.8;
}

void light() {
	// Forward+ Anime Stepped Specular Sparkles (Sun Glints)
	vec3 half_vector = normalize(VIEW + LIGHT);
	float NdotH = max(dot(NORMAL, half_vector), 0.0);
	float spec_term = pow(NdotH, specular_shininess) * ATTENUATION;
	float spec_band = smoothstep(specular_size - specular_smoothness, specular_size + specular_smoothness, spec_term);
	
	vec3 sun_glint = LIGHT_COLOR * spec_band * 2.8;
	
	// Diffuse lighting on waves
	float NdotL = max(dot(NORMAL, LIGHT), 0.0);
	vec3 wave_diffuse = ALBEDO * LIGHT_COLOR * (NdotL * 0.4 + 0.6);
	
	DIFFUSE_LIGHT += wave_diffuse;
	SPECULAR_LIGHT += sun_glint;
}
