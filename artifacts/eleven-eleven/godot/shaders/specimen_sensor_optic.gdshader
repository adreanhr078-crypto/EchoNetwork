shader_type spatial;
render_mode unshaded;
uniform vec4 indicator_color:source_color=vec4(0.0,.9,1.0,1.0);
void fragment(){
    float radius=length(UV-vec2(.5));
    float iris=1.0-smoothstep(.29,.35,radius);
    float bezel=smoothstep(.38,.40,radius)*(1.0-smoothstep(.46,.49,radius));
    ALBEDO=vec3(.012,.021,.029)+indicator_color.rgb*(iris*.22+bezel*.13);
    EMISSION=indicator_color.rgb*(iris*.10+bezel*.08);
    ROUGHNESS=.2;
}
