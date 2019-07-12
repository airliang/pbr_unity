// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "liangairan/pbr/pbr simple" {
// 　　　　　　D(h) F(v,h) G(l,v,h)
//f(l,v) = ---------------------------
// 　　　　　　4(n·l)(n·v)
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Roughness ("Roughness", Range(0,1)) = 0
        _Metallic("Metallicness",Range(0,1)) = 0
        _F0 ("Fresnel coefficient", Color) = (1,1,1,1)
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
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
            #pragma multi_compile_fwdbase 
            #define PI 3.14159265359

            sampler2D _MainTex;
            float _Roughness;
            float _Metallic;
			float _Ex;
			float _Ey;
            fixed4 _F0;
			fixed4 _Color;

            struct appdata
            {
                half4 vertex : POSITION;
                half4 color : COLOR;
                half2 uv : TEXCOORD0;
                half3 normal : NORMAL;
				half3 tangent: TANGENT;
            };

            struct VSOut
            {
                half4 pos		: SV_POSITION;
                half4 color     : COLOR;
                half2 uv : TEXCOORD0;
                half3 normalWorld : TEXCOORD1;
                half3 posWorld : TEXCOORD2;
				half3 tangentWorld : TEXCOORD3;
                SHADOW_COORDS(4)
            };

            //F(v,h)公式 cosTheta = v dot h
            half3 fresnelSchlick(float cosTheta, half3 F0)
            {
                return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
            }

            //D(h)GGX公式，计算法线分布
            //alpha = roughness * roughness
            float normalDistribution_GGX(float ndh, float alpha)
            {
                float alphaPow = alpha * alpha;
                float t = ndh * ndh * (alphaPow - 1) + 1;
                return alphaPow / (PI * t * t);
            }

            float BeckmannNormalDistribution(float roughness, float NdotH)
            {
                float roughnessSqr = roughness * roughness;
                float NdotHSqr = NdotH * NdotH;
                return max(0.000001, (1.0 / (3.1415926535 * roughnessSqr * NdotHSqr*NdotHSqr)) * exp((NdotHSqr - 1) / (roughnessSqr*NdotHSqr)));
            }

			float AnisotropyDistribution(float roughness, float NdotH, half3 N, half3 H, half3 tangent)
			{
				
				float roughnessSqr = roughness * roughness;
				float cosTheta = NdotH;
				half3 crossNH = cross(H, N);
				float3 up = abs(N.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
				//float3 tangent = normalize(cross(up, N));
				half3 binormalWorld = normalize(cross(N, tangent));
				float3 HProj = cross(N, crossNH);
				float cosPhi = max(dot(tangent, HProj), 0);
				float sinPhi = sqrt(1.0 - cosPhi * cosPhi);
				
				float e = (_Ex * cosPhi * cosPhi + _Ey * sinPhi * sinPhi);

				return sqrt((_Ex + 2.0) * (_Ey + 2.0)) * pow(cosTheta, e) / (2 * PI * roughnessSqr + 0.001);
				

				//float3 up = abs(N.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
				//float3 tangent = normalize(cross(up, N));
				//float bNormal = normalize(cross(N, tangent));
				//float dotHTEX = max(dot(H, tangent) / _Ex, 0);
				//float dotHBEY = max(dot(H, bNormal) / _Ey, 0);
				//return exp(-2.0 * (dotHTEX * dotHTEX + dotHBEY * dotHBEY) / (1.0 + NdotH));
			}

            //G(l,v,h)
            float smith_schilck(float roughness, float ndv, float ndl)
            {
                float k = (roughness + 1) * (roughness + 1) / 8;
                float Gv = ndv / (ndv * (1 - k) + k);
                float Gl = ndl / (ndl * (1 - k) + k);
                return Gv * Gl;
            }

            half3 brdf(half3 fresnel, float D, float G, float ndv, float ndl)
            {
                return fresnel * D * G / (4 * ndv * ndl + 0.0001);
            }

            VSOut vert(appdata v)
            {
                VSOut o;
                o.color = v.color;
                o.pos = UnityObjectToClipPos(v.vertex);
                //TANGENT_SPACE_ROTATION;
                o.uv = v.uv;
                o.normalWorld = UnityObjectToWorldNormal(v.normal);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
				o.tangentWorld = UnityObjectToWorldDir(v.tangent.xyz);
                TRANSFER_SHADOW(o);
                return o;
            }

            half4 frag(VSOut i) : COLOR
            {
                fixed3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
                fixed3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
                fixed3 normalDirection = normalize(i.normalWorld); //UnpackNormal(tex2D(_NormalTex, i.uv));
                //微表面法线
                fixed3 h = normalize(lightDirection + viewDirection);

                fixed3 attenColor = _LightColor0.xyz;
                

                float NdL = max(dot(normalDirection, lightDirection), 0);
                float NdV = max(dot(normalDirection, viewDirection), 0);
                float VdH = max(dot(viewDirection, h), 0);
                float NdH = max(dot(normalDirection, h), 0);
                float LdH = max(dot(lightDirection, h), 0);

                
                fixed4 albedo = i.color * tex2D(_MainTex, i.uv) * _Color;
                //fixed3 lambert = max(0.0, NdL) * albedo.rgb;
                //radiance
                fixed3 totalLightColor = UNITY_LIGHTMODEL_AMBIENT.xyz + attenColor;
                fixed3 specularColor = lerp(fixed3(0.04, 0.04, 0.04), _F0.rgb, _Metallic);
                half3 F = fresnelSchlick(VdH, specularColor.rgb);
                half3 kS = F;
                half3 kD = (half3(1, 1, 1) - kS) * (1.0 - _Metallic);

                float D = BeckmannNormalDistribution(_Roughness, NdH);
				//h要变换到切线空间里
				//float D = AnisotropyDistribution(_Roughness, NdH, normalDirection, h, i.tangentWorld);
				float G = smith_schilck(_Roughness, NdV, NdH);
                fixed3 specular = brdf(F, D, G, NdV, NdL); // *_LightColor0.xyz;
                fixed4 lightOut;
                fixed3 directDiffuse = (albedo.rgb / PI) * kD * totalLightColor * NdL;
                lightOut.rgb = directDiffuse + specular * totalLightColor * NdL;
                //lightOut.rgb = (kD * albedo.rgb / PI + specular) * attenColor * NdL;
                //lightOut.rgb += UNITY_LIGHTMODEL_AMBIENT.xyz;
                //lightOut.rgb = directDiffuse + specular * totalLightColor * NdL;
                //fixed3 shadow = shadowAtten(i.depth, i.proj); //max(UNITY_LIGHTMODEL_AMBIENT.xyz, fixed3(atten, atten, atten));
                float  atten = SHADOW_ATTENUATION(i);
                fixed3 shadow = max(UNITY_LIGHTMODEL_AMBIENT.xyz, fixed3(atten, atten, atten));

                //lightOut.rgb *= shadow;
                //lightOut.rgb = lightOut.rgb / (lightOut.rgb + fixed3(1.0, 1.0, 1.0));
                //float gama = 1.0 / 2.2;
                //lightOut.rgb = pow(lightOut.rgb, fixed3(gama, gama, gama));

                return lightOut;
            }
            ENDCG
        }
	}
    FallBack "Diffuse"
}