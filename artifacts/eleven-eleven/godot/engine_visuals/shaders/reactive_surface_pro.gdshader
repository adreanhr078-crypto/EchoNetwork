shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
global uniform vec3 player_world_pos;
global uniform vec4 global_wind_data;
global uniform float hyper_visual_time;
uniform vec4 base_color : source_color = vec4(0.19,0.26,0.34,1.0);
uniform vec4 signal_color : source_color = vec4(0.12,0.68,0.85,1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform sampler2D height_texture : hint_default_black;
uniform sampler2D roughness_texture : hint_default_white;
uniform float roughness = 0.32;
uniform float metallic = 0.25;
uniform float parallax_depth : hint_range(0.0,0.05) = 0.008;
uniform float energy_enabled = 0.0;
uniform float water_blend : hint_range(0.0,1.0) = 0.0;
uniform vec4 ripple_points[16]; // xyz world position, w start time
uniform float ripple_strengths[16];
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 view_offset = VIEW.xy / max(abs(VIEW.z),0.3);
	vec2 uv = UV - view_offset * texture(height_texture,UV).r * parallax_depth;
	vec3 color = texture(albedo_texture,uv).rgb * base_color.rgb;
	float ripple = 0.0;
	vec2 slope = vec2(0.0);
	for (int i=0; i<16; i++) {
		float age = hyper_visual_time-ripple_points[i].w;
		vec2 delta = world_pos.xz-ripple_points[i].xz;
		float radius = length(delta);
		float active = step(0.0,age)*(1.0-step(1.8,age));
		float height_gate = 1.0-smoothstep(0.08,0.3,abs(world_pos.y-ripple_points[i].y));
		float crest = exp(-pow((radius-age*1.45)*18.0,2.0));
		float fade = exp(-age*2.5) * active * height_gate * ripple_strengths[i];
		ripple += crest*fade;
		slope += delta/max(radius,0.01)*sin(radius*28.0-age*36.0)*crest*fade;
	}
	float proximity = 1.0-smoothstep(0.5,3.2,distance(world_pos,player_world_pos));
	vec2 cells = abs(fract(world_pos.xz*0.65)-0.5);
	float grid = 1.0-smoothstep(0.008,0.022,min(cells.x,cells.y));
	float caustic = pow(0.5+0.5*sin(world_pos.x*6.0+sin(world_pos.z*4.0+hyper_visual_time)),8.0);
	float fresnel = pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),4.0);
	float wet = mix(0.0,0.25,water_blend);
	ALBEDO = mix(color, color*vec3(0.72,0.9,1.0),fresnel*0.15);
	ROUGHNESS = clamp(roughness*texture(roughness_texture,uv).r-wet-ripple*0.05,0.06,1.0);
	METALLIC = metallic;
	SPECULAR = 0.65;
	NORMAL_MAP = normalize(vec3(slope.x*0.15, slope.y*0.15, 1.0))*0.5+0.5;
	EMISSION = signal_color.rgb * (ripple*(0.12+energy_enabled*1.8) + energy_enabled*proximity*(grid*0.2+caustic*0.08));
}
