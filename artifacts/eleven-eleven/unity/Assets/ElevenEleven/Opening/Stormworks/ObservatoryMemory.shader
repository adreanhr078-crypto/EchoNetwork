Shader "ElevenEleven/Memory Inside Fracture"
{
    Properties
    {
        _Memory("Memory image", 2D) = "black" {}
        _Color("Projection tint", Color) = (.62,.52,.92,.89)
        _FollowsGlass("Follows the glass surface", Float) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
        Cull Off ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            sampler2D _Memory;
            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half _FollowsGlass;
            CBUFFER_END
            float _EchoSurfaceClock;
            struct Input { float3 positionOS : POSITION; float2 uv : TEXCOORD0; };
            struct Output { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; UNITY_FOG_COORDS(1) };
            Output Vert(Input input)
            {
                Output output;
                output.positionCS = UnityObjectToClipPos(input.positionOS);
                output.uv = input.uv;
                UNITY_TRANSFER_FOG(output, output.positionCS);
                return output;
            }
            half4 Frag(Output input) : SV_Target
            {
                float2 uv = input.uv;
                half3 still = tex2D(_Memory, uv).rgb;
                half luma = dot(still, half3(.2126,.7152,.0722));
                half scan = .93h + .07h * sin(uv.y * 160.0 - _EchoSurfaceClock * 4.0);
                half edge = smoothstep(.0,.16,min(min(uv.x,uv.y), min(1.0-uv.x,1.0-uv.y)));
                half3 image = lerp(still,luma.xxx,.63h) * (.55h + _Color.rgb * .62h) * scan;
                image += _Color.rgb * .07h;
                UNITY_APPLY_FOG(input.fogCoord, image);
                return half4(image, _Color.a * lerp(.37h + .63h * edge, edge, _FollowsGlass));
            }
            ENDHLSL
        }
    }
}
