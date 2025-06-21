// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Geometry/Grass"
{
	Properties
	{
		_Color ("Bottom Color", Color) = (0.1, 0.4, 0.1, 1)
		_TopColor ("Top Color", Color) = (0.1, 1, 0.1, 1)
		_Size ("Size", Range(0, 1)) = 0.5
		_Tess ("Tessellation", Range(1, 32)) = 5.0
		_HeightOffset ("Height Offset", Float) = 0.0
		_WindSpeed ("Wind Speed", Float) = 0.5
	}

	SubShader
	{
		Tags { "IgnoreProjector" = "True" }
		Cull Off

		CGINCLUDE

		#include "UnityCG.cginc"
		#include "Tessellation.cginc"
		#include "Lighting.cginc"
		#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
			#include "AutoLight.cginc"
		#endif
		
		struct appdata
		{
			float4 pos : POSITION;
			float2 uv : TEXCOORD0;
			float2 uv1 : TEXCOORD1;
		};

		#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
			struct g2f
			{
				UNITY_POSITION(pos);
				#ifdef LIGHTMAP_ON
					float4 uv : TEXCOORD0;
				#else
					float2 uv : TEXCOORD0;
				#endif
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				UNITY_SHADOW_COORDS(3)
				UNITY_FOG_COORDS(4)
				UNITY_VERTEX_OUTPUT_STEREO
			};

			fixed4 _Color, _TopColor;
		#elif defined(UNITY_PASS_SHADOWCASTER)
			struct g2f
			{
				V2F_SHADOW_CASTER;
				UNITY_VERTEX_OUTPUT_STEREO
			};
		#endif

		fixed _Size;
		half _Tess;
		fixed _HeightOffset;
		half _WindSpeed;

		inline float2 hash22(float2 p)
		{
			return frac(float2(262144, 32768) * sin(dot(p, float2(41, 289))));
		}

		inline float CubicSmooth(float x)
		{
			return x * x * (3.0 - 2.0 * x);
		}

		inline float TriangleWave(float x)
		{
			return abs((frac(x + 0.5) * 2.0) - 1.0);
		}

		inline float TrigApproximate(float x)
		{
			return CubicSmooth(TriangleWave(x)) * 2.0 - 1.0;
		}

		appdata vert(appdata v)
		{
			#ifdef LIGHTMAP_ON
				v.uv1.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
			#endif
			return v;
		}

		UnityTessellationFactors hullconst(InputPatch < appdata, 3 > v)
		{
			UnityTessellationFactors o;
			o.edge[0] = _Tess;
			o.edge[1] = _Tess;
			o.edge[2] = _Tess;
			o.inside = _Tess;
			return o;
		}

		[UNITY_domain("tri")]
		[UNITY_partitioning("fractional_odd")]
		[UNITY_outputtopology("triangle_cw")]
		[UNITY_patchconstantfunc("hullconst")]
		[UNITY_outputcontrolpoints(3)]
		appdata hull(InputPatch < appdata, 3 > v, uint id : SV_OutputControlPointID)
		{
			return v[id];
		}

		[UNITY_domain("tri")]
		appdata doma(UnityTessellationFactors tessFactors, const OutputPatch < appdata, 3 > vi, float3 bary : SV_DomainLocation)
		{
			appdata v;
			UNITY_INITIALIZE_OUTPUT(appdata, v);
			v.pos = vi[0].pos * bary.x + vi[1].pos * bary.y + vi[2].pos * bary.z;
			v.uv = hash22(vi[0].uv * bary.x + vi[1].uv * bary.y + vi[2].uv * bary.z);
			v.uv1 = vi[0].uv1 * bary.x + vi[1].uv1 * bary.y + vi[2].uv1 * bary.z;
			return v;
		}

		[maxvertexcount(9)]
		void geom(line appdata input[2], inout TriangleStream<g2f> outStream)
		{
			g2f o;
			UNITY_INITIALIZE_OUTPUT(g2f, o);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

			float seed[4] = {
				(input[0].uv.x + input[1].uv.x), (input[0].uv.y + input[1].uv.y) * 0.5, (input[0].uv.x + input[1].uv.y) * 0.5, (input[0].uv.y + input[1].uv.x)
			};
			float2 s;
			sincos(seed[0] * UNITY_TWO_PI, s.y, s.x);
			float4x4 rotationMatrix = 0;
			rotationMatrix._m00 = s.x;
			rotationMatrix._m20 = s.y;
			rotationMatrix._m11 = 1;
			rotationMatrix._m02 = -s.y;
			rotationMatrix._m22 = s.x;

			float width = length(mul(unity_ObjectToWorld, input[1].pos - input[0].pos).xyz);
			float4 pos = mul(unity_ObjectToWorld, lerp(input[0].pos, input[1].pos, seed[2]));
			pos.y += _HeightOffset;
			float scale = 1.0 + seed[1] * seed[1] * seed[1];
			float wave = 0.01 * TrigApproximate(_Time.y / scale * _WindSpeed + seed[3]);
			scale *= _Size;
			float4 worldPos;
			#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
				o.worldNormal = float3(-s.y, 0, s.x);
				float2 uv1 = lerp(input[0].uv1, input[1].uv1, seed[2]);
				#ifdef LIGHTMAP_ON
					o.uv.zw = uv1;
				#endif
			#elif defined(UNITY_PASS_SHADOWCASTER)
				appdata_base v;
				UNITY_INITIALIZE_OUTPUT(appdata_base, v);
				v.normal = normalize(mul((float3x3)unity_WorldToObject, float3(-s.y, 0, s.x)));
			#endif

			[unroll]
			for (int y = 0; y < 5; y++)
			{
				[unroll]
				for (int x = 0; x < 2; x++)
				{
					worldPos = pos + mul(rotationMatrix, float4(float2((x - 0.5) * (1.0 - y * 0.25) * width, y * 0.25) * scale, 0, 0));
					worldPos.x += y * y * wave * scale;
					#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
						o.uv.xy = float2(x, y * 0.25);
						o.worldPos = worldPos;
						o.pos = UnityWorldToClipPos(o.worldPos);
						UNITY_TRANSFER_SHADOW(o, uv1);
						UNITY_TRANSFER_FOG(o, o.pos);
					#elif defined(UNITY_PASS_SHADOWCASTER)
						v.vertex = mul(unity_WorldToObject, worldPos);
						TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
					#endif
					outStream.Append(o);
				}
			}
			outStream.RestartStrip();
		}

		ENDCG

		Pass
		{
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }

			CGPROGRAM
			#pragma target 5.0
			#pragma vertex vert
			#pragma hull hull
			#pragma domain doma
			#pragma geometry geom
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog

			fixed4 frag(g2f IN, fixed facing : VFACE) : SV_Target
			{
				UNITY_LIGHT_ATTENUATION(atten, IN, IN.worldPos)
				half4 baseColor = lerp(_Color, _TopColor, IN.uv.y);
				half4 c = baseColor * atten;
				c.rgb *= _LightColor0.rgb;
				c.rgb *= 0.5 + 0.5 * saturate(dot(IN.worldNormal * facing, _WorldSpaceLightPos0.xyz));
				#ifdef LIGHTMAP_ON
					half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, IN.uv.zw);
					c.rgb += baseColor.rgb * DecodeLightmap(bakedColorTex);
				#endif
				UNITY_APPLY_FOG(IN.fogCoord, c);
				UNITY_OPAQUE_ALPHA(c.a);
				return c;
			}
			ENDCG
		}

		Pass
		{
			Name "FORWARD"
			Tags { "LightMode" = "ForwardAdd" }
			ZWrite Off
			Blend One One

			CGPROGRAM
			#pragma target 5.0
			#pragma vertex vert
			#pragma hull hull
			#pragma domain doma
			#pragma geometry geom
			#pragma fragment frag
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			
			fixed4 frag(g2f IN, fixed facing : VFACE) : SV_Target
			{
				#ifndef USING_DIRECTIONAL_LIGHT
					fixed3 lightDir = normalize(UnityWorldSpaceLightDir(IN.worldPos));
				#else
					fixed3 lightDir = _WorldSpaceLightPos0.xyz;
				#endif
				UNITY_LIGHT_ATTENUATION(attenuation, IN, IN.worldPos);
				fixed4 c = lerp(_Color, _TopColor, IN.uv.y);
				c.rgb *= saturate(dot(IN.worldNormal * facing, lightDir)) * _LightColor0 * attenuation;
				UNITY_APPLY_FOG(IN.fogCoord, c);
				UNITY_OPAQUE_ALPHA(c.a);
				return c;
			}
			ENDCG
		}

		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			CGPROGRAM
			#pragma target 5.0
			#pragma vertex vert
			#pragma hull hull
			#pragma domain doma
			#pragma geometry geom
			#pragma fragment frag
			#pragma multi_compile_shadowcaster

			float4 frag(g2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
}
