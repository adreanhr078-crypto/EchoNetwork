shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float motion_time = 0.0;
varying vec3 dust_color;
void vertex() {
    float seed = INSTANCE_CUSTOM.x;
    float slow_time = motion_time * (0.045+seed*0.015);
    VERTEX += vec3(sin(slow_time+seed*31.0)*0.14, sin(slow_time*0.7+seed*53.0)*0.23,cos(slow_time+seed*17.0)*0.12);
    dust_color = mix(vec3(0.22,0.38,0.42),vec3(0.62,0.43,0.20),INSTANCE_CUSTOM.y);
}
void fragment() {
    ALBEDO = dust_color;
    EMISSION = dust_color*0.16;
}
