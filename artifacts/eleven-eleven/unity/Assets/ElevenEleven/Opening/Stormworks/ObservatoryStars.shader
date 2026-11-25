Shader "ElevenEleven/Observatory Stars"
{
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Geometry-50" "RenderType"="Opaque" }
        Cull Front
        ZWrite On
        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Input { float3 positionOS : POSITION; };
            struct Output { float4 positionCS : SV_POSITION; float3 view : TEXCOORD0; };
            Output Vert(Input input)
            {
                Output output;
                output.positionCS = TransformObjectToHClip(input.positionOS);
                output.view = TransformObjectToWorld(input.positionOS) - GetCameraPositionWS();
                return output;
            }

            float Hash(float3 p)
            {
                p = frac(p * 0.3183099 + float3(.12,.31,.27)) * 19.13;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            float Nebula(float3 p)
            {
                float3 c = floor(p), f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                float low = lerp(lerp(Hash(c),Hash(c+float3(1,0,0)), f.x),
                    lerp(Hash(c+float3(0,1,0)),Hash(c+float3(1,1,0)),f.x),f.y);
                float high = lerp(lerp(Hash(c+float3(0,0,1)),Hash(c+float3(1,0,1)),f.x),
                    lerp(Hash(c+float3(0,1,1)),Hash(c+1),f.x),f.y);
                return lerp(low,high,f.z);
            }

            float Stars(float3 ray, float scale, float threshold, float size)
            {
                float3 cell = floor(ray * scale);
                float seed = Hash(cell);
                float3 offset = .25 + float3(Hash(cell+17.1),Hash(cell-8.7),Hash(cell+34.1)) * .5;
                float distance = length(frac(ray * scale) - offset);
                float aa = min(.045, fwidth(distance));
                return (1.0 - smoothstep(size, size+aa, distance)) * step(threshold,seed) *
                    (.23 + .72 * Hash(cell + 27.7));
            }

            half4 Frag(Output input) : SV_Target
            {
                float3 ray = normalize(input.view);
                float filament = Nebula(ray * 7.3 + float3(0,2,4)) * .58 +
                    Nebula(ray * 17.5 - 0.17) * .29 + Nebula(ray * 41.0 + 4.9) * .13;
                float plane = exp(-8.2 * abs(ray.y - ray.x * .4 - .35 + .24 * (filament - .5)));
                float blue = smoothstep(.30,.85,filament) * plane;
                float violet = pow(saturate((filament-.31) * 1.55), 2.8) * plane;
                float uplight = smoothstep(-.10,.47,ray.y);
                half3 color = lerp(half3(.019,.036,.058),half3(.008,.014,.031),uplight);
                color += blue * half3(.043,.085,.29);
                color += violet * half3(.31,.089,.48);
                color += Stars(ray, 125.0, .86, .098) * half3(.42,.64,1.0);
                color += Stars(ray, 54.0, .965, .094) * half3(.98,.79,.72);
                color += Stars(ray, 176.0, .88, .067) * half3(.115,.23,.39);
                return half4(color,1);
            }
            ENDHLSL
        }
    }
}
