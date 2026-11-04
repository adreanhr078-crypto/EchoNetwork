shader_type spatial;
render_mode unshaded;
uniform float local_time = 0.0;
uniform vec3 authority = vec3(0.0);
uniform sampler2D feed_atlas:source_color,filter_linear_mipmap,repeat_disable;
uniform bool has_feed_atlas=false;
void fragment() {
    vec2 p = UV;
    float row = floor(clamp(p.y,0.0,0.999)*3.0);
    float enabled = row<1.0 ? authority.z : row<2.0 ? authority.y : authority.x;
    vec3 ink = mix(vec3(0.32,0.2,0.065),vec3(0.065,0.5,0.4),enabled);
    vec2 tile = fract(p*vec2(28.0,9.0));
    float grid = (1.0-smoothstep(0.015,0.045,min(tile.x,tile.y)))*0.06;
    float route = 1.0-smoothstep(0.008,0.017,abs(fract(p.y*3.0)-0.25));
    float packet = pow(max(0.0,1.0-abs(fract(p.x*2.0-local_time*0.08)-0.5)*2.0),14.0);
    // Authored data diagram; semantic labels carry the real inspected/override/gate state.
    float quiet_zone = smoothstep(0.57,0.66,p.x);
    ALBEDO = vec3(0.022,0.037,0.048)+grid*vec3(0.18,0.27,0.3)+quiet_zone*ink*(0.15+route*(0.5+packet));
    if(has_feed_atlas){
        vec2 panel=fract(p*vec2(4.0,2.0));
        float border=smoothstep(.006,.018,min(min(panel.x,1.0-panel.x),min(panel.y,1.0-panel.y)));
        float scan=.97+.03*sin(p.y*900.0-local_time*2.0);
        vec3 record=texture(feed_atlas,p).rgb*vec3(.28,.43,.51)*scan;
        // Recorded room03-07 camera imagery is decorative;the semantic labels
        // and authority uniform still exclusively own live security status.
        ALBEDO=mix(vec3(.012,.025,.033),record,border)+quiet_zone*ink*route*.20;
    }
}
