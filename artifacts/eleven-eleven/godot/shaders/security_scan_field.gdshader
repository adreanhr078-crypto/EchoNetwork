shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 signal_color : source_color = vec4(1.0,0.48,0.13,1.0);
uniform float phase = 0.0;
uniform float alert : hint_range(0.0,1.0) = 0.0;
uniform float motion_amount : hint_range(0.0,1.0) = 1.0;
varying float axial;

void vertex() {
    // Probe in Godot4.8-dev7: CylinderMesh side UV.y spans 0..0.5.
    // Local position preserves a full-length fade independently of cap UVs.
    axial = clamp(0.5 - VERTEX.y / 13.0, 0.0, 1.0);
}

void fragment() {
	// Same cone as the actual 12-degree detector. Opaque cover depth-tests it.
	float near_fade = smoothstep(0.015,0.15,axial);
	float far_fade = 1.0-smoothstep(0.55,0.98,axial);
	float band = pow(max(0.0,cos(axial*28.0-phase*1.3)),8.0);
	float face = abs(dot(normalize(NORMAL),normalize(VIEW)));
	float shell = (0.45+0.55*pow(1.0-face,2.0))*smoothstep(0.0,0.30,face);
	ALBEDO = signal_color.rgb*(1.18+0.12*band*motion_amount);
	// Mixed transparency keeps cover readable in the measured Compatibility
	// fixture; the additive candidate rendered as a hard bright solid shell.
	ALPHA = near_fade*far_fade*shell*(0.26+0.10*band*motion_amount)*(1.0+0.4*alert)*smoothstep(0.25,0.8,-VERTEX.z);
}
