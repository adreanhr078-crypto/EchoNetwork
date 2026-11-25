Shader "ElevenEleven/Station Atmosphere"
{
    Properties
    {
        [HDR] _Tint("Emission", Color) = (0.6,0.8,1,1)
        _Effect("0 Steam / 1 Burner / 2 Arc / 3 Runnel", Range(0,3)) = 0
        _Phase("Variation", Float) = 0
        _PressureVent("Driven by pressure", Range(0,1)) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
        Pass
        {
            Tags { "LightMode"="UniversalForwardOnly" }
            Cull Off
            ZTest LEqual
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile_fog
            #include "UnityCG.cginc"

            CBUFFER_START(UnityPerMaterial)
                half4 _Tint;
                float _Effect;
                float _Phase;
                float _PressureVent;
            CBUFFER_END
            float _EchoSurfaceClock;
            float _EchoAirLoad;
            float _EchoRelayCharge;

            struct Attributes { float3 position : POSITION; float2 uv : TEXCOORD0; };
            struct Raster { float4 position : SV_POSITION; float2 uv : TEXCOORD0; UNITY_FOG_COORDS(1) };

            Raster Vertex(Attributes i)
            {
                Raster o;
                o.position = UnityObjectToClipPos(i.position);
                o.uv = i.uv;
                UNITY_TRANSFER_FOG(o, o.position);
                return o;
            }

            float NoisePoint(float2 p)
            {
                return frac(sin(dot(p, float2(43.21, 91.37))) * 21453.692);
            }

            float Noise(float2 p)
            {
                float2 i = floor(p);
                float2 w = smoothstep(0, 1, frac(p));
                return lerp(lerp(NoisePoint(i), NoisePoint(i + float2(1, 0)), w.x),
                    lerp(NoisePoint(i + float2(0, 1)), NoisePoint(i + 1), w.x), w.y);
            }

            half4 Fragment(Raster input) : SV_Target
            {
                float y = input.uv.y;
                float x = input.uv.x * 2.0 - 1.0;
                float t = _EchoSurfaceClock + _Phase;
                float gust = sin(t * 0.72) * 0.17 + sin(t * 1.67 + 2.7) * 0.08;
                float taper = smoothstep(0.0, 0.19, y) * (1.0 - smoothstep(0.44, 0.99, y));
                half3 tint = _Tint.rgb;
                float alpha;
                if (_Effect < 0.5)
                {
                    float w = lerp(0.16, 0.67, y);
                    float center = gust * y * y + (Noise(float2(y * 3.0, t * 0.85)) - 0.5) * y * 0.32;
                    float density = Noise(float2(x * 6.2, y * 4.4 - t * 0.74)) * 0.58 +
                        Noise(float2(x * 13.4, y * 10.1 - t * 1.94)) * 0.42;
                    alpha = (1.0 - smoothstep(w * 0.45, w, abs(x - center))) * taper * density;
                    alpha *= lerp(1.0, 0.18 + 0.82 * _EchoAirLoad, _PressureVent);
                }
                else if (_Effect < 1.5)
                {
                    float width = 0.35 * pow(saturate(1.0 - y), 0.82);
                    float edge = abs(x + gust * y + 0.23 * (Noise(float2(y * 8.0 - t * 4.0, x * 3.5)) - 0.5));
                    alpha = (1.0 - smoothstep(width * 0.24, width, edge)) * taper;
                    tint *= lerp(2.8h, 0.75h, y);
                }
                else if (_Effect < 2.5)
                {
                    float arc = (Noise(float2(y * 17.0, t * 15.0)) - 0.5) * 0.54 * sin(y * 3.14159265);
                    float core = abs(x - arc);
                    float flicker = lerp(0.28, 1.0, Noise(float2(t * 18.0, 7.4)));
                    alpha = (1.0 - smoothstep(0.012, 0.13, core)) * taper * flicker * _EchoRelayCharge;
                    tint *= lerp(4.2h, 1.0h, saturate(core * 18.0h));
                }
                else
                {
                    float fall = y * 7.0 + t * 4.5;
                    float runnel = Noise(float2(x * 16.0, fall * 0.47)) * 0.52 +
                        Noise(float2(x * 43.0 + gust, fall * 1.23)) * 0.48;
                    float course = (Noise(float2(y * 2.1, t * 0.22)) - 0.5) * (1.0 - y) * 0.26;
                    float width = lerp(0.69, 0.43, y);
                    float coverage = 1.0 - smoothstep(width * 0.32, width, abs(x - course));
                    float ends = smoothstep(0.0, 0.11, y) * (1.0 - smoothstep(0.94, 1.0, y));
                    alpha = coverage * ends * smoothstep(0.18, 0.80, runnel);
                    tint *= 0.59 + runnel * 0.90;
                }
                UNITY_APPLY_FOG(input.fogCoord, tint);
                return half4(tint, saturate(alpha * _Tint.a));
            }
            ENDHLSL
        }
    }
}

