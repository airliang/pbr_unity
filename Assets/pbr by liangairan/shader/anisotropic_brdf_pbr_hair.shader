// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "liangairan/pbr/anisotropic pbr hair" {
// 　　　　　　D(h) F(v,h) G(l,v,h)
//f(l,v) = ---------------------------
// 　　　　　　4(n·l)(n·v)
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_NormalTex("NormalMap (RGB)", 2D) = "bump" {}
        _Roughness ("Roughness", Range(0,1)) = 0
		//_RoughnessY ("RoughnessY", Range(0,1)) = 0
        _Metallic("Metallicness",Range(0,1)) = 0
        _F0 ("Fresnel coefficient", Color) = (1,1,1,1)
		_Ex("Ex", Range(0,1)) = 1
		_Ey("Ey",Range(0,1)) = 1
		_Cutoff("Cutoff", Range(0,1)) = 0.5
	}

	CGINCLUDE
#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"
#pragma target 3.0
#pragma exclude_renderers xbox360 flash	
#pragma multi_compile_fwdbase 
#define PI 3.14159265359

	sampler2D _MainTex;
	sampler2D _NormalTex;
	float _Roughness;
	float _Metallic;
	float _Ex;
	float _Ey;
	fixed4 _F0;
	fixed4 _Color;
	float _Cutoff;

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
		half3 binormalWorld : TEXCOORD4;
		SHADOW_COORDS(5)
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

	float D_GGXaniso(float RoughnessX, float RoughnessY, float NdotH, float3 H, float3 X, float3 Y)
	{
		float ax = RoughnessX * RoughnessX;
		float ay = RoughnessY * RoughnessY;
		float XoH = dot(X, H);
		float YoH = dot(Y, H);
		float d = XoH * XoH / (ax*ax) + YoH * YoH / (ay*ay) + NdotH * NdotH;
		return 1 / (PI * ax*ay * d*d + 0.0001);
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

	float aniso_smith_schilck(float ax, float ay, float ndv, float ndl)
	{
		float k = (ax + 1) * (ay + 1) / 8;
		float Gv = ndv / (ndv * (1 - k) + k);
		float Gl = ndl / (ndl * (1 - k) + k);
		return Gv * Gl;
	}

	half3 wardBrdf(half3 fresnel, float NdotH, float ndv, float ndl, float3 H, float3 X, float3 Y)
	{
		float ax = _Ex;
		float ay = _Ey;
		float alphaX = dot(H, X) / ax;
		float alphaY = dot(H, Y) / ay;
		float exponent = -2.0 * (alphaX * alphaX + alphaY * alphaY) / (1.0 + NdotH);

		float spec = sqrt(ndl / ndv) * exp(exponent);
		return fresnel * spec;
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
		o.binormalWorld = cross(normalize(o.normalWorld), normalize(o.tangentWorld.xyz));
		TRANSFER_SHADOW(o);
		return o;
	}

	half4 frag(VSOut i) : COLOR
	{
		fixed3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
		fixed3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
		fixed3 tangentNormal = UnpackNormal(tex2D(_NormalTex, i.uv));
		half3 tangentWorld = normalize(i.tangentWorld);//normalize(cross(normalDirection, viewDirection));
		half3 bNormalWorld = normalize(i.binormalWorld);
		float3x3 mTangentToWorld = transpose(float3x3(tangentWorld, bNormalWorld, i.normalWorld));
		fixed3 normalDirection = normalize(mul(mTangentToWorld, tangentNormal));  //法线贴图的世界坐标
		//fixed3 normalDirection = normalize(i.normalWorld); //UnpackNormal(tex2D(_NormalTex, i.uv));

		//微表面法线
		fixed3 h = normalize(lightDirection + viewDirection);

		fixed3 attenColor = _LightColor0.xyz;


		float NdL = max(dot(normalDirection, lightDirection), 0);
		float NdV = max(dot(normalDirection, viewDirection), 0);
		float VdH = max(dot(viewDirection, h), 0);
		float NdH = max(dot(normalDirection, h), 0);
		float LdH = max(dot(lightDirection, h), 0);


		fixed4 albedo = i.color * tex2D(_MainTex, i.uv) * _Color;
		clip(albedo.a - _Cutoff);
		//radiance
		fixed3 totalLightColor = UNITY_LIGHTMODEL_AMBIENT.xyz + attenColor;
		fixed3 specularColor = lerp(fixed3(0.04, 0.04, 0.04), _F0.rgb, _Metallic);
		half3 F = fresnelSchlick(VdH, specularColor.rgb);
		half3 kS = F;
		half3 kD = (half3(1, 1, 1) - kS) * (1.0 - _Metallic);


		//h要变换到切线空间里

		//float D = BeckmannNormalDistribution(_Roughness, NdH);
		float D = D_GGXaniso(_Ex, _Ey, NdH, h, tangentWorld, bNormalWorld);
		float G = smith_schilck(_Roughness, NdV, NdH);
		fixed3 specular = brdf(F, D, G, NdV, NdL);
		//fixed3 specular = wardBrdf(F, NdH, NdV, NdL, h, tangent, bNormal) * G;
		fixed4 lightOut;
		fixed3 directDiffuse = (albedo.rgb / PI) * kD * totalLightColor * NdL;
		lightOut.rgb = directDiffuse + specular * totalLightColor * NdL;

		//lightOut.rgb = i.tangentWorld;
		lightOut.a = albedo.a;

		return lightOut;
	}

	half4 fragBlend(VSOut i) : COLOR
	{
		fixed3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
		fixed3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
		fixed3 tangentNormal = UnpackNormal(tex2D(_NormalTex, i.uv));
		half3 tangentWorld = normalize(i.tangentWorld);//normalize(cross(normalDirection, viewDirection));
		half3 bNormalWorld = normalize(i.binormalWorld);
		float3x3 mTangentToWorld = transpose(float3x3(tangentWorld, bNormalWorld, i.normalWorld));
		fixed3 normalDirection = normalize(mul(mTangentToWorld, tangentNormal));  //法线贴图的世界坐标
		//fixed3 normalDirection = normalize(i.normalWorld); //UnpackNormal(tex2D(_NormalTex, i.uv));

		//微表面法线
		fixed3 h = normalize(lightDirection + viewDirection);

		fixed3 attenColor = _LightColor0.xyz;


		float NdL = max(dot(normalDirection, lightDirection), 0);
		float NdV = max(dot(normalDirection, viewDirection), 0);
		float VdH = max(dot(viewDirection, h), 0);
		float NdH = max(dot(normalDirection, h), 0);
		float LdH = max(dot(lightDirection, h), 0);


		fixed4 albedo = i.color * tex2D(_MainTex, i.uv) * _Color;
		//radiance
		fixed3 totalLightColor = UNITY_LIGHTMODEL_AMBIENT.xyz + attenColor;
		fixed3 specularColor = lerp(fixed3(0.04, 0.04, 0.04), _F0.rgb, _Metallic);
		half3 F = fresnelSchlick(VdH, specularColor.rgb);
		half3 kS = F;
		half3 kD = (half3(1, 1, 1) - kS) * (1.0 - _Metallic);


		//h要变换到切线空间里

		//float D = BeckmannNormalDistribution(_Roughness, NdH);
		float D = D_GGXaniso(_Ex, _Ey, NdH, h, tangentWorld, bNormalWorld);
		float G = smith_schilck(_Roughness, NdV, NdH);
		fixed3 specular = brdf(F, D, G, NdV, NdL);
		//fixed3 specular = wardBrdf(F, NdH, NdV, NdL, h, tangent, bNormal) * G;
		fixed4 lightOut;
		fixed3 directDiffuse = (albedo.rgb / PI) * kD * totalLightColor * NdL;
		lightOut.rgb = directDiffuse + specular * totalLightColor * NdL;

		//lightOut.rgb = i.tangentWorld;
		lightOut.a = albedo.a;

		return lightOut;
	}

	ENDCG
	/*
	SubShader {
		Tags { "LightMode" = "ForwardBase" "IgnoreProjector" = "True" "Queue" = "Geometry" "RenderType" = "Opaque"}
		//LOD 200
		
		
        Pass
        {
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
			
            ENDCG
        }
		
		
	}
	*/
	
	SubShader {
		Tags { "LightMode" = "ForwardBase" "IgnoreProjector" = "True" "Queue" = "Transparent" "RenderType" = "Transparent"}
		//LOD 200
		Pass
        {
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest Off
			ZWrite Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragBlend
            
            ENDCG
        }
	}
    //FallBack "Diffuse"
}