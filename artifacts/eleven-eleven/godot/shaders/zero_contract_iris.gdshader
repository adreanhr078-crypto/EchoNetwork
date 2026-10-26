shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

uniform sampler2D source_albedo : source_color, filter_linear_mipmap;
uniform float local_time = 0.0;
uniform float intensity = 0.0;
uniform bool reduced_motion = false;

float segment_distance(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b-a;
    return length(p-a-ab*clamp(dot(p-a,ab)/max(dot(ab,ab),0.00001),0.0,1.0));
}

void fragment() {
    vec3 painted = texture(source_albedo, UV).rgb;
    float highest = max(painted.r, max(painted.g, painted.b));
    float lowest = min(painted.r, min(painted.g, painted.b));
    float saturation = (highest - lowest) / max(highest, 0.001);
    // The native iris includes blue as well as cyan texels. Requiring green
    // dominance left its blue center unchanged. Preserve the dark pupil and
    // neutral whites while covering both cool source-iris colors.
    float cool_iris = smoothstep(0.025, 0.10, painted.b - painted.r);
    float iris = cool_iris * smoothstep(0.40, 0.65, saturation) * smoothstep(0.13, 0.30, highest);
    float detail = dot(painted, vec3(0.2126, 0.7152, 0.0722));
    // Retain the atlas pupil/highlight contrast instead of flattening the iris
    // into a uniform luminous disc at the encounter exposure.
    vec3 violet = vec3(0.40, 0.025, 0.90) * (0.025 + detail * 2.2);
    // The encounter retains its authored low exposure. Give this tiny emissive
    // iris HDR radiance locally instead of lifting the face or room exposure.
    float breath = reduced_motion ? 1.0 : 0.97 + 0.03 * sin(local_time * 1.7);
    // Fixed branching filaments in the source facial atlas follow its exact skin
    // weights. No UV drift, vertex displacement, pupil expansion or face change.
    vec2 e=(UV-vec2(0.863,0.095))/vec2(0.010,0.009);
    float d=segment_distance(e,vec2(0.83,0.40),vec2(1.15,0.65));
    d=min(d,segment_distance(e,vec2(1.15,0.65),vec2(1.07,1.05)));
    d=min(d,segment_distance(e,vec2(1.07,1.05),vec2(1.46,1.62)));
    d=min(d,segment_distance(e,vec2(1.15,0.65),vec2(1.62,0.83)));
    d=min(d,segment_distance(e,vec2(1.62,0.83),vec2(1.78,1.22)));
    d=min(d,segment_distance(e,vec2(-0.65,0.62),vec2(-0.91,1.04)));
    d=min(d,segment_distance(e,vec2(-0.91,1.04),vec2(-0.71,1.51)));
    d=min(d,segment_distance(e,vec2(-0.91,1.04),vec2(-1.23,1.22)));
    d=min(d,segment_distance(e,vec2(0.65,-0.62),vec2(0.98,-0.97)));
    d=min(d,segment_distance(e,vec2(0.98,-0.97),vec2(0.86,-1.45)));
    float outside_aperture=smoothstep(1.02,1.13,length(e*vec2(1.0,1.3)));
    float skin=(1.0-smoothstep(0.28,0.55,saturation))*smoothstep(0.16,0.36,highest);
    float aa=max(fwidth(d),0.007);
    float core=1.0-smoothstep(0.014,0.014+aa,d);
    float halo=exp(-d*38.0);
    float veins=(core*0.66+halo*0.16)*skin*outside_aperture;
    vec3 vein_radiance=vec3(0.65,0.055,1.0)*(1.4+core*1.5)*breath;
    float iris_alpha=iris*clamp(intensity*1.5,0.0,1.0);
    float vein_alpha=veins*clamp(intensity,0.0,1.0);
    ALBEDO=mix(vein_radiance,violet*4.2,iris_alpha/max(iris_alpha+vein_alpha,0.0001));
    EMISSION = ALBEDO * 1.2 * clamp(intensity, 0.0, 1.8) * breath;
    ROUGHNESS = 0.43;
    METALLIC = 0.0;
    // Source dark pupil, whites, skin, hair and eyelids receive no overlay.
    ALPHA = clamp(iris_alpha+vein_alpha,0.0,1.0);
}
