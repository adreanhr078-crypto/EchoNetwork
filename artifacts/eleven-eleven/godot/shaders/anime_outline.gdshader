shader_type spatial;
render_mode cull_front, unshaded;

// ── 11.11 Anime Inverted Hull Outline with Depth-Bias Offset ──────
uniform vec4 outline_color : source_color = vec4(0.05, 0.06, 0.09, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 2.0;
uniform float depth_bias : hint_range(0.0, 0.05) = 0.002;

void vertex() {
	vec4 clip_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_norm = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
	
	// Screen-space uniform width expansion
	vec2 offset = normalize(clip_norm.xy) / VIEWPORT_SIZE * clip_pos.w * outline_width * 2.0;
	clip_pos.xy += offset;
	
	// Depth bias to push outline slightly behind front-facing geometry, eliminating Z-fighting
	clip_pos.z += depth_bias * clip_pos.w;
	
	POSITION = clip_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
