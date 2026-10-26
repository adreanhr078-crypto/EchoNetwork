shader_type spatial;
render_mode cull_disabled;

// Local finish only: original geometry, UVs and source images stay intact.
uniform sampler2D source_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform bool textured = false;
uniform vec4 tint : source_color = vec4(0.28, 0.34, 0.41, 1.0);
uniform float metal = 0.45;
uniform float source_saturation=1.0;
uniform float base_roughness = 0.6;
// Opt-in connected-route opening in the joined backstop mesh. Bounds are
// supplied by the same adapter that opens its original physics boundary.
uniform bool campaign_aperture = false;
uniform mat4 aperture_room_inverse = mat4(1.0);
uniform vec3 aperture_min;
uniform vec3 aperture_max;
uniform bool measured_side_cladding=false;
uniform mat4 cladding_room_inverse=mat4(1.0);
uniform mat4 visual_replacement_room_inverse=mat4(1.0);
uniform int replacement_count=0;
uniform vec3 replacement_min[16];
uniform vec3 replacement_max[16];
varying vec3 world_point;

void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 replaced_point=(visual_replacement_room_inverse*vec4(world_point,1.0)).xyz;
    for(int i=0;i<16;i++){
        if(i>=replacement_count){break;}
        if(all(greaterThanEqual(replaced_point,replacement_min[i]))
                && all(lessThanEqual(replaced_point,replacement_max[i]))){discard;}
    }
    vec3 cladding_point=(cladding_room_inverse*vec4(world_point,1.0)).xyz;
    if(measured_side_cladding && (cladding_point.x<=-4.19 || cladding_point.x>=5.19)
            && cladding_point.y>=-.001 && cladding_point.y<=10.601
            && cladding_point.z>=-14.501 && cladding_point.z<=.501){discard;}
    vec3 room_point = (aperture_room_inverse * vec4(world_point, 1.0)).xyz;
    if (campaign_aperture && all(greaterThanEqual(room_point, aperture_min))
            && all(lessThanEqual(room_point, aperture_max))) {
        discard;
    }
    vec3 texel=textured?texture(source_albedo, UV).rgb:vec3(1.0);
    texel=mix(vec3(dot(texel,vec3(.2126,.7152,.0722))),texel,source_saturation);
    vec3 base=texel*tint.rgb;
    if(!FRONT_FACING){NORMAL=-NORMAL;}
    // Restrained brushed grain and oil variation, no animated noise or screen effects.
    float brush = sin(world_point.y * 140.0 + sin(world_point.x * 37.0) * 0.7);
    float stain = 0.5 + 0.5 * sin(world_point.x * 2.3 + world_point.z * 1.8)
        * sin(world_point.y * 3.7 + world_point.z * 0.6);
    ALBEDO = base * (0.89 + stain * 0.12 + brush * 0.004);
    METALLIC = metal;
    ROUGHNESS = clamp(base_roughness + (stain - 0.5) * 0.16, 0.32, 0.88);
}
