Shader "ElevenEleven/Room Utility Water"
{
    Properties
    {
        _UtilityPhase("Surface clock", Float) = 0
        _UtilityLoad("Pressure load", Float) = 1
        _UtilityDrip("Impact XZ, clock and strength", Vector) = (0,0,-10,0)
        _UtilityFootstep("Contact XZ, clock and strength", Vector) = (0,0,-10,0)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent-9" "RenderType"="Transparent" }
        Pass
        {
            Name "ShallowWaterForward"
            Tags { "LightMode"="UniversalForwardOnly" }
            Blend One OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #define _SURFACE_TYPE_TRANSPARENT 1
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _UtilityPhase, _UtilityLoad;
                float4 _UtilityDrip, _UtilityFootstep;
            CBUFFER_END

            struct Input
            {
                float3 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Output
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                half fog : TEXCOORD2;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Output Vert(Input input)
            {
                Output output = (Output)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionWS = TransformObjectToWorld(input.positionOS);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                output.uv = input.uv;
                output.fog = ComputeFogFactor(output.positionCS.z);
                return output;
            }

            // Narrow wave packet with separate phase and group velocities. Different bands
            // separate over time. These parameters use a representative 12 mm film.
            // omega^2 = (9.81*k + (surfaceTension/density)*k^3) * tanh(k*depth).
            float WaveSlope(float radius, float age, float footprint, float pixelSize,
                float waveNumber, float frequency, float groupVelocity, float height)
            {
                float width = footprint + 0.025 * age;
                float front = radius - age * groupVelocity;
                float q = front / width;
                float spatialFade = exp(-q * q);
                float viscosity = 0.000002 * waveNumber * waveNumber;
                float decay = exp(-(2.25 + viscosity) * age);
                float spreading = rsqrt(1.0 + radius / footprint);
                float antialias = 1.0 - smoothstep(0.80, 2.10, waveNumber * pixelSize);

                float phaseSin, phaseCos;
                sincos(radius * waveNumber - frequency * age, phaseSin, phaseCos);
                float envelopeSlope = -2.0 * q / width - 0.5 / (footprint + radius);
                return height * antialias * spatialFade * decay * spreading *
                    (phaseSin * envelopeSlope + phaseCos * waveNumber);
            }

            float2 ImpactSlope(float2 xz, float4 eventData, bool footstep, float pixelSize)
            {
                float age = _UtilityPhase - eventData.z;
                [branch]
                if (eventData.w <= 0.0 || age <= 0.0 || age >= 1.30)
                    return 0.0;

                float2 offset = xz - eventData.xy;
                float radius = length(offset);
                [branch]
                if (radius > 0.17 + age * 0.42)
                    return 0.0;

                float slope;
                if (footstep)
                {
                    slope = WaveSlope(radius, age, 0.065, pixelSize, 37.0, 12.364, 0.3174, 0.0030);
                    slope += WaveSlope(radius, age, 0.040, pixelSize, 60.0, 19.307, 0.2856, 0.0018);
                }
                else
                {
                    slope = WaveSlope(radius, age, 0.041, pixelSize, 92.0, 27.731, 0.2425, 0.0012);
                    slope += WaveSlope(radius, age, 0.023, pixelSize, 170.0, 44.233, 0.1938, 0.00038);
                }

                float envelope = smoothstep(0.0, 0.045, age) * (1.0 - smoothstep(0.85, 1.30, age));
                float2 direction = offset / max(radius, 0.018);
                return direction * (slope * envelope * eventData.w);
            }

            float WaterFresnel(float cosine)
            {
                // Air to water at n = 1.333 gives a normal-incidence reflectance of 0.0204.
                float grazing = 1.0 - saturate(cosine);
                float grazing2 = grazing * grazing;
                return 0.0204 + 0.9796 * grazing2 * grazing2 * grazing;
            }

            float3 LightGlint(Light light, float3 normal, float3 view, float nDotV, float roughness)
            {
                float nDotL = saturate(dot(normal, light.direction));
                float incident = nDotL * light.distanceAttenuation * light.shadowAttenuation;
                [branch]
                if (incident <= 0.0001)
                    return 0.0;

                float3 halfway = SafeNormalize(light.direction + view);
                float nDotH = saturate(dot(normal, halfway));
                float alpha = roughness * roughness;
                float alpha2 = alpha * alpha;
                float distributionDenominator = nDotH * nDotH * (alpha2 - 1.0) + 1.0;
                float distribution = alpha2 / (PI * distributionDenominator * distributionDenominator);
                float visibilityV = nDotL * sqrt(nDotV * nDotV * (1.0 - alpha2) + alpha2);
                float visibilityL = nDotV * sqrt(nDotL * nDotL * (1.0 - alpha2) + alpha2);
                float visibility = 0.5 / max(visibilityV + visibilityL, 0.0001);
                float response = WaterFresnel(dot(view, halfway)) * distribution * visibility;
                return light.color * (min(response, 12.0) * incident);
            }

            half4 Frag(Output input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float2 xz = input.positionWS.xz;
                float2 uvFromCenter = input.uv * 2.0 - 1.0;
                float2 basin = uvFromCenter + float2(0.060 * sin(uvFromCenter.y * 5.3), 0.027 * uvFromCenter.x);
                float contour = length(basin * float2(1.10, 1.12)) +
                    0.030 * sin(dot(uvFromCenter, float2(9.1, 7.6))) +
                    0.014 * sin(dot(uvFromCenter, float2(-18.0, 13.8)));
                float shore = 1.0 - contour;
                float pixelSize = max(length(ddx(xz)), length(ddy(xz)));
                float edgeWidth = max(fwidth(shore), 0.010);
                float coverage = smoothstep(-edgeWidth, 0.078 + edgeWidth, shore);
                clip(coverage - 0.002);

                float centerDepth = smoothstep(0.015, 0.65, shore);
                float waterDepth = 0.0005 + 0.0115 * centerDepth;
                float2 slope = ImpactSlope(xz, _UtilityDrip, false, pixelSize) +
                    ImpactSlope(xz, _UtilityFootstep, true, pixelSize);

                float current = lerp(0.45, 1.0, saturate(_UtilityLoad));
                float drift = cos(dot(xz, float2(14.4, -6.2)) - _UtilityPhase * 4.1);
                float cross = cos(dot(xz, float2(24.2, 16.4)) - _UtilityPhase * 6.9);
                slope += current * (drift * float2(0.010, -0.0043) + cross * float2(0.007, 0.0047));
                slope *= smoothstep(0.012, 0.18, shore);
                float2 outward = SafeNormalize(TransformObjectToWorldDir(float3(uvFromCenter, 0.0), false)).xz;
                float meniscus = smoothstep(0.005, 0.047, shore) * (1.0 - smoothstep(0.050, 0.15, shore));
                slope -= outward * meniscus * 0.022;

                float3 normal = normalize(float3(-slope.x, 1.0, -slope.y));
                float3 view = GetWorldSpaceNormalizeViewDir(input.positionWS);
                float nDotV = saturate(dot(normal, view));
                float fresnel = WaterFresnel(nDotV);
                float roughness = lerp(0.30, 0.18, centerDepth);
                float2 screenUV = GetNormalizedScreenSpaceUV(input.positionCS);
                float3 reflectionRay = reflect(-view, normal);
                float3 reflection = GlossyEnvironmentReflection(reflectionRay,
                    input.positionWS, roughness, 1.0, screenUV);

                // Blend the steel deck through the film. The unequal extinction coefficients
                // give a faint cool cast where a grazing ray takes a longer path in the water.
                float pathLength = waterDepth / max(nDotV, 0.20);
                float3 transmission = exp(-pathLength * float3(3.2, 1.10, 0.68));
                float3 ambient = max(SampleSH(normal), 0.0);
                float3 scatter = ambient * float3(0.13, 0.30, 0.35) * (1.0 - transmission);
                float3 glint = LightGlint(GetMainLight(TransformWorldToShadowCoord(input.positionWS)),
                    normal, view, nDotV, roughness);
                // Broad reflection from the lit viewport and the lower pressure instrument panel.
                float3 lightAnchor = input.positionWS.z < 19.0 ? float3(-7.8, 2.25, 8.7) : float3(-2.95, 1.58, 24.6);
                float3 towardPractical = lightAnchor - input.positionWS;
                float distanceSquared = dot(towardPractical, towardPractical);
                float alignment = saturate(dot(reflectionRay, SafeNormalize(towardPractical)));
                glint += float3(0.20, 0.47, 0.58) * fresnel * exp2(-12.0 * (1.0 - alignment)) /
                    (1.0 + 0.095 * distanceSquared);

                #if defined(_ADDITIONAL_LIGHTS)
                    InputData inputData = (InputData)0;
                    inputData.positionWS = input.positionWS;
                    inputData.normalizedScreenSpaceUV = screenUV;

                    #if USE_CLUSTER_LIGHT_LOOP
                        [loop]
                        for (uint lightIndex = 0u; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); ++lightIndex)
                        {
                            CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK
                            Light light = GetAdditionalLight(lightIndex, input.positionWS, half4(1.0, 1.0, 1.0, 1.0));
                            glint += LightGlint(light, normal, view, nDotV, roughness);
                        }
                    #endif

                    uint lightCount = GetAdditionalLightsCount();
                    LIGHT_LOOP_BEGIN(lightCount)
                        Light light = GetAdditionalLight(lightIndex, input.positionWS, half4(1.0, 1.0, 1.0, 1.0));
                        glint += LightGlint(light, normal, view, nDotV, roughness);
                    LIGHT_LOOP_END
                #endif

                float transmitted = (1.0 - fresnel) * dot(transmission, float3(0.2126, 0.7152, 0.0722));
                float opacity = coverage * (1.0 - transmitted);
                float3 color = coverage * (reflection * fresnel + scatter * (1.0 - fresnel) + glint);
                color = MixFogColor(color, unity_FogColor.rgb * opacity, (float)input.fog);
                return half4(color, opacity);
            }
            ENDHLSL
        }
    }
}
