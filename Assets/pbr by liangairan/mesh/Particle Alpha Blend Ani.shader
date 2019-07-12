Shader "Glow/Particles/Ani Alpha Blended Mask"
{
    Properties
    {
        [HDR] _TintColor ("Tint Color",Color)=(0.5, 0.5, 0.5, 0.5)
        _MainTex ("Particle Texture", 2D) = "white" {}
        _Mask ("Mask ( R Channel )", 2D) = "white" {}
        _SpeedU ("SpeedU", Float) = 0
        _SpeedV ("SpeedV", Float) = 0
    }

    Category
    {
        Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
        }
        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask RGB
        Cull Off
        Lighting Off
        ZWrite Off

        SubShader
        {
            Pass
            {

                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma target 2.0
                #pragma multi_compile_particles
                #include "UnityCG.cginc"

                sampler2D _MainTex;
                sampler2D _Mask;
                fixed4 _TintColor;
                float _SpeedU;
                float _SpeedV;

                struct appdata_t
                {
                    float4 vertex : POSITION;
                    fixed4 color : COLOR;
                    float2 texcoord : TEXCOORD0;
                    UNITY_VERTEX_INPUT_INSTANCE_ID
                };

                struct v2f
                {
                    float4 vertex : SV_POSITION;
                    fixed4 color : COLOR;
                    float2 texcoord : TEXCOORD0;
                    float2 texcoordMask : TEXCOORD1;
                    UNITY_VERTEX_OUTPUT_STEREO
                };

                float4 _MainTex_ST;
                float4 _Mask_ST;

                v2f vert(appdata_t v)
                {
                    v2f o;
                    UNITY_SETUP_INSTANCE_ID(v);
                    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                    o.vertex = UnityObjectToClipPos(v.vertex);

                    o.color = v.color * _TintColor;
                    o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
                    o.texcoordMask = TRANSFORM_TEX(v.texcoord,_Mask);
                    return o;
                }

                fixed4 frag(v2f i) : SV_Target
                {
                    i.texcoord += _Time.g * float2(_SpeedU, _SpeedV);

                    fixed4 col = 2.0f * i.color * tex2D(_MainTex, i.texcoord);
                    col.a = saturate(col.a * tex2D(_Mask, i.texcoordMask).r);
                    return col;
                }
                ENDCG
            }
        }
    }
}