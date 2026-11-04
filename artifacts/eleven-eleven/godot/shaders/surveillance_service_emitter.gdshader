shader_type spatial;
render_mode unshaded;
uniform float elapsed=0.0;
uniform float motion=1.0;
uniform float cleared=0.0;
uniform int device_role=1;
void fragment(){
 vec3 warm=vec3(.91,.74,.49);
 vec3 signal=mix(vec3(.68,.055,.025),vec3(.08,.55,.32),cleared);
 vec3 ink=device_role==1?warm:signal;
 float pulse=device_role==1?1.0:(.94+.06*sin(elapsed*1.4)*motion);
 ALBEDO=ink*.48;EMISSION=ink*.55*pulse;
}
