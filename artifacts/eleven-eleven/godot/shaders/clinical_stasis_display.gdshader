shader_type spatial;
render_mode unshaded, cull_back;

// Static clinical standby panel; the original Label3D owns the actual 11:11
// reveal. No fabricated countdown, flashing, text, audio or story mutation.
uniform bool stasis_active=false;

void fragment(){
	vec2 uv=UV;
	vec3 ink=stasis_active?vec3(.27,.12,.38):vec3(.055,.22,.27);
	vec3 background=vec3(.035,.060,.077);
	float edge=min(min(uv.x,1.0-uv.x),min(uv.y,1.0-uv.y));
	float inset=step(.017,edge);
	float grid_x=1.0-smoothstep(.008,.023,abs(fract(uv.x*40.0)-.5));
	float grid_y=1.0-smoothstep(.008,.023,abs(fract(uv.y*10.0)-.5));
	float grid=max(grid_x,grid_y)*.08;
	float header=step(.10,uv.y)*step(uv.y,.115)*step(.05,uv.x)*step(uv.x,.95);
	float footer=step(.87,uv.y)*step(uv.y,.885)*step(.05,uv.x)*step(uv.x,.95);
	float side=step(.08,uv.x)*step(uv.x,.25)+step(.75,uv.x)*step(uv.x,.92);
	float rows=step(.38,uv.y)*step(uv.y,.70)*step(.35,fract(uv.y*14.0));
	float bars=side*rows*mix(.17,.40,step(.5,fract(uv.x*30.0)));
	ALBEDO=mix(ink*.48,background+ink*(grid+header*.7+footer*.35+bars),inset);
	// Feather light toward the retained architectural reveal; the original
	// clock digits render independently in front of this panel.
	ALBEDO*=mix(.30,1.0,smoothstep(.0,.14,edge));
}
