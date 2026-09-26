shader_type spatial;
render_mode cull_back;

// ── 11.11 World-Class Anime Cel Shader (Genshin Impact / ZZZ Standard) ─────────
// Features: 2-band stepped cel shading, warm peach/rose Subsurface Scattering (SSS)
// terminator line, Kajiya-Kay anisotropic hair specular highlight ("Angel Ring"),
// dynamic backlight-boosted anime rim glow, and Forward+ light integration.

group_uniforms BaseProperties;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform bool use_normal_texture = false;
uniform float normal_depth : hint_range(0.0, 2.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.35;
uniform float metallic : hint_range(0.0, 1.0) = 0.05;

group_uniforms CelShading;
uniform vec4 shadow_color : source_color = vec4(0.38, 0.42, 0.56, 1.0); // Anime cool blue shadow
uniform float cel_split_1 : hint_range(0.0, 1.0) = 0.48;
uniform float cel_split_2 : hint_range(0.0, 1.0) = 0.22;
uniform float cel_smoothness : hint_range(0.001, 0.15) = 0.035;

group_uniforms SubsurfaceScattering;
uniform bool use_sss = true;
uniform vec4 sss_color : source_color = vec4(0.96, 0.45, 0.40, 1.0); // Warm peach/rose terminator tint
uniform float sss_width : hint_range(0.01, 0.3) = 0.10;
uniform float sss_intensity : hint_range(0.0, 2.0) = 0.70;

group_uniforms StylizedSpecular;
uniform vec4 specular_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float specular_size : hint_range(0.01, 1.0) = 0.65;
uniform float specular_smoothness : hint_range(0.001, 0.2) = 0.03;
uniform float specular_shininess : hint_range(8.0, 128.0) = 48.0;

group_uniforms AnisotropicHair;
uniform bool is_hair = false;
uniform vec4 hair_specular_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform float hair_specular_shift : hint_range(-0.5, 0.5) = 0.04;
uniform float hair_specular_power : hint_range(8.0, 128.0) = 42.0;
uniform float hair_specular_width : hint_range(0.01, 0.4) = 0.08;

group_uniforms FaceShading;
uniform bool is_face = false;

group_uniforms RimLighting;
uniform vec4 rim_color : source_color = vec4(0.0, 0.94, 1.0, 1.0); // Signal Cyan
uniform float rim_power : hint_range(1.0, 8.0) = 3.6;
uniform float rim_intensity : hint_range(0.0, 3.0) = 0.75;
uniform float rim_smoothness : hint_range(0.01, 0.5) = 0.1;

group_uniforms Emissive;
uniform vec4 emissive_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emissive_intensity : hint_range(0.0, 10.0) = 0.0;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo_color.rgb * tex.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	
	if (use_normal_texture) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	
	// Stylized Anime Rim Light with View Fresnel
	float NdotV = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = 1.0 - NdotV;
	float rim = smoothstep(1.0 - (1.0 / rim_power), 1.0 - (1.0 / rim_power) + rim_smoothness, fresnel);
	
	EMISSION = (emissive_color.rgb * emissive_intensity) + (rim_color.rgb * rim * rim_intensity);
}

void light() {
	// Half-Lambert term for flattering anime illumination
	float NdotL = dot(NORMAL, LIGHT);
	float half_lambert = NdotL * 0.5 + 0.5;
	
	// Combine half-lambert with light attenuation/shadow map
	float shadow_term = clamp(half_lambert * ATTENUATION, 0.0, 1.0);
	
	// 2-Band Stepped Cel Diffuse
	float s1 = is_face ? (cel_split_1 * 0.45) : cel_split_1;
	float s2 = is_face ? (cel_split_2 * 0.35) : cel_split_2;
	float band_1 = smoothstep(s1 - cel_smoothness, s1 + cel_smoothness, shadow_term);
	float band_2 = smoothstep(s2 - cel_smoothness, s2 + cel_smoothness, shadow_term);
	
	vec3 shade_tier_2 = shadow_color.rgb * (is_face ? 0.88 : 0.72);
	vec3 shade_tier_1 = shadow_color.rgb;
	vec3 lit_color = vec3(1.0);
	
	vec3 cel_tone = mix(shade_tier_2, shade_tier_1, band_2);
	cel_tone = mix(cel_tone, lit_color, band_1);
	
	vec3 diffuse_result = ALBEDO * LIGHT_COLOR * cel_tone;
	
	// Subsurface Scattering (Warm Peach Terminator Line Tint)
	if (use_sss) {
		float terminator_dist = abs(shadow_term - cel_split_1);
		float sss_factor = smoothstep(sss_width, 0.0, terminator_dist);
		vec3 sss_rim = sss_color.rgb * sss_factor * sss_intensity * LIGHT_COLOR;
		diffuse_result += sss_rim * ALBEDO;
	}
	
	// Stylized Anime Stepped Blinn-Phong Specular
	vec3 half_vector = normalize(VIEW + LIGHT);
	float NdotH = max(dot(NORMAL, half_vector), 0.0);
	float spec_term = pow(NdotH, specular_shininess) * ATTENUATION;
	float spec_band = smoothstep(specular_size - specular_smoothness, specular_size + specular_smoothness, spec_term);
	vec3 specular_result = specular_color.rgb * LIGHT_COLOR * spec_band * (1.0 - roughness);
	
	// Kajiya-Kay Anisotropic Hair Specular Highlight ("Angel Ring")
	if (is_hair) {
		vec3 bitangent = normalize(cross(NORMAL, vec3(0.0, 1.0, 0.0)));
		vec3 hair_tangent = normalize(cross(NORMAL, bitangent));
		vec3 shifted_tangent = normalize(hair_tangent + NORMAL * hair_specular_shift);
		float TdotH = dot(shifted_tangent, half_vector);
		float sinTH = sqrt(max(0.0, 1.0 - TdotH * TdotH));
		float hair_spec = pow(sinTH, hair_specular_power);
		float hair_band = smoothstep(0.5 - hair_specular_width, 0.5 + hair_specular_width, hair_spec);
		specular_result += hair_specular_color.rgb * LIGHT_COLOR * hair_band * 2.0 * ATTENUATION;
	}
	
	DIFFUSE_LIGHT += diffuse_result;
	SPECULAR_LIGHT += specular_result;
}
