shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D reflection_map : source_color, filter_linear;
uniform mat4 reflection_vp;
uniform float elapsed = 0.0;
uniform float motion = 1.0;
uniform float reflection_gain = 1.0;
uniform vec4 reflection_tint:source_color = vec4(1.0);
uniform vec4 ripple_a = vec4(0.0,0.0,-100.0,0.0);
uniform vec4 ripple_b = vec4(0.0,0.0,-100.0,0.0);
uniform vec4 ripple_c = vec4(0.0,0.0,-100.0,0.0);
uniform vec4 ripple_d = vec4(0.0,0.0,-100.0,0.0);
varying vec3 world_position;
varying vec4 reflection_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    reflection_position = reflection_vp * vec4(world_position,1.0);
}

vec2 ring(vec4 event, vec2 point) {
    float age = elapsed-event.z;
    vec2 offset = point-event.xy;
    float radius = length(offset);
    float envelope = exp(-pow((radius-age*0.85)*3.0,2.0))*exp(-max(age,0.0)*1.8);
    float live = step(0.0,age)*step(age,3.0)*event.w;
    return normalize(offset+vec2(0.0001))*sin(radius*24.0-age*13.0)*envelope*live*0.002;
}

void fragment() {
    vec2 point = world_position.xz;
    float t = elapsed*motion;
    vec2 wave = vec2(sin(point.x*1.4+point.y*0.7+t*0.8),cos(point.y*1.1-point.x*0.5+t*0.6))*0.0018*motion;
    wave += (ring(ripple_a,point)+ring(ripple_b,point)+ring(ripple_c,point)+ring(ripple_d,point))*motion;
    vec2 projected = reflection_position.xy / max(reflection_position.w,0.001);
    vec2 uv = projected*vec2(0.5,-0.5)+vec2(0.5)+wave;
    vec3 reflected = texture(reflection_map,clamp(uv,vec2(0.001),vec2(0.999))).rgb;
    float inside = step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0)*step(0.0,reflection_position.w);
    float fresnel = pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
    vec3 water = vec3(0.022,0.047,0.067);
    ALBEDO = mix(water,reflected*reflection_tint.rgb*reflection_gain,inside*(0.58+0.3*fresnel));
    ALPHA = 0.95;
}
