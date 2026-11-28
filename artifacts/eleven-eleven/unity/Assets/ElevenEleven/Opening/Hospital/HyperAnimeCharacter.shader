Shader "ElevenEleven/Hyper Anime Character"
{
    Properties
    {
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor("Base Color", Color) = (0.94, 0.92, 0.92, 1)
        _ShadowColor("Shadow Tint", Color) = (0.72, 0.69, 0.79, 1)
        _ShadowOffset("Shadow Threshold", Range(-0.5, 0.5)) = -0.02
        _ShadowFeather("Shadow Softness", Range(0.02, 0.6)) = 0.16
        _RimColor("Rim Color", Color) = (0.58, 0.84, 1.0, 1)
        _RimPower("Rim Power", Range(1.5, 8.0)) = 3.8
        _RimStrength("Rim Strength", Range(0.0, 1.5)) = 0.36
        _HairSheen("Hair Highlight", Range(0.0, 1.0)) = 0.22
        _OutlineDarken("Edge Ink Strength", Range(0.0, 0.8)) = 0.22
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "HyperAnimeForward"
            Tags { "LightMode" = "UniversalForward" }
            Cull Back
            ZWrite On

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _ShadowColor;
                half _ShadowOffset;
                half _ShadowFeather;
                half4 _RimColor;
                half _RimPower;
                half _RimStrength;
                half _HairSheen;
                half _OutlineDarken;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
                half fogFactor : TEXCOORD3;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings Vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normInputs = GetVertexNormalInputs(input.normalOS);
                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;
                output.normalWS = normInputs.normalWS;
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.fogFactor = ComputeFogFactor(posInputs.positionCS.z);
                return output;
            }

            half3 EvalAnimeLight(Light light, half3 N, half3 V, half3 albedo, half darkMask)
            {
                half ndotl = dot(N, light.direction);
                half halfLambert = ndotl * 0.5h + 0.5h + _ShadowOffset;
                half atten = light.distanceAttenuation * light.shadowAttenuation;
                half ramp = smoothstep(0.5h - _ShadowFeather, 0.5h + _ShadowFeather, halfLambert * lerp(0.55h, 1.0h, atten));
                half3 litTerm = lerp(albedo * _ShadowColor.rgb, albedo, ramp);

                // Controlled silky hair sheen gated to darker tones (hair/suit), leaving skin smooth and matte
                half3 H = SafeNormalize(light.direction + V);
                half ndoth = saturate(dot(N, H));
                half spec = pow(ndoth, 18.0h) * _HairSheen * darkMask * smoothstep(0.35h, 0.85h, ramp);
                half lightLum = dot(light.color, half3(0.2126h, 0.7152h, 0.0722h));
                half3 radiance = light.color * saturate(atten);
                return litTerm * radiance + light.color * (spec * saturate(atten) * saturate(lightLum));
            }

            half4 Frag(Varyings input) : SV_Target
            {
                half4 texSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 albedo = texSample.rgb * _BaseColor.rgb;
                half texLum = dot(texSample.rgb, half3(0.299h, 0.587h, 0.114h));
                half darkMask = 1.0h - smoothstep(0.22h, 0.52h, texLum);

                half3 N = SafeNormalize(input.normalWS);
                half3 V = GetWorldSpaceNormalizeViewDir(input.positionWS);
                half ndotv = saturate(dot(N, V));

                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                half3 direct = EvalAnimeLight(mainLight, N, V, albedo, darkMask);

                #if defined(_ADDITIONAL_LIGHTS)
                    InputData inputData = (InputData)0;
                    inputData.positionWS = input.positionWS;
                    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                    uint lightCount = GetAdditionalLightsCount();
                    #if USE_CLUSTER_LIGHT_LOOP
                        [loop]
                        for (uint li = 0u; li < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); ++li)
                        {
                            CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK
                            Light l = GetAdditionalLight(li, input.positionWS, half4(1, 1, 1, 1));
                            direct += EvalAnimeLight(l, N, V, albedo, darkMask);
                        }
                    #endif
                    LIGHT_LOOP_BEGIN(lightCount)
                        Light l = GetAdditionalLight(lightIndex, input.positionWS, half4(1, 1, 1, 1));
                        direct += EvalAnimeLight(l, N, V, albedo, darkMask);
                    LIGHT_LOOP_END
                #endif

                half3 sh = max(SampleSH(N), half3(0.18h, 0.19h, 0.22h));
                half3 ambient = albedo * (sh * 0.58h + half3(0.10h, 0.10h, 0.12h));

                // Clean anime silhouette rim light
                half fresnel = pow(1.0h - ndotv, _RimPower);
                half upward = saturate(N.y * 0.5h + 0.5h);
                half3 rim = _RimColor.rgb * (fresnel * _RimStrength * lerp(0.45h, 1.0h, upward));

                // Subtle crisp ink stroke along grazing silhouette edges
                half ink = 1.0h - _OutlineDarken * (1.0h - smoothstep(0.06h, 0.22h, ndotv));

                half3 finalCol = (ambient + direct) * ink + rim;
                finalCol = MixFog(finalCol, input.fogFactor);
                return half4(finalCol, 1.0h);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;

            struct ShadowAttr
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct ShadowVar
            {
                float4 positionCS : SV_POSITION;
            };

            ShadowVar ShadowVert(ShadowAttr input)
            {
                ShadowVar o;
                float3 posWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normWS = TransformObjectToWorldNormal(input.normalOS);
                o.positionCS = TransformWorldToHClip(ApplyShadowBias(posWS, normWS, _LightDirection));
                #if UNITY_REVERSED_Z
                    o.positionCS.z = min(o.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    o.positionCS.z = max(o.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif
                return o;
            }

            half4 ShadowFrag(ShadowVar input) : SV_Target { return 0; }
            ENDHLSL
        }
    }
}
