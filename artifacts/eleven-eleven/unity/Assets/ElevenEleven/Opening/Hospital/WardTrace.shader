Shader "ElevenEleven/Ward Trace"
{
    Properties
    {
        [NoScaleOffset] _MainTex("Trace", 2D) = "white" {}
        [HDR] _TraceColor("Tint", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent+12" }
        Pass
        {
            Cull Off
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            CBUFFER_START(UnityPerMaterial)
                half4 _TraceColor;
            CBUFFER_END
            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; };
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; };
            Varyings Vertex(Attributes input)
            {
                Varyings result;
                result.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                result.uv = input.uv;
                return result;
            }
            half4 Fragment(Varyings input) : SV_Target
            {
                half4 texel = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                return texel * _TraceColor;
            }
            ENDHLSL
        }
    }
}
