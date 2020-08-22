// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "liangairan/pbr/pbr by IBL" {
// 　　　　　　D(h) F(v,h) G(l,v,h)
//f(l,v) = ---------------------------
// 　　　　　　4(n·l)(n·v)
	Properties {
		_Color ("Color", Color) = (0.5,0.5,0.5,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
    _NormalTex("NormalMap (RGB)", 2D) = "bump" {}
    //_ShadowmapTex("ShadowMap", 2D) = "black" {}
    _IrradianceMap("IrradianceMap", Cube) = "_Skybox" {}
    _SpecularIndirectMap("SpecularIndirectMap", Cube) = "_Skybox" {}
    _BRDFLUTTex("Brdf lut map", 2D) = "white" {}
		_Roughness("Roughness", Range(0,1)) = 0
		_Metallic("Metallicness",Range(0,1)) = 0
		_F0("Fresnel coefficient", Color) = (1,1,1,1)
		_ShadowScale("ShadowScale", Range(0,1)) = 0
		_DepthBias("DepthBias", Range(-1,1)) = 0
	[KeywordEnum(DEFAULT, GGX, BECKMANN)]ndf("normal distribution function", float) = 0
	}
		SubShader{
			Tags { "RenderType" = "Opaque" }
			LOD 200

			Pass
			{
				Tags { "LightMode" = "ForwardBase" }
				CGPROGRAM
				#include "UnityCG.cginc"
				#include "AutoLight.cginc"
				#include "Lighting.cginc"
#include "pbrInclude.cginc"
				#pragma target 3.0
				#pragma vertex vert
				#pragma fragment frag
				#pragma exclude_renderers xbox360 flash	
				#pragma multi_compile_fwdbase 
			#pragma multi_compile NDF_DEFAULT NDF_GGX NDF_BECKMANN

				float4 _Color;
            sampler2D _MainTex;
        sampler2D _NormalTex;
        //sampler2D _ShadowmapTex;
        samplerCUBE _IrradianceMap;
        UNITY_DECLARE_TEXCUBE(_SpecularIndirectMap);
        sampler2D _BRDFLUTTex;
            float _Roughness;
            float _Metallic;
            fixed4 _F0;
            float _ShadowScale;
            float4x4 LightProjectionMatrix;
            float _DepthBias;
			float ndf;
			

            struct appdata
            {
                half4 vertex : POSITION;
                half4 color : COLOR;
                half2 uv : TEXCOORD0;
                half3 normal : NORMAL;
                float4 tangent	: TANGENT;
            };

            struct VSOut
            {
                half4 pos		: SV_POSITION;
                half4 color     : COLOR;
                half2 uv : TEXCOORD0;
                half3 normalWorld : TEXCOORD1;
                half3 posWorld : TEXCOORD2;
                half3 tangentWorld : TEXCOORD3;
                half3 binormalWorld : TEXCOORD4;
                SHADOW_COORDS(5)
                //    half4 proj : TEXCOORD6;
                //half2 depth : TEXCOORD7;
            };

            VSOut vert(appdata v)
            {
                VSOut o;
                o.color = v.color;
                o.pos = UnityObjectToClipPos(v.vertex);
                //TANGENT_SPACE_ROTATION;
                o.uv = v.uv;
                o.normalWorld = UnityObjectToWorldNormal(v.normal);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                //TRANSFER_VERTEX_TO_FRAGMENT(o);
                o.tangentWorld = UnityObjectToWorldDir(v.tangent.xyz);
                o.binormalWorld = cross(normalize(o.normalWorld), normalize(o.tangentWorld.xyz)) * v.tangent.w;
                TRANSFER_SHADOW(o);

                //float4x4 matWLP = mul(LightProjectionMatrix, unity_ObjectToWorld);
                //o.proj = mul(matWLP, v.vertex);
                //o.depth = o.proj.zw;
                return o;
            }

            half4 frag(VSOut i) : COLOR
            {
                fixed3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                fixed3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);

                fixed3 tangentNormal = UnpackNormal(tex2D(_NormalTex, i.uv));
                float3x3 mTangentToWorld = float3x3(i.tangentWorld, i.binormalWorld, i.normalWorld);
                fixed3 normalDirection = normalize(mul(tangentNormal, mTangentToWorld));  //法线贴图的世界坐标
                //fixed3 normalDirection = normalize(i.normalWorld); //UnpackNormal(tex2D(_NormalTex, i.uv));
                //微表面法线
                fixed3 h = normalize(lightDirection + viewDirection);

                half3 attenColor = _LightColor0.xyz;
                half3 R = reflect(-viewDirection, normalDirection);
                

                float NdL = max(dot(normalDirection, lightDirection), 0);
                float NdV = max(dot(normalDirection, viewDirection), 0);
                float VdH = max(dot(viewDirection, h), 0);
                float NdH = max(dot(normalDirection, h), 0);
                float LdH = max(dot(lightDirection, h), 0);
                
                //return half4(fresnelSchlick(NdV, _F0), 1);
                
                half4 albedo = i.color * tex2D(_MainTex, i.uv) * _Color;

                //radiance
                half3 totalLightColor = UNITY_LIGHTMODEL_AMBIENT.xyz + attenColor;
                //fixed3 diffuseLambert = max(0, (totalLightColor - UNITY_LIGHTMODEL_AMBIENT.xyz) * NdL + UNITY_LIGHTMODEL_AMBIENT.xyz);

                //目的是当金属度为0时，也希望有0.04的高光
                // calculate reflectance at normal incidence; if dia-electric (like plastic) use F0 
                // of 0.04 and if it's a metal, use the albedo color as F0 (metallic workflow)  
                half3 F0 = half3(0.04, 0.04, 0.04);
                F0 = lerp(F0, albedo.rgb, _Metallic);
                //fixed3 specularColor = lerp(fixed3(0.04, 0.04, 0.04), _F0.rgb, _Metallic);
                half3 F = fresnelSchlick(VdH, F0);
                half3 kS = F;
                half3 kD = (half3(1, 1, 1) - kS) * (1.0 - _Metallic);
                half3 directDiffuse = (albedo.rgb / PI) * kD * totalLightColor * NdL;
				//float f0 = F0(NdL, NdV, LdH, _Roughness);
				//directDiffuse *= f0;
#ifdef NDF_GGX
				_Roughness = max(_Roughness, 0.007);
				float D = normalDistribution_GGX(_Roughness, NdH);
				float G = GGX_GSF(_Roughness, NdV, NdL);
#elif NDF_BECKMANN
				_Roughness = max(_Roughness, 0.01);
                float D = BeckmannNormalDistribution(_Roughness, NdH);
                float G = smith_schilck(_Roughness, NdV, NdL);
#else
				_Roughness = max(_Roughness, 0.01);
				float D = BeckmannNormalDistribution(_Roughness, NdH);
				float G = Schilck_GSF(_Roughness, NdV, NdL);
#endif
                half3 specular = brdf(F, D, G, NdV, NdL);
				
                

                F = fresnelSchlickRoughness(NdV, F0, _Roughness);
                kS = F;
                kD = 1.0 - kS;
                kD *= 1.0 - _Metallic;

                half4 lightOut;
                lightOut.rgb = directDiffuse + specular * _LightColor0 * NdL;
                half4 irradianceColor = texCUBE(_IrradianceMap, normalDirection);

                half3 indirectDiffuse = irradianceColor.rgb * albedo.rgb * kD;

                //下面是计算indirect specular
                const float MAX_REFLECTION_LOD = 7.0;
                float mipLevel = floor(_Roughness * MAX_REFLECTION_LOD);
                float r_max = 1.0 / MAX_REFLECTION_LOD;
                float mipT = _Roughness * MAX_REFLECTION_LOD - mipLevel;
                half3 indirectEnvColor = UNITY_SAMPLE_TEXCUBE_LOD(_SpecularIndirectMap, R, mipLevel).rgb;
                half3 indirectEnvColor2 = UNITY_SAMPLE_TEXCUBE_LOD(_SpecularIndirectMap, R, mipLevel + 1).rgb;
                indirectEnvColor = lerp(indirectEnvColor, indirectEnvColor2, mipT);
                half3 brdf = tex2D(_BRDFLUTTex, half2(NdV, _Roughness));
                half3 indirectSpecular = indirectEnvColor * (F * brdf.x + brdf.y);

                lightOut.rgb += indirectDiffuse + indirectSpecular;

                //float  atten = saturate(SHADOW_ATTENUATION(i) + _ShadowScale);
                //half3 shadow = max(UNITY_LIGHTMODEL_AMBIENT.xyz, fixed3(atten, atten, atten));

                //lightOut.rgb *= shadow;
                //lightOut.rgb = lightOut.rgb / (lightOut.rgb + 1.0);
                //lightOut.rgb = 1.0 - exp(-lightOut.rgb * 1.0);
                //float gama = 1 / 2.2;
                //lightOut.rgb = pow(lightOut.rgb, gama);

                return lightOut;
            }
            ENDCG
        }
	}
    FallBack "Diffuse"
}