// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Geometry/Boxel"
{
	Properties
	{
		_Color ("Main Color", Color) = (1, 1, 1, 1)
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_EmissionColor ("Emission Color", Color) = (0, 0, 0, 0)
		[NoScaleOffset] _EmissionMap ("Emission Map", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = .5
		_Metallic ("Metallic", Range(0,1)) = .0
		_CubeSize ("Cube Size", Float) = .8
	}
	SubShader
	{
		Tags { "IgnoreProjector" = "True" "DisableBatching" = "True" }

		CGINCLUDE
		
		#pragma target 5.0
		#pragma vertex vert
		#pragma geometry geom
		#pragma fragment frag
		
		#include "UnityCG.cginc"

		#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
		#pragma multi_compile_fog

		#include "Lighting.cginc"
		#include "AutoLight.cginc"
		#include "UnityPBSLighting.cginc"
		
		sampler2D _MainTex;
		float4 _MainTex_ST;
		#endif

		struct appdata
		{
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
		};

		struct g2f
		{
			#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				UNITY_SHADOW_COORDS(3)
				UNITY_FOG_COORDS(4)
				#if UNITY_SHOULD_SAMPLE_SH && defined(UNITY_PASS_FORWARDBASE)
				float3 sh: TEXCOORD5;
				#endif
			#elif defined(UNITY_PASS_SHADOWCASTER)
				V2F_SHADOW_CASTER;
			#endif
			UNITY_VERTEX_OUTPUT_STEREO
		};
		
		fixed _CubeSize;

		static fixed3 face[6] = {float3(1, 0, 0),
								 float3(0, 0, 0),
								 float3(0, 1, 0),
								 float3(0, 0, 1),
								 float3(0, 0, 1),
								 float3(0, 1, 0)};

		appdata vert(appdata v)
		{
			return v;
		}

		[maxvertexcount(24)]
		void geom(triangle appdata input[3], inout TriangleStream<g2f> outStream)
		{
			g2f o;
			UNITY_INITIALIZE_OUTPUT(g2f, o);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

			float3 area = cross((input[1].vertex - input[0].vertex).xyz, (input[2].vertex - input[0].vertex).xyz);
			float size = _CubeSize * pow(area.x * area.x + area.y * area.y + area.z * area.z, 0.25);
			float4 pivotPos = (input[0].vertex + input[1].vertex + input[2].vertex) / 3.0;
			pivotPos.xyz -= size * 0.5;

			#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
			o.uv = (input[0].uv + input[1].uv + input[2].uv) / 3.0;
			o.uv = TRANSFORM_TEX(o.uv, _MainTex);
			#elif defined(UNITY_PASS_SHADOWCASTER)
			appdata_base v;
			UNITY_INITIALIZE_OUTPUT(appdata_base, v);
			#endif

			float3 normal;
			float4 pos;

			[unroll]
			for(int z = 0; z < 6; ++z)
			{
				normal = 0;
				normal[floor(z / 2)] = 1;
				normal *= (1 - (z % 2) * 2);
				#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
				o.worldNormal = UnityObjectToWorldNormal(normal);
				#elif defined(UNITY_PASS_SHADOWCASTER)
				v.normal = normal;
				#endif

				[unroll]
				for(int x = 0; x < 2; ++x)
				{
					[unroll]
					for(int y = 0; y < 2; ++y)
					{
						pos = pivotPos + float4(dot(face[z], float3(1, x, y)), dot(face[(z + 4) % 6], float3(1, x, y)), dot(face[(z + 2) % 6], float3(1, x, y)), 0) * size;
						#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
						o.pos = pos;
						o.worldPos = mul(unity_ObjectToWorld, o.pos).xyz;
						o.pos = UnityObjectToClipPos(o.pos);
						
						#if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL && defined(UNITY_PASS_FORWARDBASE)
							o.sh = 0;
							#ifdef VERTEXLIGHT_ON
								o.sh += Shade4PointLights(
								unity_4LightPosX0,
								unity_4LightPosY0,
								unity_4LightPosZ0,
								unity_LightColor[0].rgb,
								unity_LightColor[1].rgb,
								unity_LightColor[2].rgb,
								unity_LightColor[3].rgb,
								unity_4LightAtten0,
								o.worldPos,
								o.worldNormal);
							#endif
							o.sh = ShadeSHPerVertex(o.worldNormal, o.sh);
						#endif

						UNITY_TRANSFER_SHADOW(o,o.uv);
						UNITY_TRANSFER_FOG(o,o.pos);
						
						#elif defined(UNITY_PASS_SHADOWCASTER)
						v.vertex = pos;
						TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
						#endif

						outStream.Append(o);
					}
				}
				outStream.RestartStrip();
			}
		}

		ENDCG

		Pass
		{
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }

			CGPROGRAM
			#pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap

			fixed4 _Color;
			sampler2D _EmissionMap;
			fixed4 _EmissionColor;
			fixed _Glossiness;
			fixed _Metallic;
			
			fixed4 frag(g2f IN) : SV_Target
			{
				float3 worldPos = IN.worldPos;
				float3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

				#ifndef USING_DIRECTIONAL_LIGHT
					fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				#else
					fixed3 lightDir = _WorldSpaceLightPos0.xyz;
				#endif
				
				SurfaceOutputStandard o;
				UNITY_INITIALIZE_OUTPUT(SurfaceOutputStandard, o);
				o.Albedo = tex2D(_MainTex, IN.uv) * _Color;
				o.Emission = tex2D(_EmissionMap, IN.uv) * _EmissionColor;
				o.Alpha = 1.0;
				o.Occlusion = 1.0;
				o.Normal = IN.worldNormal;
				o.Metallic = _Metallic;
				o.Smoothness = _Glossiness;

				UNITY_LIGHT_ATTENUATION(atten, IN, worldPos)

				fixed4 c = 0;

				UnityGI gi;
				UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
				gi.indirect.diffuse = 0;
				gi.indirect.specular = 0;
				gi.light.color = _LightColor0.rgb;
				gi.light.dir = lightDir;

				UnityGIInput giInput;
				UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
				giInput.light = gi.light;
				giInput.worldPos = worldPos;
				giInput.worldViewDir = worldViewDir;
				giInput.atten = atten;
				giInput.lightmapUV = 0.0;

				#if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
					giInput.ambient = IN.sh;
				#else
					giInput.ambient.rgb = 0.0;
				#endif

				giInput.probeHDR[0] = unity_SpecCube0_HDR;
				giInput.probeHDR[1] = unity_SpecCube1_HDR;

				#if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
					giInput.boxMin[0] = unity_SpecCube0_BoxMin;
				#endif

				#ifdef UNITY_SPECCUBE_BOX_PROJECTION
					giInput.boxMax[0] = unity_SpecCube0_BoxMax;
					giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
					giInput.boxMax[1] = unity_SpecCube1_BoxMax;
					giInput.boxMin[1] = unity_SpecCube1_BoxMin;
					giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
				#endif

				LightingStandard_GI(o, giInput, gi);
				c += LightingStandard(o, worldViewDir, gi);
				c.rgb += o.Emission;

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
			#pragma multi_compile_fwdadd_fullshadows

			fixed4 _Color;
			sampler2D _EmissionMap;
			fixed4 _EmissionColor;
			fixed _Glossiness;
			fixed _Metallic;

			fixed4 frag(g2f IN) : SV_Target
			{
				float3 worldPos = IN.worldPos;
				float3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				#ifndef USING_DIRECTIONAL_LIGHT
					fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				#else
					fixed3 lightDir = _WorldSpaceLightPos0.xyz;
				#endif

				SurfaceOutputStandard o;
				UNITY_INITIALIZE_OUTPUT(SurfaceOutputStandard, o);
				o.Albedo = tex2D(_MainTex, IN.uv) * _Color;
				o.Emission = 0;
				o.Alpha = 1.0;
				o.Occlusion = 1.0;
				o.Normal = IN.worldNormal;
				o.Metallic = _Metallic;
				o.Smoothness = _Glossiness;

				UNITY_LIGHT_ATTENUATION(atten, IN, worldPos)
				fixed4 c = 0;

				UnityGI gi;
				UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
				gi.indirect.diffuse = 0;
				gi.indirect.specular = 0;
				gi.light.color = _LightColor0.rgb;
				gi.light.dir = lightDir;
				gi.light.color *= atten;

				c += LightingStandard(o, worldViewDir, gi);
				c.a = 0.0;

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
			#pragma multi_compile_shadowcaster

			float4 frag(g2f i) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
}
