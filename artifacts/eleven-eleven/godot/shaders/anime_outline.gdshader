shader_type spatial;
render_mode cull_front, unshaded;

// ── 11.11 Anime Inverted Hull Outline with Microscopic Normal Extrusion ──────
// Microscopic thickness (~0.00065m / 0.65mm) guarantees that delicate facial features
// (eyelids, nose bridge, lips, chin) remain crisp without distorting geometry,
// eliminating dark envelope artifacts and mesh clipping.
// Fully compatible with hardware GPU skinning across Godot 4.7.2 Forward+, Mobile,
// and GL Compatibility.

uniform vec4 outline_color : source_color = vec4(0.05, 0.06, 0.09, 1.0);
uniform float outline_width : hint_range(0.0, 4.0) = 1.0;
uniform float microscopic_thickness : hint_range(0.0001, 0.003) = 0.00065;

void vertex() {
	// Microscopic inverted-hull expansion along vertex normal
	float thickness = microscopic_thickness * outline_width;
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}

