shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

// ── 11.11 Anime Cel-Shading Shader (Genshin / NieR Style) ──────
group_uniforms BaseProperties;
uniform vec4 albedo_color : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.35;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;

group_uniforms CelShading;
uniform vec4 shadow_color : source_color = vec4(0.35, 0.38, 0.45, 1.0);
uniform float cel_split_1 : hint_range(0.0, 1.0) = 0.45;
uniform float cel_split_2 : hint_range(0.0, 1.0) = 0.15;
uniform float cel_smoothness : hint_range(0.001, 0.2) = 0.04;

group_uniforms RimLighting;
uniform vec4 rim_color : source_color = vec4(0.0, 0.94, 1.0, 1.0); // Signal Cyan
uniform float rim_power : hint_range(1.0, 8.0) = 3.2;
uniform float rim_intensity : hint_range(0.0, 3.0) = 0.85;

group_uniforms Emissive;
uniform vec4 emissive_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emissive_intensity : hint_range(0.0, 10.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	ALBEDO = albedo_color.rgb * tex_color.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	
	// Rim lighting calculation
	float fresnel = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(fresnel, rim_power) * rim_intensity;
	
	EMISSION = (emissive_color.rgb * emissive_intensity) + (rim_color.rgb * rim);
}

void light() {
	// N.L Cel Stepping
	float n_dot_l = dot(NORMAL, LIGHT);
	float light_step_1 = smoothstep(cel_split_1 - cel_smoothness, cel_split_1 + cel_smoothness, n_dot_l);
	float light_step_2 = smoothstep(cel_split_2 - cel_smoothness, cel_split_2 + cel_smoothness, n_dot_l);
	
	vec3 ramp_color = mix(shadow_color.rgb, vec3(1.0), light_step_1);
	ramp_color = mix(shadow_color.rgb * 0.7, ramp_color, light_step_2);
	
	// Attenuation & Light color
	vec3 diffuse_light = ramp_color * LIGHT_COLOR * ATTENUATION;
	DIFFUSE_LIGHT += diffuse_light * ALBEDO;
}
