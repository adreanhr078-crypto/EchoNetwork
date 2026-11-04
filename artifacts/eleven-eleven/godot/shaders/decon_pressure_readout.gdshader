shader_type spatial;
render_mode unshaded;
uniform float elapsed=0.0;
uniform float motion=1.0;
uniform bool cleared=false;
void fragment(){
	vec2 uv=UV;
	vec3 signal=cleared?vec3(.08,.46,.25):vec3(.03,.32,.42);
	float grid=step(.97,fract(uv.x*12.0))+step(.97,fract(uv.y*8.0));
	float pressure=.5+.08*sin(uv.x*16.0)+.018*sin(uv.x*45.0);
	float trace=1.0-smoothstep(.006,.018,abs(uv.y-pressure));
	float head=exp(-pow((uv.x-fract(elapsed*.10))/.08,2.0))*motion;
	float bars=step(.80,uv.y)*step(uv.y,.86)*step(.08,uv.x)*step(uv.x,cleared?.90:.56);
	ALBEDO=vec3(.008,.017,.024)+grid*.008+signal*(trace*(.8+head*.4)+bars*.65);
}
