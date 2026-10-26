shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 impact_center = vec2(0.5);
uniform float strength = 0.0;
uniform float phase = 0.0;
uniform vec2 viewport_size = vec2(1920.0,1080.0);
void fragment() {
	vec2 d = SCREEN_UV-impact_center;
	d.x *= viewport_size.x/max(viewport_size.y,1.0);
	float r = length(d);
	float wave = exp(-pow((r-phase*0.85)*35.0,2.0))*strength;
	vec2 dir = d/max(r,0.001);
	dir.x *= viewport_size.y/max(viewport_size.x,1.0);
	vec2 uv = clamp(SCREEN_UV+dir*wave*0.006,vec2(0.002),vec2(0.998));
	vec2 split = dir * strength * 0.0018;
	vec3 rgb = vec3(texture(screen_texture,uv+split).r,texture(screen_texture,uv).g,texture(screen_texture,uv-split).b);
	vec3 blur = (texture(screen_texture,clamp(uv-dir*strength*0.004,vec2(0.002),vec2(0.998))).rgb+texture(screen_texture,clamp(uv-dir*strength*0.008,vec2(0.002),vec2(0.998))).rgb)*0.5;
	COLOR = vec4(mix(rgb,blur,strength*0.14),1.0);
}
