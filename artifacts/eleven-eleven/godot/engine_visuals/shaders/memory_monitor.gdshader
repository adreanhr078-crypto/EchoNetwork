shader_type spatial;
render_mode unshaded, cull_disabled;
global uniform float hyper_visual_time;
uniform sampler2D footage : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(0.84,0.92,1.0,1.0);
uniform float strength = 0.8;
uniform float motion = 1.0;
uniform float playback_time = 0.0;
uniform float clip_duration = 8.0;
uniform float detail = 1.0;
uniform float drift_scale = 1.0;
uniform float phase = 1.9;
void vertex() {
    float t = hyper_visual_time * motion;
    // An intact, frameless memory pane drifts as a single rigid surface.
    float angle = sin(t*0.24+phase)*0.012*motion*detail;
    vec2 relative = VERTEX.xy;
    VERTEX.xy = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*relative;
    VERTEX.xy += vec2(sin(t*0.31+phase),cos(t*0.27+phase))*0.022*motion*drift_scale;
    VERTEX.z += sin(t*0.22+phase)*0.035*motion*drift_scale;
}
void fragment() {
    vec3 scene = texture(footage,UV).rgb;
    float lines = 0.995+0.005*sin(UV.y*620.0+hyper_visual_time*0.8*motion)*detail;
    float seam = mix(0.88,1.0,smoothstep(0.0,0.25,min(playback_time,clip_duration-playback_time)));
    float facing = FRONT_FACING ? 1.0 : 0.25;
    float border = min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
    float thin_edge = 1.0-smoothstep(0.001,0.003,border);
    vec3 memory = scene*tint.rgb*strength*lines*seam*facing;
    vec3 glass_edge = mix(vec3(0.12,0.42,0.62),vec3(0.42,0.25,0.65),0.3);
    ALBEDO = mix(memory,glass_edge*0.3,thin_edge*0.35);
    EMISSION = glass_edge*thin_edge*0.3;
}
