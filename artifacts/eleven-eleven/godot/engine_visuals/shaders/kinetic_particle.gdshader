shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.4,0.65,0.85,1.0);
uniform int shape = 0;
uniform float brightness = 0.4;
void vertex() {
	// Camera-facing cards retain particle scale without external textures.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0].xyz *= length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[1].xyz *= length(MODEL_MATRIX[1].xyz);
}
void fragment() {
	vec2 p = UV*2.0-1.0;
	float radius = length(p);
	float radial = exp(-dot(p,p)*6.0)*(1.0-smoothstep(0.65,1.0,radius));
	float spark = exp(-p.x*p.x*95.0)*(1.0-smoothstep(0.2,1.0,abs(p.y)));
	float ring = exp(-pow((radius-0.67)*20.0,2.0));
	float mask = shape==1 ? spark : (shape==2 ? ring : radial);
	ALBEDO = tint.rgb * brightness * COLOR.rgb;
	ALPHA = mask * tint.a * COLOR.a;
}
