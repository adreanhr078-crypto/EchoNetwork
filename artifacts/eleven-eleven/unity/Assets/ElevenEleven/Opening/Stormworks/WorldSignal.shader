Shader "ElevenEleven/World Signal"
{
    Properties
    {
        _BaseMap("Lettering", 2D) = "white" {}
        [HDR] _BaseColor("Tint", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
        Pass
        {
            Tags { "LightMode"="UniversalForwardOnly" }
            Cull Off
            ZTest LEqual
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
            CBUFFER_END

            struct VertexInput { float3 position : POSITION; float2 uv : TEXCOORD0; };
            struct Raster { float4 position : SV_POSITION; float2 uv : TEXCOORD0; half fog : TEXCOORD1; };

            Raster Vertex(VertexInput input)
            {
                Raster output;
                output.position = TransformObjectToHClip(input.position);
                output.uv = input.uv;
                output.fog = ComputeFogFactor(output.position.z);
                return output;
            }

            half4 Fragment(Raster input) : SV_Target
            {
                half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a;
                return half4(MixFog(_BaseColor.rgb, input.fog), alpha * _BaseColor.a);
            }
            ENDHLSL
        }
    }
}
