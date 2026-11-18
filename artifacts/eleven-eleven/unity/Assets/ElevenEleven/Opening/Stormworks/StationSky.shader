Shader "ElevenEleven/Station Sky"
{
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
        Pass
        {
            Cull Off
            ZWrite Off
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            float _EchoSurfaceClock;
            struct SkyVertex { float3 positionOS : POSITION; };
            struct SkyRaster { float4 positionCS : SV_POSITION; float3 direction : TEXCOORD0; };
            SkyRaster Vertex(SkyVertex input)
            {
                SkyRaster output;
                output.positionCS = TransformObjectToHClip(input.positionOS);
                output.direction = input.positionOS;
                return output;
            }

            half4 Fragment(SkyRaster input) : SV_Target
            {
                float3 d = normalize(input.direction);
                half height = saturate(d.y * 2.3 + 0.16);
                half3 color = lerp(half3(0.041h, 0.143h, 0.29h), half3(0.008h, 0.011h, 0.052h), height);
                float t = _EchoSurfaceClock * 0.13;
                float wave = 0.19 + 0.09 * sin(d.x * 4.8 + t) + 0.025 * sin(d.x * 13.9 - t * 0.6);
                half body = exp(-19.0 * abs(d.y - wave));
                half crest = exp(-62.0 * abs(d.y - wave + 0.082));
                half variation = saturate(0.46h + 0.38h * sin(d.x * 7.3h + t));
                half3 glow = lerp(half3(0.19h, 0.018h, 0.35h), half3(0.018h, 0.29h, 0.29h), variation);
                color += body * glow * 0.69h;
                color += crest * half3(0.014h, 0.14h, 0.26h) * saturate(d.z * 1.3h);
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}
