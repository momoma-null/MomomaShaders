// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Fragment/WarpGate"
{
	Properties
	{
		_Height ("Height", Range(0, 1)) = 0.1
		_Speed ("Speed", Float) = 1.0
		_Glossiness ("Smoothness", Range(0,1)) = 0.85
	}
	SubShader
	{
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma target 3.0

			#include "UnityCG.cginc"
			#include "UnityStandardConfig.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float3 objPos : TEXCOORD2;
				float4 vertex : SV_POSITION;
			};

			fixed _Height, _Speed, _Glossiness;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.objPos = v.vertex;
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			inline float hash21(float2 p)
			{
				float h = dot(p, float2(127.1, 311.7));
				return frac(sin(h) * 43758.5453123);
			}

			float noise(float p)
			{
				float i = floor(p);
				float f = frac(p);

				float u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

				float a = hash21(i);
				float b = hash21(i + 1.0);
				
				return lerp(a, b, u);
			}

			float fbm(float2 p)
			{
				float r = length(p) - _Speed * _Time.y;
				float f = 0;
				f += noise(r) * 0.5;
				r *= 2.0;
				f += noise(r) * 0.25;
				r *= 2.0;
				f += noise(r) * 0.125;
				return f / 0.875;
			}

			float3 getNormal(float2 uv)
			{
				float2 dx = ddx(uv);
				float2 dy = ddy(uv);
				float h0 = _Height * fbm(uv);
				float h1 = _Height * fbm(uv + dx);
				float h2 = _Height * fbm(uv + dy);
				return normalize(cross(float3(dx, h1 - h0), float3(dy, h2 - h0)));
			}

			inline float3 boxProjection(float3 normalizedDir, float3 worldPosition, float4 probePosition, float3 boxMin, float3 boxMax)
			{
				#if UNITY_SPECCUBE_BOX_PROJECTION
					if (probePosition.w > 0)
					{
						float3 magnitudes = ((normalizedDir > 0 ? boxMax : boxMin) - worldPosition) / normalizedDir;
						float magnitude = min(min(magnitudes.x, magnitudes.y), magnitudes.z);
						normalizedDir = normalizedDir * magnitude + (worldPosition - probePosition);
					}
				#endif

				return normalizedDir;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float3 normal = getNormal((i.uv - 0.5) * 10.0);
				float3 eyePos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));
				float3 direction = UnityObjectToWorldDir(i.objPos - eyePos);
				float3 worldPos = mul(unity_ObjectToWorld, float4(i.objPos, 1.0));
				float3 reflDir = reflect(direction, normal);
				float3 reflDir0 = boxProjection(reflDir, worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
				float3 reflDir1 = boxProjection(reflDir, worldPos, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
				float4 refColor0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir0, (1.0 - _Glossiness) * UNITY_SPECCUBE_LOD_STEPS);
				float4 refColor1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, reflDir1, (1.0 - _Glossiness) * UNITY_SPECCUBE_LOD_STEPS);
				refColor0.rgb = DecodeHDR(refColor0, unity_SpecCube0_HDR);
				refColor1.rgb = DecodeHDR(refColor1, unity_SpecCube1_HDR);
				float4 c = lerp(refColor1, refColor0, unity_SpecCube0_BoxMin.w);

				UNITY_APPLY_FOG(i.fogCoord, c);
				return c;
			}
			ENDCG
		}
	}
	FallBack "Standard"
}
