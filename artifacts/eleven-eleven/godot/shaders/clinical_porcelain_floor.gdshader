shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 porcelain : source_color = vec4(0.31,0.38,0.44,1.0);
uniform float surface_roughness=0.50;
uniform float surface_metalness=0.10;
uniform float tile_span_m=0.9;
uniform sampler2D ceramic_grain : source_color, filter_linear_mipmap;
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    vec2 cell=(world_point.xz+vec2(tile_span_m*.5))/tile_span_m;
    vec2 tile=fract(cell);
    vec2 edge=min(tile,1.0-tile);
    // World-space joints need pixel coverage at grazing angles, otherwise
    // distant intersections flicker as isolated black dots.
    vec2 footprint=max(fwidth(cell),vec2(.0005));
    vec2 half_pixel=footprint*.5;
    // Integrate the narrow physical joint over a pixel. Merely widening
    // smoothstep to fwidth would turn distant seams into a heavy grid.
    vec2 overlap=max(vec2(0.0),min(edge+half_pixel,vec2(.0012))-max(edge-half_pixel,vec2(-.0012)));
    vec2 lines=overlap/footprint;
    float seam=max(lines.x,lines.y);
    float grain=texture(ceramic_grain,world_point.xz*.7).r;
    vec3 body=porcelain.rgb*(0.86+grain*.25);
    ALBEDO=mix(body,body*.20,seam);
    ROUGHNESS=mix(surface_roughness+grain*.05,.76,seam);
    METALLIC=surface_metalness;
    SPECULAR=.55;
    // Controlled indirect bounce retains joint/material readability in the
    // sealed room. Direct light, occlusion and reflection still own form.
    EMISSION=ALBEDO*.055;
}
