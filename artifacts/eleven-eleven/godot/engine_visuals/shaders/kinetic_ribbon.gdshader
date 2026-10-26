shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, particle_trails;
uniform vec4 tint : source_color = vec4(0.22,0.56,0.8,0.35);
void fragment() {
	float width = sin(clamp(UV.x,0.0,1.0)*PI);
	float fade = (1.0-UV.y)*(1.0-UV.y);
	ALBEDO = tint.rgb*COLOR.rgb;
	ALPHA = width*fade*tint.a*COLOR.a;
}
