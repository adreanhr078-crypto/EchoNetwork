shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic_offset : hint_range(0.0, 0.05) = 0.015;
uniform float scanline_density : hint_range(50.0, 800.0) = 320.0;
uniform float time_speed : hint_range(0.5, 8.0) = 3.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	if (glitch_intensity <= 0.001) {
		COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);
	} else {
		vec2 uv = SCREEN_UV;
		float time = TIME * time_speed;

	// Block Glitch Displacement
	float block_y = floor(uv.y * 24.0);
	float glitch_trigger = step(0.75 - glitch_intensity * 0.45, hash(vec2(block_y, floor(time * 8.0))));
	float displacement = (hash(vec2(block_y, floor(time * 12.0))) - 0.5) * 0.08 * glitch_intensity * glitch_trigger;
	uv.x += displacement;

	// Chromatic Aberration with Glitch Multiplier
	float split = chromatic_offset * glitch_intensity;
	float r = texture(SCREEN_TEXTURE, uv + vec2(split, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(split, 0.0)).b;

	// Scanline Overlay
	float scanline = sin(uv.y * scanline_density + time * 10.0) * 0.5 + 0.5;
	vec3 color = vec3(r, g, b);
	color -= scanline * 0.15 * glitch_intensity;

	// Simulation Grid Tint / Inversion Flicker
	float flash = step(0.92, hash(vec2(floor(time * 16.0), 0.0))) * glitch_intensity;
	color = mix(color, vec3(0.05, 0.9, 0.75) * (1.0 - color), flash * 0.4);

	COLOR = vec4(color, 1.0);
	}
}
