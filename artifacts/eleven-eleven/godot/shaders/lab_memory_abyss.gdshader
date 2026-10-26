shader_type canvas_item;

// Subjective water over the live laboratory. Authored elapsed time pauses with
// the scene; reduced motion holds the same readable composition without drift.
uniform sampler2D scene_color : hint_screen_texture, filter_linear;
uniform float elapsed = 0.0;
uniform float motion = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = elapsed * motion;
	vec2 ripple = vec2(sin(uv.y * 24.0 + t * .5), cos(uv.x * 17.0 + t * .4));
	vec3 scene = texture(scene_color, clamp(uv + ripple * .0015 * motion, vec2(.002), vec2(.998))).rgb;
	float shaft = exp(-pow((uv.x - .52) / (.12 + uv.y * .2), 2.0)) * pow(1.0 - uv.y, 2.2);
	float grain = fract(sin(dot(floor(uv * vec2(820.0,460.0)),vec2(12.9898,78.233))) * 43758.5453);
	float edge = smoothstep(.16,.72,length((uv - vec2(.5,.42)) * vec2(1.0,.8)));
	vec3 water = vec3(.012,.027,.055) + shaft * vec3(.10,.16,.21);
	vec3 tinted = scene * vec3(.16,.25,.38) + water + (grain - .5) * .009;
	tinted *= 1.0 - edge * .46;
	COLOR = vec4(tinted,1.0);
}
