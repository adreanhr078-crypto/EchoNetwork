Shader "ElevenEleven/Stormworks Surface"
{
    Properties
    {
        _BaseColor("Base", Color) = (0.12,0.18,0.24,1)
        _ShadowTone("Chromatic shadow", Color) = (0.28,0.16,0.48,1)
        [HDR] _EmissionColor("Signal", Color) = (0,0,0,1)
        _Wetness("Water coverage", Range(0,1)) = 0
        _WaterBody("Open body of water", Range(0,1)) = 0
        _WaterShimmer("Water optical shimmer", Range(0,1)) = 1
        _PanelScale("Panel frequency", Float) = 0.7
        [Toggle(_EXAMINATION_DETAIL)] _ExaminationDetail("Examination finish", Float) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        Pass
        {
            Name "StormworksForward"
            Tags { "LightMode"="UniversalForwardOnly" }
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma shader_feature_local_fragment _EXAMINATION_DETAIL
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _ShadowTone;
                half4 _EmissionColor;
                float _Wetness;
                float _PanelScale;
                float _WaterBody;
                float _WaterShimmer;
            CBUFFER_END

            float _EchoSurfaceClock;
            float4 _EchoSurfaceContact;


            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                half fog : TEXCOORD2;
            };

            Varyings Vertex(Attributes input)
            {
                Varyings output;
                VertexPositionInputs p = GetVertexPositionInputs(input.positionOS);
                output.positionWS = p.positionWS;
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.positionCS = p.positionCS;
                output.fog = ComputeFogFactor(output.positionCS.z);
                return output;
            }

            half3 Direct(Light light, half3 n, half3 v, half3 paint, half wet)
            {
                half nl = dot(n, light.direction);
                half band = 0.15h + 0.35h * smoothstep(-0.055h, 0.09h, nl) + 0.50h * smoothstep(0.42h, 0.59h, nl);
                half3 mirror = normalize(light.direction + v + half3(0.0001h, 0, 0));
                half specular = pow(saturate(dot(n, mirror)), lerp(20.0h, 72.0h, wet)) * lerp(0.12h, 0.28h, wet);
                return (paint * band + specular) * light.color * light.distanceAttenuation * light.shadowAttenuation;
            }

            half4 Fragment(Varyings input) : SV_Target
            {
                float3 p = input.positionWS;
                half3 n = normalize(input.normalWS);
                half3 view = GetWorldSpaceNormalizeViewDir(p);
                float2 xy = abs(n.y) > 0.55 ? p.xz : (abs(n.x) > 0.55 ? p.zy : p.xy);
                float2 grid = abs(frac(xy * max(0.01, _PanelScale)) - 0.5);
                float seam = max(grid.x, grid.y);
                float joint = lerp(1.0 - smoothstep(0.485, 0.495 + fwidth(seam), seam), 1.0, _WaterBody);
                float scuff = sin(dot(xy, float2(31.7, -17.4))) * sin(dot(xy, float2(7.8, 25.1)));
                half3 paint = _BaseColor.rgb * (0.75h + 0.25h * joint + 0.011h * scuff);
                #if defined(_EXAMINATION_DETAIL)
                float footprint = max(length(ddx(xy)), length(ddy(xy)));
                float grain = sin(xy.x * 91.7 + sin(xy.y * 42.3)) * sin(xy.y * 117.1);
                half aggregate = 0.018h * grain * (1.0h - smoothstep(0.009h, 0.032h, footprint));
                half panelVariation = 0.045h * sin(dot(floor(xy * _PanelScale), float2(2.61, 6.74)));
                paint *= 1.0h + aggregate + panelVariation;
                #endif

                float mask = smoothstep(-0.47, 0.48, sin(p.x * 0.38 + cos(p.z * 0.44)) + cos(p.z * 0.67));
                half wet = _Wetness * lerp(mask, 1.0, _WaterBody) * saturate(n.y);
                float t = _EchoSurfaceClock;
                float2 k1 = float2(1.94, 0.76);
                float2 k2 = float2(-0.63, 3.14);
                float2 k3 = float2(4.09, -1.89);
                float a = dot(p.xz, k1) - t * 2.29;
                float b = dot(p.xz, k2) - t * 2.61 + 0.34 * sin(a);
                float c = dot(p.xz, k3) - t * 3.05;
                float2 slope = 0.046 * cos(a) * k1 + 0.024 * cos(b) * k2 + 0.010 * cos(c) * k3;
                slope *= lerp(0.31, 1.0, _WaterBody);
                n = normalize(n + wet * half3(-slope.x, 0, -slope.y));
                half rim = pow(1.0h - saturate(dot(n, view)), 4.0h);
                half3 reflected = reflect(-view, n);
                half spectral = 0.5h + 0.5h * sin(p.x * 0.14h + p.z * 0.047h + reflected.x * 1.6h);
                half3 chroma = lerp(half3(0.015h, 0.31h, 0.43h), half3(0.28h, 0.021h, 0.44h), spectral);
                half3 color = paint * (_ShadowTone.rgb + 0.21h);
                color += wet * chroma * rim * lerp(0.38h, 0.63h * _WaterShimmer, _WaterBody);
                float focus = pow(saturate(0.53 + 0.24 * sin(a * 2.9 + cos(b)) + 0.23 * cos(b * 2.1 + sin(c))), 9.0);
                color += half3(0.025h, 0.22h, 0.17h) * focus * wet * _WaterBody * _WaterShimmer;
                float age = max(0.0, t - _EchoSurfaceContact.z);
                float d = distance(p.xz, _EchoSurfaceContact.xy);
                float ring = exp(-75.0 * pow(d - age * 2.15, 2.0)) * saturate(1.0 - age * 1.7);
                color += wet * ring * _EchoSurfaceContact.w * half3(0.17h, 0.36h, 0.41h);

                color += Direct(GetMainLight(TransformWorldToShadowCoord(p)), n, view, paint, wet);
                #if defined(_ADDITIONAL_LIGHTS)
                InputData inputData = (InputData)0;
                inputData.positionWS = p;
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                #if USE_CLUSTER_LIGHT_LOOP
                UNITY_LOOP for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); ++lightIndex)
                {
                    CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK
                    color += Direct(GetAdditionalLight(lightIndex, p, half4(1,1,1,1)), n, view, paint, wet);
                }
                #endif
                uint count = GetAdditionalLightsCount();
                LIGHT_LOOP_BEGIN(count)
                    color += Direct(GetAdditionalLight(lightIndex, p, half4(1,1,1,1)), n, view, paint, wet);
                LIGHT_LOOP_END
                #endif
                color += _EmissionColor.rgb;
                return half4(MixFog(color, input.fog), 1);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
