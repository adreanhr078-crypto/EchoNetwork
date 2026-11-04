shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

// Architectural ceramic/alloy keeps continuous reflected light and a very
// fine surface finish. Character and hero-prop cel materials stay separate.
uniform vec4 base_color:source_color=vec4(.62,.68,.72,1.0);
uniform float metalness:hint_range(0.0,1.0)=.12;
uniform float surface_roughness:hint_range(0.0,1.0)=.55;
uniform float minimum_roughness:hint_range(0.0,1.0)=.1;
uniform bool clean_clinical_coating=false;
uniform bool cladding_tone_enabled=false;
uniform float cladding_base_y=0.0;
uniform vec4 coating_color:source_color=vec4(.64,.65,.66,1.0);
uniform bool ceramic_finish=true;
uniform sampler2D finish_grain:filter_linear_mipmap,repeat_enable;
uniform sampler2D color_map:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D roughness_map:filter_linear_mipmap,repeat_enable;
uniform sampler2D metallic_map:filter_linear_mipmap,repeat_enable;
uniform sampler2D ao_map:filter_linear_mipmap,repeat_enable;
uniform bool has_color_map=false;
// Per-room colour direction preserves the original texture bytes and every
// PBR channel. Default1 keeps all previously reviewed material response.
uniform float texture_saturation:hint_range(0.0,1.0)=1.0;
uniform bool has_normal_map=false;
uniform bool has_roughness_map=false;
uniform bool has_metallic_map=false;
uniform bool combined_rm_map=false;
uniform bool has_ao_map=false;
uniform float normal_strength=1.0;
uniform vec4 roughness_channel=vec4(1,0,0,0);
uniform vec4 metallic_channel=vec4(1,0,0,0);
uniform vec4 ao_channel=vec4(1,0,0,0);
uniform vec3 uv_scale=vec3(1.0);
uniform vec3 uv_offset=vec3(0.0);
varying vec3 world_position;
varying vec3 world_normal;

void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment(){
	// Retained generated perimeter sheets have outward-facing exterior
	// normals. Double-sided interior rendering needs the corresponding normal
	// flip; otherwise a lit solid ceiling reads as an unlit black aperture.
	if(!FRONT_FACING){NORMAL=-NORMAL;}
	vec3 n=abs(normalize(world_normal));
	vec2 coords=n.y>.7?world_position.xz:(n.x>.7?world_position.zy:world_position.xy);
	float grain=texture(finish_grain,coords*2.0).r;
	float finish=ceramic_finish?mix(.965,1.015,grain):1.0;
	vec2 uv=UV*uv_scale.xy+uv_offset.xy;
	vec3 texel=has_color_map?texture(color_map,uv).rgb:vec3(1.0);
	texel=mix(vec3(dot(texel,vec3(.2126,.7152,.0722))),texel,texture_saturation);
	// source_color sampling already returns linear light: keep the threshold
	// in linear space so old baked midtone shadows do not survive as stains.
	float coating=clean_clinical_coating?smoothstep(.035,.22,dot(texel,vec3(.2126,.7152,.0722))):0.0;
	if(clean_clinical_coating&&!FRONT_FACING){coating=max(coating,.90);}
	ALBEDO=mix(base_color.rgb*finish*texel,coating_color.rgb*mix(.97,1.01,grain),coating*.94);
	if(cladding_tone_enabled){
		// A calm upper service tier and lifted graphite seams keep the
		// repeating tile subordinate to the examination station.
		float upper=smoothstep(4.8,6.0,world_position.y-cladding_base_y);
		ALBEDO=max(ALBEDO,vec3(.016,.025,.045))*mix(vec3(.74,.79,.85),vec3(.52,.56,.62),upper);
	}
	vec4 rm=has_roughness_map?texture(roughness_map,uv):vec4(1.0);
	vec4 metal=has_metallic_map?(combined_rm_map?rm:texture(metallic_map,uv)):vec4(1.0);
	METALLIC=metalness*dot(metal,metallic_channel);
	ROUGHNESS=clamp(surface_roughness*dot(rm,roughness_channel)+(grain-.5)*.045,minimum_roughness,.95);
	METALLIC*=1.0-coating*.90;
	ROUGHNESS=max(ROUGHNESS,coating*.66);
	if(has_normal_map){NORMAL_MAP=texture(normal_map,uv).rgb;NORMAL_MAP_DEPTH=normal_strength*mix(1.0,.35,coating);}
	AO=has_ao_map?dot(texture(ao_map,uv),ao_channel):1.0;
	SPECULAR=.5;
}
