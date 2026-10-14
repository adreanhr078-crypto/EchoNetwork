shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 signal_color : source_color = vec4(1.0,0.48,0.13,1.0);
uniform float phase = 0.0;
uniform float alert : hint_range(0.0,1.0) = 0.0;
uniform float motion_amount : hint_range(0.0,1.0) = 1.0;

void fragment() {
	// Same cone as the actual 12-degree detector. Opaque cover depth-tests it.
	float near_fade = smoothstep(0.015,0.12,UV.y);
	float far_fade = 1.0-smoothstep(0.70,1.0,UV.y);
	float band = pow(max(0.0,cos(UV.y*35.0-phase*1.3)),12.0);
	float rim = pow(1.0-clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),3.0);
	ALBEDO = signal_color.rgb;
	ALPHA = near_fade*far_fade*(0.018+0.034*rim+0.018*band*motion_amount)*(1.0+0.4*alert);
}
