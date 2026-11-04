shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D scene_color:hint_screen_texture,filter_linear_mipmap;
uniform float elapsed=0.0;
uniform float motion=1.0;
float hash(float x){return fract(sin(x*127.1)*43758.5453);}
void fragment(){
 vec2 bend=vec2(0.0);float glint=0.0;
 // The room owns/frees this clock. No TIME,independent timer or RM phase reset.
 for(int i=0;i<3;i++){
  float l=float(i);vec2 q=UV*vec2(19.0+l*9.0,5.0+l*2.0);
  float id=floor(q.x);q.x=fract(q.x)-.2-hash(id+l*31.0)*.6;
  q.y=fract(q.y-elapsed*(.10+hash(id)*.09)+hash(id+l*7.0))-.5;
  vec2 shape=q*vec2(27.0,4.5);float drop=exp(-dot(shape,shape)*2.0);
  bend+=q*drop*.032;glint+=drop*.08;
 }
 ALBEDO=textureLod(scene_color,SCREEN_UV+bend,.15).rgb+vec3(glint);
 ALPHA=.17+clamp(glint*3.0,0.0,.3);
}
