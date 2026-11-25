Shader "ElevenEleven/Observatory Clock Digits"
{
    Properties
    {
        _BaseMap("Clock lettering", 2D) = "white" {}
        [HDR] _BaseColor("Clock light", Color) = (1,1,1,1)
        _ClockDotIntensity("Colon pulse", Vector) = (1,1,0,0)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
        Pass
        {
            Cull Off
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            sampler2D _BaseMap;
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _ClockDotIntensity;
            CBUFFER_END
            struct Input { float3 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct Output { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; UNITY_FOG_COORDS(1) };

            Output Vert(Input input)
            {
                Output output;
                output.pos = UnityObjectToClipPos(input.vertex);
                output.uv = input.uv;
                UNITY_TRANSFER_FOG(output, output.pos);
                return output;
            }

            half4 Frag(Output input) : SV_Target
            {
                half colon = step(.465h,input.uv.x) * (1.0h - step(.538h,input.uv.x));
                half dotLight = lerp(_ClockDotIntensity.y,_ClockDotIntensity.x,step(.45h,input.uv.y));
                half gain = lerp(1.0h,dotLight,colon);
                half3 color = _BaseColor.rgb * (1.0h + colon * gain * .48h);
                UNITY_APPLY_FOG(input.fogCoord, color);
                return half4(color,tex2D(_BaseMap,input.uv).a * _BaseColor.a * saturate(gain));
            }
            ENDHLSL
        }
    }
}
