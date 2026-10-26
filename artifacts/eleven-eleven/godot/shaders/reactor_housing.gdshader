shader_type spatial;
uniform float motion_time = 0.0;
uniform float isolation : hint_range(0.0,1.0) = 0.0;
uniform vec4 body_color:source_color=vec4(.31,.39,.48,1.0);
uniform vec4 joint_color:source_color=vec4(.11,.17,.23,1.0);
uniform sampler2D finish_grain:filter_linear_mipmap,repeat_enable;
uniform bool has_finish_grain=false;
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
    float around = atan(local_point.z,local_point.x)/6.283185+0.5;
    vec2 p = vec2(around*28.0,local_point.y+7.0);
    vec2 cell = fract(p/vec2(2.0,2.35));
    vec2 edge = min(cell,1.0-cell)*vec2(2.0,2.35);
    float joint = 1.0-smoothstep(0.018,0.050,min(edge.x,edge.y));
    float rib = 1.0-smoothstep(0.06,0.15,edge.x);
    float vent = smoothstep(0.32,0.38,cell.x)*(1.0-smoothstep(0.62,0.68,cell.x));
    vent *= smoothstep(0.18,0.25,cell.y)*(1.0-smoothstep(0.75,0.82,cell.y));
    float slats = step(0.35,fract(p.y*9.0));
    float flow = 0.5+0.5*sin(p.y*2.8-motion_time*1.5+floor(around*14.0)*0.65);
    vec3 signal_color = mix(vec3(0.10,0.62,0.78),vec3(0.18,0.72,0.54),isolation);
    float grain=has_finish_grain?texture(finish_grain,vec2(around*84.0,p.y*3.0)).r:.5;
    ALBEDO = mix(body_color.rgb,joint_color.rgb,max(joint*0.6,vent*0.8))*mix(.975,1.015,grain);
    ALBEDO += rib*vec3(0.035,0.045,0.055);
    METALLIC = 0.28;
    ROUGHNESS = 0.52+joint*0.14+(grain-.5)*.035;
    EMISSION = signal_color*vent*slats*(0.38+flow*0.42)*(1.0-isolation*0.45);
}
