Shader "ElevenEleven/Station Reflection"
{
    Properties
    {
        [NoScaleOffset] _ReflectionMap("Planar color", 2D) = "black" {}
        _ReflectionReady("Planar color present", Float) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry+2" }
        Pass
        {
            Tags { "LightMode"="UniversalForwardOnly" }
            Cull Off
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            TEXTURE2D(_ReflectionMap);
            SAMPLER(sampler_ReflectionMap);
            CBUFFER_START(UnityPerMaterial)
                float _ReflectionReady;
            CBUFFER_END

            struct Attributes { float3 positionOS : POSITION; float2 texcoord : TEXCOORD0; };
            struct Varyings { float4 positionCS : SV_POSITION; float2 glassUV : TEXCOORD0; half fog : TEXCOORD1; };

            Varyings Vertex(Attributes input)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(input.positionOS);
                o.glassUV = input.texcoord;
                o.fog = ComputeFogFactor(o.positionCS.z);
                return o;
            }

            half4 Fragment(Varyings input) : SV_Target
            {
                float2 uv = GetNormalizedScreenSpaceUV(input.positionCS);
                uv.x = 1.0 - uv.x;
                half3 sceneColor = SAMPLE_TEXTURE2D(_ReflectionMap, sampler_ReflectionMap, uv).rgb;
                float2 edge = min(input.glassUV, 1.0 - input.glassUV);
                half rim = (1.0h - smoothstep(0.003h, 0.08h, min(edge.x, edge.y)));
                half3 tint = half3(0.015h, 0.031h, 0.066h);
                half3 reflected = sceneColor * half3(0.60h, 0.80h, 0.92h);
                half3 glass = tint + reflected * _ReflectionReady + rim * half3(0.06h, 0.16h, 0.23h);
                return half4(MixFog(glass, input.fog), 1.0h);
            }
            ENDHLSL
        }
    }
}
