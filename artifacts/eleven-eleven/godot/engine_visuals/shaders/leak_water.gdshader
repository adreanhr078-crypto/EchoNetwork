shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
global uniform float hyper_visual_time;
uniform float motion = 1.0;
uniform float detail = 1.0;
uniform vec4 ripples[4]; // world x,z,time,strength; original contact events only
varying vec3 world_pos;
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
    vec2 p=UV*2.0-1.0;
    float outline=length(p)+0.04*sin(p.x*17.0+p.y*11.0)+0.025*sin(p.y*31.0);
    if(outline>0.97) discard;
    float t=hyper_visual_time*motion;
    vec2 slope=vec2(sin(world_pos.x*8.0+t*1.1),cos(world_pos.z*7.0+t))*0.035*motion;
    float crest=0.0;
    for(int i=0;i<4;i++){
        float age=hyper_visual_time-ripples[i].z;
        vec2 offset=world_pos.xz-ripples[i].xy;
        float radius=length(offset);
        float live=step(0.0,age)*(1.0-step(1.8,age))*ripples[i].w*motion;
        float ring=exp(-pow((radius-age*0.9)*20.0,2.0))*exp(-age*2.5)*live;
        slope+=offset/max(radius,0.01)*ring*0.2;
        crest+=ring;
    }
    float drip=fract(t*0.46);
    float ring=exp(-pow((length(p*vec2(1.0,1.6))-drip)*24.0,2.0))*(1.0-drip)*motion*detail;
    slope+=p*ring*0.08;
    float fresnel=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),4.0);
    ALBEDO=mix(vec3(0.025,0.047,0.058),vec3(0.16,0.24,0.28),fresnel*0.55)+(crest+ring)*0.018;
    ROUGHNESS=0.13+smoothstep(0.7,0.97,outline)*0.26;
    METALLIC=0.08;
    SPECULAR=0.8;
    NORMAL_MAP=normalize(vec3(slope.x,slope.y,1.0))*0.5+0.5;
}
