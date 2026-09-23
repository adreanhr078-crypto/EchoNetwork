shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

// ── 11.11 Monster Digital Dissolve Burn Shader ──────
uniform vec4 albedo_color : source_color = vec4(0.85, 0.85, 0.9, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.3;
uniform float metallic : hint_range(0.0, 1.0) = 0.8;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 burn_color : source_color = vec4(1.0, 0.15, 0.25, 1.0);
uniform float burn_width : hint_range(0.01, 0.2) = 0.08;

// Procedural 3D noise approximation
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	ALBEDO = albedo_color.rgb * tex_color.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;

	if (dissolve_amount > 0.001) {
		float n = noise(UV * 24.0);
		float adjusted_dissolve = dissolve_amount * 1.1;
		if (n < adjusted_dissolve) {
			discard;
		}
		
		// Glowing burning dissolve edge
		if (n < adjusted_dissolve + burn_width) {
			float burn_factor = 1.0 - ((n - adjusted_dissolve) / burn_width);
			EMISSION = burn_color.rgb * (burn_factor * 8.0);
		}
	}
}
