shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform float motion_time = 0.0;
uniform float resonance = 0.0;
uniform float decoded = 0.0;
uniform vec4 memory_color : source_color = vec4(0.8,0.61,0.29,1.0);
void fragment() {
    vec2 grid = vec2(UV.x*24.0,UV.y*34.0-motion_time*0.8);
    vec2 cell = fract(grid);
    float seed = fract(sin(dot(floor(grid),vec2(12.9898,78.233)))*43758.5453);
    float glyph = step(0.22,cell.x)*(1.0-step(0.62,cell.x))*step(0.14,cell.y)*(1.0-step(0.57,cell.y))*step(0.58,seed);
    float lane = 1.0-smoothstep(0.01,0.05,abs(fract(UV.x*8.0)-0.5));
    float ends = smoothstep(0.0,0.15,UV.y)*(1.0-smoothstep(0.82,1.0,UV.y));
    vec3 signal_color = mix(memory_color.rgb,vec3(0.35,0.88,0.98),lane*0.5);
    signal_color = mix(signal_color,vec3(0.24,0.80,0.65),decoded*0.55);
    ALBEDO = signal_color*(1.10+resonance*0.25);
    ALPHA = (0.05+glyph*0.32+lane*0.18)*ends;
}
