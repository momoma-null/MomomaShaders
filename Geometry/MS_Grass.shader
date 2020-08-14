// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Geometry/Grass"
{
	Properties
	{
		_Color ("Bottom Color", Color) = (0.1, 1, 0.1, 1)
		_TopColor ("Top Color", Color) = (0.1, 0.4, 0.1, 1)
		_Size ("Particle Size", Range(0, 1)) = 0.5
	}

	SubShader
	{
		Tags { "IgnoreProjector" = "True" }
		Cull Off

		CGINCLUDE

		#include "UnityCG.cginc"
		#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
		#include "Lighting.cginc"
		#include "AutoLight.cginc"
		#endif
			
		struct appdata
		{
			float4 pos : POSITION;
			float2 uv : TEXCOORD0;
		};

		#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
		struct g2f
		{
			UNITY_POSITION(pos);
			float2 uv : TEXCOORD0;
			float3 worldNormal : TEXCOORD1;
			float3 worldPos : TEXCOORD2;
			UNITY_SHADOW_COORDS(3)
			UNITY_FOG_COORDS(4)
			UNITY_VERTEX_OUTPUT_STEREO
		};

		fixed4 _Color, _TopColor;	
		#endif
		#ifdef UNITY_PASS_SHADOWCASTER
		struct g2f
		{
			V2F_SHADOW_CASTER;
			UNITY_VERTEX_OUTPUT_STEREO
		};	
		#endif

		fixed _Size;

		appdata vert (appdata v)
		{
			return v;
		}

		inline float hash21(float2 p)
		{
			float h = dot(p, float2(127.1, 311.7));
			return frac(sin(h) * 43758.5453123);
		}
		
		[maxvertexcount(9)]
		void geom (line appdata input[2], inout TriangleStream<g2f> outStream)
		{
			g2f o;
			UNITY_INITIALIZE_OUTPUT(g2f, o);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

			float2 s;
			sincos(hash21(input[0].uv) * UNITY_PI, s.y, s.x);
			float4x4 rotationMatrix = 0;
			rotationMatrix._m00 = s.x;
			rotationMatrix._m20 = s.y;
			rotationMatrix._m11 = 1;
			rotationMatrix._m02 = -s.y;
			rotationMatrix._m22 = s.x;
				
			float seed = hash21(input[1].uv);
			float scale = 1.0 + seed * seed * seed;
			float size = _Size * scale;
			float4 pos = mul(unity_ObjectToWorld, lerp(input[0].pos, input[1].pos, hash21(input[0].uv * 3.7)));
			seed = hash21(input[1].uv * 4.1);
			#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
			o.worldNormal = float3(-s.y, 0, s.x);
			#elif defined(UNITY_PASS_SHADOWCASTER)
			appdata_base v;
			UNITY_INITIALIZE_OUTPUT(appdata_base, v);
			v.normal = normalize(mul((float3x3)unity_WorldToObject, float3(-s.y, 0, s.x)));
			#endif
			
			[unroll]
			for(int y = 0; y < 5; y++)
			{
				[unroll]
				for(int x = 0; x < 2; x++)
				{		
					#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
					o.uv = float2(x, y * 0.25);
					o.worldPos = pos + mul(rotationMatrix, float4(float2((x - 0.5) * (0.2 - y * 0.05), y * 0.25) * size, 0, 0));
					o.worldPos.x += 0.02 * y * sin(_Time.y / scale + seed * UNITY_TWO_PI) * size;
					o.pos = UnityWorldToClipPos(o.worldPos);
					UNITY_TRANSFER_SHADOW(o, o.uv);
					UNITY_TRANSFER_FOG(o, o.pos);
					#endif
					#ifdef UNITY_PASS_SHADOWCASTER
					v.vertex = pos + mul(rotationMatrix, float4(float2((x - 0.5) * (0.2 - y * 0.05), y * 0.25) * size, 0, 0));
					v.vertex.x += 0.02 * y * sin(_Time.y / scale + seed * UNITY_TWO_PI) * size;
					v.vertex = mul(unity_WorldToObject, v.vertex);
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
			#pragma geometry geom
			#pragma fragment frag
			#pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap
			#pragma multi_compile_fog
			
			fixed4 frag (g2f IN, fixed facing : VFACE) : SV_Target
			{
				UNITY_LIGHT_ATTENUATION(atten, IN, IN.worldPos)
				fixed4 c = lerp(_Color, _TopColor, IN.uv.y);
				c.rgb *= _LightColor0.rgb * atten;
				c.rgb *= 0.5 + 0.5 * saturate(dot(IN.worldNormal * facing, _WorldSpaceLightPos0.xyz));
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
			#pragma geometry geom
			#pragma fragment frag
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			
			fixed4 frag (g2f IN, fixed facing : VFACE) : SV_Target
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
