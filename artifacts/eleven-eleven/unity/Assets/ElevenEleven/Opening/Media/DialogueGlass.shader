Shader "ElevenEleven/Dialogue Glass"
{
    Properties
    {
        [PerRendererData] _MainTex("Sprite", 2D) = "white" {}
        _Color("Tint", Color) = (1,1,1,1)
        _Edge("Bright edge", Color) = (0.09,0.85,1,1)
        _Near("Left glass", Color) = (0.04,0.14,0.26,0.92)
        _Far("Right glass", Color) = (0.21,0.05,0.33,0.87)
        _Drift("Shimmer", Float) = 1
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "CanUseSpriteAtlas"="True" }
        Cull Off ZWrite Off ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag
            float4 _Color, _Edge, _Near, _Far;
            float _Drift;
            struct App { float4 vertex:POSITION; float4 color:COLOR; float2 uv:TEXCOORD0; };
            struct Pixel { float4 pos:SV_POSITION; float4 color:COLOR; float2 uv:TEXCOORD0; };
            Pixel vert(App input)
            {
                Pixel output;
                output.pos = UnityObjectToClipPos(input.vertex);
                output.uv = input.uv;
                output.color = input.color * _Color;
                return output;
            }
            fixed4 frag(Pixel input):SV_Target
            {
                float2 uv = saturate(input.uv);
                // Derivatives keep the rounded silhouette and fine rim consistent at each resolution.
                float2 pixels = rcp(max(fwidth(uv), float2(0.00001, 0.00001)));
                float radius = min(16, pixels.y * 0.23);
                float2 rounded = abs((uv - 0.5) * pixels) - (pixels * 0.5 - radius);
                float signedDistance = length(max(rounded, 0)) + min(max(rounded.x, rounded.y), 0) - radius;
                float inside = 1 - smoothstep(-0.3, 0.8, signedDistance);
                float rim = smoothstep(-2.1, -0.25, signedDistance) * inside;
                float topGlow = exp2((uv.y - 1) * 11);
                float sweep = pow(saturate(1 - abs(uv.x + 0.24 * uv.y - frac(_Time.y * 0.09) * 1.7 + 0.2)), 12);
                fixed4 glass = lerp(_Near, _Far, smoothstep(0,1,uv.x));
                glass.rgb = glass.rgb * 0.43 + float3(0.022, 0.032, 0.048);
                glass.rgb += _Edge.rgb * (rim * (0.17 + 0.16 * uv.y) + topGlow * 0.045 + _Drift * sweep * 0.022);
                glass.a = (glass.a * 0.91 + rim * 0.15) * inside;
                return glass * input.color;
            }
            ENDCG
        }
    }
}
