shader_type spatial;
render_mode unshaded,cull_back;
uniform int memories=0;
uniform bool decoded=false;
uniform float phase=0.0;
void fragment(){
	vec2 p=UV;
	vec2 cell=abs(fract(p*vec2(24.0,12.0))-.5);
	float grid=smoothstep(.46,.50,max(cell.x,cell.y));
	vec3 ink=vec3(.007,.017,.024)+grid*vec3(.006,.013,.017);
	for(int i=0;i<3;i++){
		float centre=.25+float(i)*.25;
		float rail=(1.0-smoothstep(.010,.021,abs(p.y-centre)))*step(.10,p.x)*step(p.x,.88);
		float active=i<memories?1.0:.18;
		ink+=rail*mix(vec3(.025,.14,.18),vec3(.26,.14,.035),decoded?1.0:0.0)*active;
	}
	float trace=.5+sin(p.x*23.0+sin(p.x*8.0))*.12;
	float wave=(1.0-smoothstep(.006,.013,abs(p.y-trace)))*step(.08,p.x)*step(p.x,.92);
	float scan=1.0+.08*sin(phase*.8);
	ALBEDO=ink+wave*vec3(.018,.12,.15)*scan;
}
