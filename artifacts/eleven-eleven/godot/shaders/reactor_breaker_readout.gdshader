shader_type spatial;
render_mode unshaded,cull_back;
uniform float relay_a=0.0;
uniform float relay_b=0.0;
uniform int instrument=0;
uniform float phase=0.0;
void fragment(){
    vec2 p=UV;
    vec2 cell=abs(fract(p*vec2(26.0,12.0))-.5);
    float grid=smoothstep(.46,.50,max(cell.x,cell.y));
    vec3 ink=vec3(.006,.013,.018)+grid*vec3(.006,.010,.013);
    for(int i=0;i<2;i++){
        float y=.31+float(i)*.38;
        float state=i==0?relay_a:relay_b;
        vec3 signal_color=mix(vec3(.23,.115,.025),vec3(.025,.22,.25),state);
        float rail=(1.0-smoothstep(.012,.023,abs(p.y-y)))*step(.16,p.x)*step(p.x,.85);
        float nodes=(1.0-smoothstep(.025,.043,length((p-vec2(.16,y))*vec2(1.0,1.8))))
            +(1.0-smoothstep(.025,.043,length((p-vec2(.85,y))*vec2(1.0,1.8))));
        float selected=i==instrument?1.0:.48;
        ink+=(rail+nodes)*signal_color*selected;
    }
    float sweep=1.0+.05*sin(phase*.8);
    ALBEDO=ink*sweep;
}
