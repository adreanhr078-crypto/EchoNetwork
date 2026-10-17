shader_type spatial;
render_mode unshaded, blend_mix, cull_back;

uniform float motion_time = 0.0;

void vertex() {
    float rise = mod(INSTANCE_CUSTOM.y + motion_time * (0.12 + INSTANCE_CUSTOM.z * 0.07)
        * INSTANCE_CUSTOM.w / 3.3, INSTANCE_CUSTOM.w);
    VERTEX.y += rise - INSTANCE_CUSTOM.y;
    VERTEX.x += sin(motion_time * 0.35 + INSTANCE_CUSTOM.x * 6.283185) * 0.025;
}

void fragment() {
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.4);
    ALBEDO = vec3(0.40, 0.67, 0.72);
    ALPHA = 0.12 + rim * 0.28;
}
