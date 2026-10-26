shader_type sky;
uniform vec4 zenith : source_color = vec4(0.06,0.035,0.16,1.0);
uniform vec4 horizon : source_color = vec4(0.14,0.22,0.35,1.0);
void sky() {
	float gradient = smoothstep(-0.15,0.65,EYEDIR.y);
	COLOR = mix(horizon.rgb,zenith.rgb,gradient);
}
