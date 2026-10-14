shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float motion_time = 0.0;
uniform float strength = 0.35;
uniform int kind = 0;
uniform vec4 tint : source_color = vec4(0.15,0.65,0.86,1.0);
varying float seed;
varying float life;

void vertex() {
    seed = INSTANCE_CUSTOM.x;
    float speed = mix(0.08,0.15,seed);
    life = fract(seed+motion_time*speed);
    vec3 origin = (MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
    if (kind == 0) {
        origin += vec3(sin(seed*31.0+motion_time*0.21)*0.23,life*0.85,cos(seed*17.0+motion_time*0.16)*0.20);
        VERTEX.xy *= 0.8+life*1.25;
    } else if (kind == 1) {
        origin += vec3(sin(seed*27.0+motion_time*0.33)*0.25,sin(seed*42.0+motion_time*0.28)*0.30,cos(seed*32.0+motion_time*0.25)*0.25);
        VERTEX.xy *= mix(0.7,1.4,seed);
    } else {
        origin.y += life*0.65;
        origin.x += sin(seed*31.0+motion_time*0.18)*0.025;
    }
    mat4 billboard = mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],vec4(origin,1.0));
    MODELVIEW_MATRIX = VIEW_MATRIX*billboard;
}

void fragment() {
    vec2 q = UV*2.0-1.0;
    float shape;
    if (kind == 0) {
        float soft = exp(-dot(q*vec2(1.0,0.72),q*vec2(1.0,0.72))*4.2);
        float folds = 0.65+0.35*sin(q.x*8.0+q.y*5.0+motion_time*0.25+seed*13.0);
        shape = soft*folds*sin(life*3.14159265)*0.22;
    } else if (kind == 1) {
        float core = exp(-dot(q,q)*8.0);
        float cross = exp(-abs(q.x)*30.0)*exp(-abs(q.y)*4.0)+exp(-abs(q.y)*30.0)*exp(-abs(q.x)*4.0);
        shape = core*0.8+cross*0.12;
    } else {
        float bar = (1.0-smoothstep(0.10,0.35,abs(q.y)))*(1.0-smoothstep(0.65,0.98,abs(q.x)));
        float ticks = step(0.30,fract(UV.x*7.0+seed*11.0));
        shape = bar*ticks*sin(life*3.14159265)*0.65;
    }
    ALBEDO = tint.rgb;
    EMISSION = tint.rgb*1.5;
    ALPHA = clamp(shape*strength,0.0,0.55);
}
