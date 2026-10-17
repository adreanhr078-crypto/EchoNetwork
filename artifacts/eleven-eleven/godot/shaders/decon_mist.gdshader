shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float motion_time = 0.0;
uniform float mist_amount = 1.0;
varying float origin_phase;
void vertex() { origin_phase = MODEL_MATRIX[3].z*0.45; }
void fragment() {
	float edge_x = smoothstep(0.0,0.14,UV.x)*(1.0-smoothstep(0.86,1.0,UV.x));
	float edge_y = smoothstep(0.0,0.06,UV.y)*(1.0-smoothstep(0.78,1.0,UV.y));
	float rays = 0.55+0.45*sin(UV.x*38.0+sin(UV.y*9.0-motion_time*1.4)*1.6+origin_phase);
	float jet = (1.0-smoothstep(0.0,0.62,UV.y))*rays;
	vec2 p = vec2(UV.x*6.5+sin(UV.y*8.0-motion_time*1.1+origin_phase)*0.65,UV.y*7.5-motion_time*1.65);
	float swirl_a = 0.5+0.5*sin(p.x*2.4+cos(p.y*2.1+origin_phase)*1.8);
	float swirl_b = 0.5+0.5*cos(p.y*3.1-sin(p.x*2.7-motion_time*0.9)*1.5);
	float vortex = smoothstep(0.22,0.88,swirl_a*0.6+swirl_b*0.4);
	// One broad purge sweep during the existing fade, no repeated flashing.
	float purge = 1.0+sin(mist_amount*3.14159)*0.75*step(mist_amount,0.96);
	vec3 color = mix(vec3(0.58,0.15,0.96),vec3(0.22,0.86,0.82),smoothstep(0.10,0.82,UV.y)*(0.65+0.35*vortex));
	float density = (jet*0.55+vortex*0.65)*edge_x*edge_y;
	ALBEDO = color*(1.15+jet*0.45)*purge;
	// Fade only beside the lens so crossing a curtain never floods the camera.
	float camera_fade = smoothstep(0.35,1.1,-VERTEX.z);
	ALPHA = clamp(density*mist_amount*purge*0.25,0.0,0.55)*camera_fade;
}
