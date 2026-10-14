shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float motion_time = 0.0;
uniform float strength = 0.0;

void vertex() {
    float distance = mod(INSTANCE_CUSTOM.x*16.7+motion_time*1.6,16.7);
    vec3 path = distance < 3.5 ? vec3(-3.5+distance,0.075,-4.0) : vec3(0.0,0.075,-4.0-(distance-3.5));
    VERTEX *= strength*(0.65+INSTANCE_CUSTOM.y*0.5);
    VERTEX += path;
}
void fragment() {
    ALBEDO = vec3(0.20,0.80,0.96);
    EMISSION = vec3(0.20,0.85,1.0)*2.2*strength;
}
