Shader "ElevenEleven/Practical Light Scattering"
{
    Properties
    {
        [HDR] _Tint("Scattered light", Color) = (1,0.9,0.75,1)
        _Density("Density", Range(0,0.25)) = 0.08
        _SoftIntersection("Intersection softness in metres", Float) = 0.42
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent-9" "RenderType"="Transparent" }
        Pass
        {
            Name "Practical light depth fade"
            Tags { "LightMode"="UniversalForwardOnly" }
            Cull Off
            ZWrite Off
            ZTest LEqual
            Blend One One
            ColorMask RGB

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _Tint;
                half _Density;
                float _SoftIntersection;
            CBUFFER_END

            float _EchoSurfaceClock;

            struct Attributes
            {
                float3 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float viewDepth : TEXCOORD1;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs position = GetVertexPositionInputs(input.positionOS);
                output.positionCS = position.positionCS;
                output.viewDepth = -position.positionVS.z;
                output.uv = input.uv;
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float sceneDepth = LinearEyeDepth(SampleSceneDepth(GetNormalizedScreenSpaceUV(input.positionCS)), _ZBufferParams);
                float clipped = saturate((sceneDepth - input.viewDepth) / max(_SoftIntersection, 0.05));
                float nearFade = smoothstep(0.40, 1.35, input.viewDepth);
                float core = 1.0 - smoothstep(0.03, 1.0, abs(input.uv.x * 2.0 - 1.0));
                float falloff = smoothstep(0.0, 0.12, input.uv.y) *
                    (1.0 - smoothstep(0.30, 1.0, input.uv.y));
                float air = 0.87 + 0.13 * sin(input.uv.y * 21.0 + input.uv.x * 13.0 - _EchoSurfaceClock * 0.62);
                return half4(_Tint.rgb * (_Density * clipped * nearFade * core * falloff * air), 0.0);
            }
            ENDHLSL
        }
    }
}
