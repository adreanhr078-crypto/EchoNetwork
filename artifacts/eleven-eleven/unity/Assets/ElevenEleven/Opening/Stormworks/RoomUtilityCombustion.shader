Shader "ElevenEleven/Room Utility Combustion"
{
    Properties
    {
        _UtilityPhase("Flame clock", Float) = 0
        _UtilityLoad("Pilot flow", Float) = 1
        [Toggle(_UTILITY_SMOKE)] _Smoke("Smoke particle", Float) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent+3" "RenderType"="Transparent" }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma shader_feature_local_fragment _UTILITY_SMOKE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _UtilityPhase, _UtilityLoad;
            CBUFFER_END

            struct Input { float3 positionOS : POSITION; half4 color : COLOR; float2 uv : TEXCOORD0; };
            struct Output { float4 positionCS : SV_POSITION; half4 color : COLOR; float2 uv : TEXCOORD0; };

            Output Vert(Input input)
            {
                Output output;
                output.positionCS = TransformObjectToHClip(input.positionOS);
                output.color = input.color;
                output.uv = input.uv;
                return output;
            }

            float RandomValue(float2 p)
            {
                p = frac(p * float2(0.1031, 0.11369));
                p += dot(p, p.yx + 19.19);
                return frac(p.x * p.y);
            }

            float Noise(float2 p)
            {
                float2 origin = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                return lerp(lerp(RandomValue(origin), RandomValue(origin + float2(1,0)), f.x),
                    lerp(RandomValue(origin + float2(0,1)), RandomValue(origin + 1.0), f.x), f.y);
            }

            half4 Frag(Output input) : SV_Target
            {
                float2 uv = input.uv;
                #if defined(_UTILITY_SMOKE)
                    float2 offset = uv * 2.0 - 1.0;
                    half densityNoise = Noise(uv * 6.1) * 0.7h + Noise(uv * 13.4) * 0.3h;
                    half opacity = saturate(1.0h - dot(offset, offset)) * densityNoise;
                    return half4(input.color.rgb, input.color.a * opacity * opacity);
                #else
                    float load = _UtilityLoad;
                    float h = uv.y / max(0.01, load);
                    float time = _UtilityPhase;
                    float lean = 0.17 * h * h + (Noise(float2(h * 4.2 - time * 4.7, 3.7)) - 0.5) * 0.37 * h;
                    float x = uv.x * 2.0 - 1.0 - lean;
                    float envelope = (0.46 + 0.10 * sin(h * PI)) * saturate(1.10 - h * 0.92);
                    float buoyancy = Noise(float2(x * 7.6, h * 7.2 - time * 5.1)) * 0.69 +
                        Noise(float2(x * 13.6 + time * 0.6, h * 12.4 - time * 9.3)) * 0.31;
                    float distanceFromCore = abs(x + (buoyancy - 0.52) * 0.37 * h);
                    half body = 1.0h - smoothstep(envelope * 0.18, envelope + 0.09, distanceFromCore);
                    half tornTip = 1.0h - smoothstep(0.64, 1.01, h + (0.58 - buoyancy) * 0.53);
                    half alpha = body * tornTip * smoothstep(0.0, 0.055, h) *
                        smoothstep(0.12, 0.45, load) * (0.63h + 0.36h * buoyancy);
                    half heat = saturate(body * 0.69h + (1.0h - h) * 0.43h + (buoyancy - 0.36h) * 0.48h);
                    half3 color = lerp(half3(1.08h, 0.20h, 0.036h), half3(2.70h, 1.44h, 0.42h), heat);
                    half blueBase = (1.0h - smoothstep(0.04, 0.15, h)) * body;
                    color = lerp(color, half3(0.20h, 0.64h, 1.43h), blueBase * 0.67h);
                    return half4(color, alpha);
                #endif
            }
            ENDHLSL
        }
    }
}
