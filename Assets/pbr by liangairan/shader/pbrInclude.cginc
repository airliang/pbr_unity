#define PI 3.14159265359

//F(v,h)公式 cosTheta = v dot h
half3 fresnelSchlick(float cosTheta, half3 F0)
{
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

half3 DiffuseLambert(half3 diffuse)
{
	return diffuse / PI;
}

//D(h)GGX公式，计算法线分布
//alpha = roughness * roughness
float normalDistribution_GGX(float alpha, float ndh)
{
	if (ndh == 0)
		return 0;
	float alphaPow = alpha * alpha;
	float t = ndh * ndh * (alphaPow - 1) + 1;
	return alphaPow / (PI * t * t);
	//float ndhPow2 = ndh * ndh;
	//float tanSita_pow = (1 - ndhPow2) / (ndh * ndh + 0.00001);
	//float t = alphaPow + tanSita_pow;
	//float D = alphaPow * ndh / (ndhPow2 * ndhPow2 * PI * t * t);
	//return D;
}

float GGX_GSF(float roughness, float ndv, float ndl)
{
	//float tan_ndv_pow = (1 - ndv * ndv) / (ndv * ndv + 0.00001);

	//return (ndl / ndv) * 2 / (1 + sqrt(1 + roughness * roughness * tan_ndv_pow));
	float k = roughness / 2;


	float SmithL = (ndl) / (ndl * (1 - k) + k);
	float SmithV = (ndv) / (ndv * (1 - k) + k);


	float Gs = (SmithL * SmithV);
	return Gs;
}

float BeckmannNormalDistribution(float roughness, float NdotH)
{
	float roughnessSqr = roughness * roughness;
	float NdotHSqr = NdotH * NdotH;
	return max(0.000001, (1.0 / (3.1415926535 * roughnessSqr * NdotHSqr*NdotHSqr)) * exp((NdotHSqr - 1) / (roughnessSqr*NdotHSqr)));
}

//G(l,v,h)，计算微表面遮挡
float smith_schilck(float roughness, float ndv, float ndl)
{
	float k = (roughness + 1) * (roughness + 1) / 8;
	float Gv = ndv / (ndv * (1 - k) + k);
	float Gl = ndl / (ndl * (1 - k) + k);
	return Gv * Gl;
}

float Schilck_GSF(float roughness, float ndv, float ndl)
{
	float roughnessSqr = roughness * roughness;
	float Gv = ndv / (ndv * (1 - roughnessSqr) + roughnessSqr);
	float Gl = ndl / (ndl * (1 - roughnessSqr) + roughnessSqr);
	return Gv * Gl;
}

float MixFunction(float i, float j, float x) 
{
	return  j * x + i * (1.0 - x);
}

float SchlickFresnel(float i) {
	float x = clamp(1.0 - i, 0.0, 1.0);
	float x2 = x * x;
	return x2 * x2*x;
}

float F0(float NdotL, float NdotV, float LdotH, float roughness) {
	float FresnelLight = SchlickFresnel(NdotL);
	float FresnelView = SchlickFresnel(NdotV);
	float FresnelDiffuse90 = 0.5 + 2.0 * LdotH*LdotH * roughness;
	return  MixFunction(1, FresnelDiffuse90, FresnelLight) * MixFunction(1, FresnelDiffuse90, FresnelView);
}

half3 brdf(half3 fresnel, float D, float G, float ndv, float ndl)
{
	return fresnel * D * G / (4 * ndv * ndl + 0.0001);
}