shader_type sky;

// ── 11.11 Stylized Anime Sky Dome Shader (Genshin Impact Standard) ─────────────
// Multi-band zenith-to-horizon twilight gradient, animated anime cloud strata with rim light,
// twinkling celestial cyber-stars, and stylized glowing sun/moon celestial disc.

group_uniforms SkyColors;
uniform vec4 zenith_color : source_color = vec4(0.04, 0.06, 0.18, 1.0);        // Deep midnight indigo
uniform vec4 horizon_color : source_color = vec4(0.14, 0.32, 0.58, 1.0);      // Coastal twilight cyan/blue
uniform vec4 horizon_glow_color : source_color = vec4(0.32, 0.48, 0.72, 1.0); // Warm twilight horizon band
uniform vec4 ground_color : source_color = vec4(0.015, 0.02, 0.04, 1.0);      // Shadow ground
uniform float horizon_blur : hint_range(0.05, 1.5) = 0.45;

group_uniforms CelestialElements;
uniform vec3 sun_direction = vec3(0.4, 0.6, -0.6);
uniform vec4 sun_disk_color : source_color = vec4(1.0, 0.96, 0.82, 1.0);
uniform float sun_disk_size : hint_range(0.001, 0.1) = 0.025;
uniform float sun_halo_size : hint_range(0.01, 0.5) = 0.15;
uniform float stars_intensity : hint_range(0.0, 5.0) = 2.2;

group_uniforms AnimeClouds;
uniform vec4 cloud_color : source_color = vec4(0.22, 0.36, 0.65, 0.65);
uniform vec4 cloud_rim_color : source_color = vec4(0.42, 0.60, 0.88, 0.85);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.40;
uniform float cloud_speed : hint_range(0.001, 0.1) = 0.014;

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

void sky() {
	float y = EYEDIR.y;
	
	// Multi-band Anime Gradient
	vec3 col;
	if (y > 0.0) {
		float h = smoothstep(0.0, horizon_blur, y);
		float glow_band = smoothstep(0.0, 0.22, y) * (1.0 - smoothstep(0.18, 0.55, y));
		col = mix(horizon_color.rgb, zenith_color.rgb, pow(h, 0.75));
		col = mix(col, horizon_glow_color.rgb, glow_band * 0.45);
	} else {
		float g = smoothstep(0.0, -horizon_blur, y);
		col = mix(horizon_color.rgb, ground_color.rgb, g);
	}
	
	// Celestial Cyber-Stars in upper sky with twinkle
	if (y > 0.12) {
		vec2 star_uv = EYEDIR.xz / (y + 0.1) * 48.0;
		float star_noise = hash(floor(star_uv));
		if (star_noise > 0.982) {
			float twinkle = sin(TIME * 2.8 + star_noise * 25.0) * 0.35 + 0.65;
			col += vec3(0.85, 0.95, 1.0) * twinkle * stars_intensity * (y - 0.12);
		}
	}
	
	// Stylized Anime Cloud Strata with illuminated rims
	if (y > 0.02) {
		vec2 cloud_uv = EYEDIR.xz / (y + 0.15) * 2.4 + vec2(TIME * cloud_speed, 0.0);
		float c_noise = noise(cloud_uv * 3.0) * 0.6 + noise(cloud_uv * 7.0) * 0.4;
		float cloud_factor = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.16, c_noise);
		float rim_factor = smoothstep(1.0 - cloud_coverage + 0.12, 1.0 - cloud_coverage + 0.18, c_noise);
		
		vec3 c_composite = mix(cloud_color.rgb, cloud_rim_color.rgb, rim_factor);
		col = mix(col, c_composite, cloud_factor * cloud_color.a * min(1.0, y * 3.5));
	}
	
	// Stylized Sun/Moon Disc & Outer Corona Halo
	vec3 sun_dir = normalize(sun_direction);
	float sun_dist = distance(EYEDIR, sun_dir);
	if (sun_dist < sun_halo_size) {
		float halo = 1.0 - smoothstep(sun_disk_size, sun_halo_size, sun_dist);
		col += sun_disk_color.rgb * halo * 0.65;
	}
	if (sun_dist < sun_disk_size) {
		float sun_alpha = smoothstep(sun_disk_size, sun_disk_size * 0.35, sun_dist);
		col = mix(col, sun_disk_color.rgb * 3.5, sun_alpha);
	}
	
	COLOR = col;
}
