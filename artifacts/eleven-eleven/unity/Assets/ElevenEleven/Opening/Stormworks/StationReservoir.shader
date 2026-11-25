Shader "ElevenEleven/Station Reservoir"
{
    Properties
    {
        _DeepColor("Scattered light in deep water", Color) = (0.018, 0.047, 0.063, 1)
        _SkyColor("Cool basin reflections", Color) = (0.083, 0.19, 0.25, 1)
        _Absorption("RGB absorption per metre", Vector) = (0.87, 0.34, 0.20, 0)
        [NoScaleOffset] _BasinReflection("Baked observatory reflection", Cube) = "black" {}
        _ReflectionBlend("Baked reflection weight", Range(0, 1)) = 0
        _ReflectionOrigin("Reflection capture position", Vector) = (0, -3.42, 57.8, 0)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" "RenderType"="Opaque" }
        Pass
        {
            Name "ReservoirForward"
            Tags { "LightMode"="UniversalForwardOnly" }
            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vertex
            #pragma fragment Fragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _DeepColor, _SkyColor;
                float4 _Absorption;
                float4 _ReflectionOrigin;
                half _ReflectionBlend;
            CBUFFER_END
            TEXTURECUBE(_BasinReflection);
            SAMPLER(sampler_BasinReflection);

            float _EchoSurfaceClock;
            static const float Gravity = 9.80665;
            static const float WaterDepth = 2.45;
            static const float SurfaceTensionOverDensity = 0.0000728;

            struct Attributes { float3 positionOS : POSITION; };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float crest : TEXCOORD2;
            };

            float Frequency(float k, float depth)
            {
                // This form of tanh avoids overflow in the D3D11 expansion at capillary wavelengths.
                float attenuation = exp(-2.0 * k * depth);
                float depthFactor = (1.0 - attenuation) / (1.0 + attenuation);
                return sqrt((Gravity * k + SurfaceTensionOverDensity * k * k * k) * depthFactor);
            }

            // Evaluate finite-depth dispersion and the analytical surface Jacobian at the same phase.
            void GravityWave(float2 xz, float2 direction, float wavelength, float amplitude, float steepness,
                float phase, inout float3 position, inout float3 tangentX, inout float3 tangentZ)
            {
                float k = TWO_PI / wavelength;
                float s, c;
                sincos(k * dot(direction, xz) - Frequency(k, WaterDepth) * _EchoSurfaceClock + phase, s, c);
                float2 horizontal = steepness * amplitude * direction;
                position += float3(horizontal.x * c, amplitude * s, horizontal.y * c);
                float3 derivative = float3(-horizontal.x * s, amplitude * c, -horizontal.y * s) * k;
                tangentX += derivative * direction.x;
                tangentZ += derivative * direction.y;
            }

            Varyings Vertex(Attributes input)
            {
                Varyings output;
                float3 surface = TransformObjectToWorld(input.positionOS);
                float2 samplePoint = surface.xz - float2(0.0, 57.8);
                float3 tangentX = float3(1, 0, 0);
                float3 tangentZ = float3(0, 0, 1);
                GravityWave(samplePoint, float2(0.5000, 0.8660), 7.8, 0.124, 0.79, 0.39, surface, tangentX, tangentZ);
                GravityWave(samplePoint, float2(0.7660, 0.6428), 5.45, 0.090, 0.73, 1.42, surface, tangentX, tangentZ);
                GravityWave(samplePoint, float2(-0.4695, 0.8829), 4.12, 0.063, 0.67, 2.92, surface, tangentX, tangentZ);
                GravityWave(samplePoint, float2(0.9511, 0.3090), 2.78, 0.037, 0.64, 3.61, surface, tangentX, tangentZ);
                GravityWave(samplePoint, float2(-0.8090, 0.5878), 2.05, 0.021, 0.57, 5.72, surface, tangentX, tangentZ);
                output.positionWS = surface;
                output.normalWS = normalize(cross(tangentZ, tangentX));
                output.crest = max(0, 1.0 - (tangentX.x * tangentZ.z - tangentX.z * tangentZ.x));
                output.positionCS = TransformWorldToHClip(surface);
                return output;
            }

            float2 FineSlope(float2 xz, float2 direction, float wavelength, float amplitude, float offset)
            {
                float k = TWO_PI / wavelength;
                float phase = k * dot(direction, xz) - Frequency(k, WaterDepth) * _EchoSurfaceClock + offset;
                float filter = 1.0 - smoothstep(0.85, 3.14, fwidth(phase));
                return direction * (k * amplitude * cos(phase) * filter);
            }

            float2 RunoffSlope(float2 xz, float2 outlet, float cycleOffset)
            {
                float2 radial = xz - outlet;
                float radius = length(radial);
                float time = _EchoSurfaceClock + cycleOffset;
                float age = frac(time * 1.11) / 1.11;
                float k = TWO_PI / 0.44;
                float omega = Frequency(k, WaterDepth);
                float travel = radius - age * (Gravity + 3.0 * SurfaceTensionOverDensity * k * k) / (2.0 * omega);
                float wavefront = exp(-3.8 * travel * travel) * smoothstep(0.03, 0.14, radius);
                float taper = exp(-0.58 * radius) * sin(PI * age * 1.11);
                return radial * rsqrt(max(0.02, dot(radial, radial))) *
                    (0.17 * wavefront * taper * cos(k * radius - omega * age));
            }

            half3 PracticalGlint(float3 surface, half3 reflected, half3 view, float3 lightPosition, half3 color,
                half angularSharpness, half fresnel)
            {
                float3 toLight = lightPosition - surface;
                float distanceSquared = dot(toLight, toLight);
                half alignment = saturate(dot(reflected, toLight * rsqrt(distanceSquared)));
                half lobe = exp2(-angularSharpness * (1.0h - alignment));
                return color * ((fresnel + 0.09h) * lobe * (34.0 / (12.0 + distanceSquared))) *
                    saturate(view.y * 4.0h + 0.22h);
            }

            float3 CorrectReflectionRay(float3 surface, float3 reflected)
            {
                float3 inverseRay = (step(0.0, reflected) * 2.0 - 1.0) / max(abs(reflected), 0.0001);
                float3 lower = float3(-35.5, -5.0, 26.4);
                float3 upper = float3(35.5, 23.0, 89.4);
                float3 exits = (lerp(lower, upper, step(0.0, reflected)) - surface) * inverseRay;
                float travel = max(0.0, min(exits.x, min(exits.y, exits.z)));
                return surface + travel * reflected - _ReflectionOrigin.xyz;
            }

            float BasinDepth(float2 xz)
            {
                float2 interior = float2(34.5, 30.5) - abs(xz - float2(0.0, 57.8));
                float outerSlope = smoothstep(0.0, 9.0, min(interior.x, interior.y));
                float westShelf = length((xz - float2(-19.2, 55.0)) * float2(0.94, 0.40));
                float eastShelf = length((xz - float2(19.45, 63.0)) * float2(0.94, 0.36));
                return lerp(0.38, 3.72, outerSlope * smoothstep(0.0, 7.5, min(westShelf, eastShelf)));
            }

            half4 Fragment(Varyings input) : SV_Target
            {
                float3 surface = input.positionWS;
                float2 xz = surface.xz;
                float2 slope = FineSlope(xz, float2(0.342, 0.940), 0.94, 0.012, 0.4);
                slope += FineSlope(xz, float2(0.848, 0.530), 0.50, 0.008, 2.7);
                slope += FineSlope(xz, float2(-0.695, 0.719), 0.28, 0.0045, 5.4);
                slope += FineSlope(xz, float2(0.95, -0.312), 0.116, 0.0016, 1.8);
                slope += RunoffSlope(xz, float2(-17.9, 54.2), 0.11);
                slope += RunoffSlope(xz, float2(19.05, 62.6), 0.47);
                float3 normal = normalize(input.normalWS + float3(-slope.x, 0, -slope.y));
                float3 view = GetWorldSpaceNormalizeViewDir(surface);
                float3 reflected = reflect(-view, normal);
                float3 refracted = refract(-view, normal, 1.0 / 1.333);

                // Fresnel reflectance for air and water, n = 1.333, with Schlick's angle term.
                half grazing = 1.0h - saturate(dot(view, normal));
                half grazing2 = grazing * grazing;
                half fresnel = 0.02037h + 0.97963h * grazing2 * grazing2 * grazing;
                half highSky = smoothstep(0.0h, 0.85h, reflected.y);
                half3 environment = lerp(_SkyColor.rgb * half3(0.65h, 1.58h, 1.92h), half3(0.215h, 0.265h, 0.424h), highSky);
                half horizon = pow(saturate(1.0h - abs(reflected.y - 0.10h)), 7.0h);
                environment += half3(0.070h, 0.055h, 0.131h) * horizon;
                UNITY_BRANCH
                if (_ReflectionBlend > 0.001h)
                {
                    half3 baked = SAMPLE_TEXTURECUBE_LOD(_BasinReflection, sampler_BasinReflection,
                        CorrectReflectionRay(surface, reflected), 1.4).rgb;
                    environment = lerp(environment, max(baked, environment * 0.23h), _ReflectionBlend);
                }

                float depth = BasinDepth(xz);
                float thickness = depth / max(0.28, -dot(normal, refracted));
                float shore = (1.0 - smoothstep(0.40, 0.85, depth)) * 0.28;
                float2 bed = xz + refracted.xz * thickness;
                float bedStrata = 0.53 + 0.25 * sin(dot(bed, float2(2.39, 1.85))) + 0.21 * sin(dot(bed, float2(-2.85, 3.79)));
                half3 background = lerp(half3(0.020h, 0.031h, 0.034h), half3(0.043h, 0.063h, 0.074h), bedStrata);
                half3 transmission = exp(-_Absorption.xyz * thickness);
                half waterFocus = saturate(normal.y * 0.45h + (normal.x - normal.z) * 0.85h + input.crest);
                half3 scattered = lerp(half3(0.013h, 0.037h, 0.055h), _DeepColor.rgb * half3(1.35h, 1.53h, 1.76h), waterFocus);
                half3 deepLight = lerp(scattered, background, transmission);
                half3 color = lerp(deepLight, environment, fresnel);
                color += PracticalGlint(surface, reflected, view, float3(-14.5, 6.72, 50.5), half3(3.1h, 1.26h, 0.36h), 27.0h, fresnel);
                color += PracticalGlint(surface, reflected, view, float3(17.4, 7.4, 57.5), half3(0.39h, 2.60h, 3.05h), 33.0h, fresnel);
                color += PracticalGlint(surface, reflected, view, float3(-6.2, 20.1, 62.3), half3(0.66h, 0.41h, 1.67h), 48.0h, fresnel);
                color += PracticalGlint(surface, reflected, view, float3(-14.2, 0.90, 52.7), half3(2.6h, 1.13h, 0.33h), 35.0h, fresnel);
                color += PracticalGlint(surface, reflected, view, float3(15.5, 1.45, 63.0), half3(0.39h, 1.76h, 2.35h), 45.0h, fresnel);

                float foamCells = 0.50 + 0.23 * sin(dot(xz, float2(12.1, 8.7)) + slope.x * 7.0) +
                    0.17 * sin(dot(xz, float2(-21.9, 16.2)) + slope.y * 10.0);
                float foam = max(shore * 0.68, smoothstep(0.20, 0.267, input.crest) * 0.27);
                foam *= smoothstep(0.43, 0.79, foamCells);
                color = lerp(color, half3(0.41h, 0.59h, 0.63h), saturate(foam));
                float distanceSquared = dot(_WorldSpaceCameraPos - surface, _WorldSpaceCameraPos - surface);
                half haze = 1.0h - exp(-distanceSquared * 0.00012);
                return half4(lerp(color, half3(0.027h, 0.052h, 0.080h), haze), 1.0h);
            }
            ENDHLSL
        }
    }
}
