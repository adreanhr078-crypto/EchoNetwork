shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 signal_color : source_color = vec4(0.45, 0.06, 0.95, 1.0);
uniform int shape_kind = 0;
uniform float opacity : hint_range(0.0, 0.6) = 0.38;
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
	float mask;
	if (shape_kind == 0) {
		float angle = abs(atan(local_point.z, local_point.x));
		float sector = 1.0 - smoothstep(1.0, 1.45, angle);
		float band = 1.0 - smoothstep(0.025, 0.085, abs(length(local_point.xz) - 1.225));
		mask = sector * band;
	} else {
		vec2 p = UV * 2.0 - 1.0;
		float curve = 0.5 * (p.x * p.x - 0.5);
		mask = (1.0 - smoothstep(0.025, 0.16, abs(p.y - curve))) * (1.0 - smoothstep(0.65, 1.0, abs(p.x)));
	}
	ALBEDO = signal_color.rgb * 0.28;
	EMISSION = signal_color.rgb * 1.2;
	ALPHA = mask * opacity;
}
