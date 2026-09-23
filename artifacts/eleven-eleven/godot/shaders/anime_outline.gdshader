shader_type spatial;
render_mode cull_front, unshaded;

// ── 11.11 Anime Inverted Hull Screen-Space Outline Shader ──────
uniform vec4 outline_color : source_color = vec4(0.06, 0.07, 0.1, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 2.2;

void vertex() {
	vec4 clip_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_norm = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
	clip_pos.xy += normalize(clip_norm.xy) / VIEWPORT_SIZE * clip_pos.w * outline_width * 2.0;
	POSITION = clip_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
