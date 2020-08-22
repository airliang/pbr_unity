// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "liangairan/pbr/prefilterSpecularMap" {
// 　　　　　　D(h) F(v,h) G(l,v,h)
//f(l,v) = ---------------------------
// 　　　　　　4(n·l)(n·v)
	Properties {
        _Cube("Environment Map", Cube) = "_Skybox" {}
        //_NormalTex("NormalMap (RGB)", 2D) = "bump" {}
    }
        SubShader{
            Tags { "RenderType" = "Opaque" }
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

        //UNITY_DECLARE_TEXCUBE( _Cube);
    samplerCUBE _Cube;
    uniform float _roughness;
            //sampler2D _NormalTex;

            float DistributionGGX(float3 N, float3 H, float roughness)
            {
                float a = roughness * roughness;
                float a2 = a * a;
                float NdotH = max(dot(N, H), 0.0);
                float NdotH2 = NdotH * NdotH;

                float nom = a2;
                float denom = (NdotH2 * (a2 - 1.0) + 1.0);
                denom = PI * denom * denom;

                return nom / denom;
            }
            // ----------------------------------------------------------------------------
            // http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
            // efficient VanDerCorpus calculation.
            float RadicalInverse_VdC(uint bits)
            {
                bits = (bits << 16u) | (bits >> 16u);
                bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
                bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
                bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
                bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
                return float(bits) * 2.3283064365386963e-10; // / 0x100000000
            }
            // ----------------------------------------------------------------------------
            float2 Hammersley(uint i, uint N)
            {
                return float2(float(i) / float(N), RadicalInverse_VdC(i));
            }
            // ----------------------------------------------------------------------------
            float3 ImportanceSampleGGX(float2 Xi, float3 N, float roughness)
            {
                float a = roughness * roughness;

                float phi = 2.0 * PI * Xi.x;
                float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0) * Xi.y));  
                float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

                // from spherical coordinates to cartesian coordinates - halfway vector
                //H是球的极坐标转直角坐标
                float3 H;
                H.x = cos(phi) * sinTheta;
                H.y = sin(phi) * sinTheta;
                H.z = cosTheta;

                // from tangent-space H vector to world-space sample vector
                //float3 up = abs(N.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
				float3 up = float3(0.0, 1.0, 0.0);
                float3 tangent = normalize(cross(up, N));
                float3 bitangent = cross(N, tangent);

                float3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
                return normalize(sampleVec);
            }

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
                fixed3 N = normalize(i.posWorld);

                // make the simplyfying assumption that V equals R equals the normal 
                fixed3 R = N;
                fixed3 V = R;

                const uint SAMPLE_COUNT = 1024u;
                half3 prefilteredColor = half3(0.0, 0.0, 0.0);
                float totalWeight = 0.0;

                for (uint i = 0u; i < SAMPLE_COUNT; ++i)
                {
                    // generates a sample vector that's biased towards the preferred alignment direction (importance sampling).
                    float2 Xi = Hammersley(i, SAMPLE_COUNT);
                    float3 H = ImportanceSampleGGX(Xi, N, _roughness);
                    float3 L = normalize(2.0 * dot(V, H) * H - V);   //反射向量，可以理解成lightdirection，用这个来取入射光的颜色

                    float NdotL = max(dot(N, L), 0.0);
                    if (NdotL > 0.0)
                    {
#ifdef PREFILTER_CONVOLUTION
                        // sample from the environment's mip level based on roughness/pdf
                        float D = DistributionGGX(N, H, _roughness);
                        float NdotH = max(dot(N, H), 0.0);
                        float HdotV = max(dot(H, V), 0.0);
                        float pdf = D * NdotH / (4.0 * HdotV) + 0.0001;

                        float resolution = 128.0; // resolution of source cubemap (per face)

                        //球的面积是4π，那一个像素对应的面积就是 4π/(6 * resolution²)
                        float saTexel = 4.0 * PI / (6.0 * resolution * resolution);
                        float saSample = 1.0 / (float(SAMPLE_COUNT) * pdf + 0.0001);

                        float mipLevel = _roughness == 0.0 ? 0.0 : 0.5 * log2(saSample / saTexel);

                        prefilteredColor += UNITY_SAMPLE_TEXCUBE_LOD(_Cube, L, mipLevel).rgb * NdotL;
#else
						prefilteredColor += texCUBE(_Cube, L).rgb * NdotL;
#endif
                        totalWeight += NdotL;
                    }
                }

                prefilteredColor = prefilteredColor / totalWeight;
#if !defined(UNITY_COLORSPACE_GAMMA)
                prefilteredColor.rgb = pow(prefilteredColor.rgb, 2.2);
#endif

                return half4(prefilteredColor, 1.0);
            }
            ENDCG
        }
	}
    //FallBack "Diffuse"
}