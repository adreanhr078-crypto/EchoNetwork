shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,shadows_disabled;
uniform float elapsed=0.0;
uniform float motion=1.0;
uniform float active=1.0;
void fragment(){
 float cycle=fract(elapsed*.29);
 float burst=step(.965,cycle)*motion*active;
 float line=.5+sin(UV.y*27.0+elapsed*31.0)*.11+sin(UV.y*81.0-elapsed*19.0)*.04;
 float filament=1.0-smoothstep(.012,.075,abs(UV.x-line));
 float edge=sin(UV.y*3.14159265);
 ALBEDO=vec3(.38,.66,.83);ALPHA=filament*edge*burst*.45;
}
