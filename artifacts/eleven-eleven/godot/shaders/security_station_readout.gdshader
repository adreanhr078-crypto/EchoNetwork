shader_type spatial;
render_mode unshaded,cull_back;
uniform vec4 signal_color:source_color=vec4(0.0,.85,.95,1.0);
void fragment(){
    vec2 uv=UV;
    float frame=step(.06,uv.x)*step(uv.x,.94)*step(.06,uv.y)*step(uv.y,.94);
    float rows=1.0-smoothstep(.025,.05,abs(fract(uv.y*5.0)-.5));
    float bars=rows*step(.18,uv.x)*step(uv.x,.76)*frame;
    ALBEDO=vec3(.009,.018,.028)+signal_color.rgb*bars*.22;
    EMISSION=signal_color.rgb*bars*.035;
}
