shader_type spatial;
render_mode unshaded;
uniform sampler2D approved_page : source_color,filter_linear;
// Approved page009, panel3 older Echo only. Zero and E-01 lie outside this region.
uniform vec4 record_region = vec4(0.258333333,0.537037037,0.283333333,0.211111111);
void fragment() {
    vec2 point = record_region.xy+clamp(UV,vec2(0.002),vec2(0.998))*record_region.zw;
    ALBEDO = min(texture(approved_page,point).rgb*1.35,vec3(1.0));
}
