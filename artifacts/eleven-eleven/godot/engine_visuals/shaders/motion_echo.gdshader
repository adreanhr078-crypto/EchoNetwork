shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.18, 0.03, 0.38, 1.0);
uniform float opacity : hint_range(0.0, 0.14) = 0.14;
uniform vec3 snapshot_center = vec3(0.0);
varying float camera_distance;
void vertex() { camera_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz); }

// Original posed skin supplies the complete vertex stage: no displacement,
// wind, scale or invented skeleton can deform a captured character silhouette.
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = ink_color.rgb * mix(0.3, 1.0, rim);
	EMISSION = ink_color.rgb * rim * 0.18;
	float whole_fade = smoothstep(0.9, 1.6, distance(INV_VIEW_MATRIX[3].xyz, snapshot_center));
	ALPHA = clamp(opacity, 0.0, 0.14) * mix(0.35, 1.0, rim) * whole_fade * smoothstep(0.55, 1.0, camera_distance);
}
