Shader "ElevenEleven/Station Reflection"
{
    Properties
    {
        [NoScaleOffset] _ReflectionMap("Planar color", 2D) = "black" {}
        _ReflectionReady("Planar color present", Float) = 0
        _Fracture("Transient optical shift", Range(0,1)) = 0
        _Reflectance("Mirror reflectance", Color) = (0.60, 0.80, 0.92, 1)
        _RimColor("Glass rim", Color) = (0.06, 0.16, 0.23, 1)
        _BaseTint("Glass base", Color) = (0.015, 0.031, 0.066, 1)
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
                half _Fracture;
                half4 _Reflectance;
                half4 _RimColor;
                half4 _BaseTint;
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
                float scan = sin(input.glassUV.y * 93.0 + _Time.y * 16.0);
                uv.x += scan * 0.0016 * _Fracture;
                half3 sceneColor = SAMPLE_TEXTURE2D(_ReflectionMap, sampler_ReflectionMap, uv).rgb;
                float2 edge = min(input.glassUV, 1.0 - input.glassUV);
                half rim = (1.0h - smoothstep(0.003h, 0.08h, min(edge.x, edge.y)));
                half3 reflected = sceneColor * _Reflectance.rgb;
                half3 glass = _BaseTint.rgb + reflected * _ReflectionReady + rim * _RimColor.rgb;
                half seam = 1.0h - smoothstep(0.0h, 0.04h, abs(input.glassUV.y - 0.57h - 0.03h * scan));
                glass += _Fracture * seam * half3(0.14h, 0.045h, 0.19h);
                return half4(MixFog(glass, input.fog), 1.0h);
            }
            ENDHLSL
        }
    }
}
