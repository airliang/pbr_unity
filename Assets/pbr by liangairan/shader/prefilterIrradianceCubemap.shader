// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "liangairan/pbr/prefilterIrradianceCubemap" {
// 　　　　　　D(h) F(v,h) G(l,v,h)
//f(l,v) = ---------------------------
// 　　　　　　4(n·l)(n·v)
	Properties {
        _Cube("Environment Map", Cube) = "_Skybox" {}
        //_NormalTex("NormalMap (RGB)", 2D) = "bump" {}
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
        Cull Off

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            CGPROGRAM
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma exclude_renderers xbox360 flash	
            //#pragma multi_compile_fwdbase 
            #define PI 3.14159265359

            samplerCUBE _Cube;
            //sampler2D _NormalTex;

            struct appdata
            {
                half4 vertex : POSITION;
                half2 uv : TEXCOORD0;
                half3 normal : NORMAL;
                //float4 tangent	: TANGENT;
            };

            struct VSOut
            {
                half4 pos		: SV_POSITION;
                half2 uv : TEXCOORD0;
                half3 normalWorld : TEXCOORD1;
                half3 posWorld : TEXCOORD2;
                //half3 tangentWorld : TEXCOORD3;
                //half3 binormalWorld : TEXCOORD4;
            };

            VSOut vert(appdata v)
            {
                VSOut o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normalWorld = UnityObjectToWorldNormal(v.normal);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                //o.tangentWorld = UnityObjectToWorldDir(v.tangent.xyz);
                //o.binormalWorld = cross(normalize(o.normalWorld), normalize(o.tangentWorld.xyz)) * v.tangent.w;
                return o;
            }

            half4 frag(VSOut i) : COLOR
            {
                /*
                fixed3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                fixed3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);

                fixed3 tangentNormal = UnpackNormal(tex2D(_NormalTex, i.uv));
                float3x3 mTangentToWorld = transpose(float3x3(i.tangentWorld, i.binormalWorld, i.normalWorld));
                fixed3 normalDirection = normalize(mul(mTangentToWorld, tangentNormal));  //法线贴图的世界坐标
                */
                fixed3 normalDirection = normalize(i.posWorld);

                fixed3 irradiance = fixed3(0, 0, 0);
                fixed3 up = fixed3(0.0, 1.0, 0.0);
                fixed3 right = cross(up, normalDirection);
                up = cross(normalDirection, right);
                
                float sampleDelta = 0.025;
                float nrSamples = 0.0;
                for (float phi = 0.0; phi < 2.0 * PI; phi += sampleDelta)
                {
                    for (float theta = 0.0; theta < 0.5 * PI; theta += sampleDelta)
                    {
                        // spherical to cartesian (in tangent space)
                        fixed3 tangentSample = fixed3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
                        // tangent space to world
                        fixed3 sampleVec = tangentSample.x * right + tangentSample.y * up + tangentSample.z * normalDirection;

                        irradiance += texCUBE(_Cube, sampleVec).rgb * cos(theta) * sin(theta);
                        nrSamples += 1.0;
                    }
                }
                irradiance = PI * irradiance * (1.0 / float(nrSamples));

                return fixed4(irradiance, 1.0);
            }
            ENDCG
        }
	}
    //FallBack "Diffuse"
}