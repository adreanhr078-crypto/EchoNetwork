Shader "ElevenEleven/Containment Optics"
{
    Properties
    {
        [HDR] _Tint("Medium color", Color) = (0.04, 0.65, 0.7, 0.42)
        _Mode("Glass · Liquid · Projection · Conductor · Dielectric", Range(0, 4)) = 0
        _Phase("Variation", Float) = 0
        _ProjectionViewFade("Projection near and full distance", Vector) = (0, 0, 0, 0)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
        Pass
        {
            Tags { "LightMode"="UniversalForwardOnly" }
            Cull Back
            ZWrite Off
            ZTest LEqual
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            CBUFFER_START(UnityPerMaterial)
                half4 _Tint;
                float _Mode;
                float _Phase;
                float4 _ProjectionViewFade;
            CBUFFER_END
            float _EchoSurfaceClock;
            float _EchoRelayCharge;

            struct Attributes { float3 positionOS : POSITION; float3 normalOS : NORMAL; float2 uv : TEXCOORD0; };
            struct Raster
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
                half fog : TEXCOORD3;
            };
            Raster Vertex(Attributes input)
            {
                Raster o;
                VertexPositionInputs p = GetVertexPositionInputs(input.positionOS);
                o.positionCS = p.positionCS;
                o.positionWS = p.positionWS;
                o.normalWS = TransformObjectToWorldNormal(input.normalOS);
                o.uv = input.uv;
                o.fog = ComputeFogFactor(p.positionCS.z);
                return o;
            }
            float Hash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }
            half4 Fragment(Raster input) : SV_Target
            {
                half3 view = GetWorldSpaceNormalizeViewDir(input.positionWS);
                half3 n = normalize(input.normalWS);
                half fresnel = pow(1.0h - saturate(dot(n, view)), 3.2h);
                half3 color = _Tint.rgb;
                float alpha;
                float t = _EchoSurfaceClock + _Phase;
                float y = input.uv.y;
                float u = input.uv.x;
                if (_Mode < 0.5)
                {
                    half strips = pow(saturate(0.56h + 0.44h * cos((u + y * 0.19h) * 33.0h)), 16.0h);
                    color *= 0.82h + 0.7h * fresnel + strips * 0.52h;
                    alpha = _Tint.a * (0.17 + 0.76 * fresnel + 0.21 * strips);
                }
                else if (_Mode < 1.5)
                {
                    float2 cells = float2(u * 31 + sin(y * 13 + t * 0.9) * 0.24, y * 11 - t * 0.91);
                    float2 tile = floor(cells);
                    float2 local = frac(cells) - 0.5;
                    float dotRadius = lerp(0.07, 0.18, Hash(tile + 1.51));
                    half bubble = (1.0 - smoothstep(dotRadius * 0.65, dotRadius, length(local)))
                        * smoothstep(0.47, 0.79, Hash(tile));
                    half band = 0.5h + 0.5h * sin(u * 27.3 + y * 14.7 + t * 1.6 + 1.25 * sin(y * 8.7 - t));
                    color *= lerp(0.47h, 1.13h, band);
                    color += bubble * _Tint.rgb * 1.9h;
                    alpha = min(0.82, _Tint.a * (0.68 + 0.17 * band + bubble * 0.41 + 0.19 * fresnel));
                }
                else if (_Mode < 2.5)
                {
                    float3 p = input.positionWS;
                    float spokes = pow(saturate(0.5 + 0.5 * sin((p.x + p.z * 0.33) * 14 + sin(p.y * 1.7 - t * 0.9))), 7);
                    float bands = pow(saturate(0.5 + 0.5 * sin(p.y * 21 - t * 2.0)), 8);
                    color *= 0.82h + 0.75h * spokes + 0.66h * bands;
                    alpha = _Tint.a * (0.12 + 0.29 * spokes + 0.38 * bands + 0.22 * fresnel);
                }
                else if (_Mode < 3.5)
                {
                    half traces = pow(saturate(0.5h + 0.5h * sin(u * 48.0 - t * 1.25)), 7.0h);
                    color *= 0.63h + 0.44h * fresnel + 0.26h * traces;
                    alpha = _Tint.a * (0.42h + 0.32h * fresnel + 0.19h * traces);
                }
                else
                {
                    float axial = saturate(y);
                    float phase = u * 18.849556 + 1.27 * sin(axial * 16.3 - t * 1.32) - t * 1.18;
                    float thread = pow(saturate(0.5 + 0.5 * cos(phase)), 19.0);
                    float travel = 0.55 + 0.45 * sin(axial * 28.0 - t * 2.1);
                    float charge = saturate(_EchoRelayCharge);
                    float taper = smoothstep(0.0, 0.12, axial) * (1.0 - smoothstep(0.86, 1.0, axial));
                    float discharge = thread * travel * taper * charge;
                    color = _Tint.rgb * (0.19h + 0.23h * fresnel + charge * 0.14h);
                    color += half3(0.26h, 0.93h, 1.09h) * discharge * 0.58h;
                    alpha = _Tint.a * (0.22 + 0.42 * fresnel) + 0.48 * discharge;
                }
                if (_Mode >= 1.5 && _ProjectionViewFade.y > _ProjectionViewFade.x)
                {
                    float eyeDistance = distance(GetCameraPositionWS(), input.positionWS);
                    alpha *= smoothstep(_ProjectionViewFade.x, _ProjectionViewFade.y, eyeDistance);
                }
                return half4(MixFog(color, input.fog), saturate(alpha));
            }
            ENDHLSL
        }
    }
}

