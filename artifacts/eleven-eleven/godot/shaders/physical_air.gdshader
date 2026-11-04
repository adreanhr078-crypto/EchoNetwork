shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled,shadows_disabled;
uniform vec4 tint:source_color=vec4(.65,.70,.74,.15);
void vertex(){
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0].xyz*=length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[1].xyz*=length(MODEL_MATRIX[1].xyz);
}
void fragment(){
	vec2 p=UV*2.0-1.0;
	float mask=exp(-dot(p,p)*5.0)*(1.0-smoothstep(.6,1.0,length(p)));
	ALBEDO=tint.rgb*COLOR.rgb;
	ALPHA=mask*tint.a*COLOR.a;
}
