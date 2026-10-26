shader_type spatial;
render_mode unshaded, cull_back;

// Instrument texture only. Dialogue/objectives remain live localized UI.
uniform float elapsed=0.0;
uniform float motion=1.0;
void fragment(){
    vec2 uv=UV;
    vec2 cell=abs(fract(uv*vec2(16.0,9.0))-.5);
    float grid=smoothstep(.46,.50,max(cell.x,cell.y));
    float trace=.5+sin(uv.x*19.0+sin(uv.x*7.0))*.13;
    float line=1.0-smoothstep(.007,.020,abs(uv.y-trace));
    float head=exp(-pow((uv.x-fract(elapsed*.12))/.06,2.0))*motion;
    float bar=step(.78,uv.y)*step(uv.y,.83)*step(.08,uv.x)*step(uv.x,.42);
    ALBEDO=vec3(.010,.025,.037)+grid*vec3(.008,.018,.022);
    ALBEDO+=line*vec3(.035,.19,.23)*(1.0+head*.30);
    ALBEDO+=bar*vec3(.18,.08,.025);
}
