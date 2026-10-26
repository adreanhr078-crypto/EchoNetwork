shader_type spatial;
uniform vec4 floor_color : source_color = vec4(0.46,0.51,0.54,1.0);
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float grain(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 p=world_point.xz/0.8;
 vec2 cell=fract(p);
 float edge=min(min(cell.x,1.0-cell.x),min(cell.y,1.0-cell.y));
 float seam=1.0-smoothstep(0.0015,0.006,edge);
 float speckle=grain(floor(world_point.xz*310.0))-.5;
 ALBEDO=floor_color.rgb*(1.0-seam*.12)+speckle*.009;
 METALLIC=.02;ROUGHNESS=.42;SPECULAR=.5;
}
