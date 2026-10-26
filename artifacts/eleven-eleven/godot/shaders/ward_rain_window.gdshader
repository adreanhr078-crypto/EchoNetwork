shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float elapsed=0.0;
uniform float motion=1.0;
float hash(float n){return fract(sin(n*127.1)*43758.5453);}
void fragment(){
 vec2 uv=UV;
 vec3 sky=mix(vec3(.64,.71,.74),vec3(.33,.46,.55),1.0-uv.y);
 float column=floor(uv.x*13.0);
 float building=step(.66+hash(column)*.23,uv.y)*step(.08,fract(uv.x*13.0));
 sky=mix(sky,vec3(.29,.39,.45),building*.45);
 float drops=0.0;
 for(int layer=0;layer<3;layer++){
  float l=float(layer);
  vec2 p=uv*vec2(19.0+l*7.0,3.2+l);
  float id=floor(p.x);
  p.x=fract(p.x)-.2-hash(id+l*23.0)*.6;
  p.y=fract(p.y-elapsed*motion*(.08+hash(id)*.06)+hash(id+l*4.0))-.5;
  float body=1.0-smoothstep(.015,.042,length(p*vec2(1.0,.14)));
  drops+=body*(.025+.012*l);
 }
 ALBEDO=sky+drops;
}
