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
		_Tess ("Tessellation", Range(0, 10)) = 5.0
		_TessMin ("Min Distance", Range(0, 100)) = 10.0
		_TessMax ("Max Distance", Range(0, 100)) = 25.0
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
		#elif defined(UNITY_PASS_SHADOWCASTER)
		struct g2f
		{
			V2F_SHADOW_CASTER;
			UNITY_VERTEX_OUTPUT_STEREO
		};	
		#endif

		fixed _Size;
		fixed _Tess, _TessMin, _TessMax;

		inline float2 hash22(float2 p)
		{
			return frac(float2(262144, 32768) * sin(dot(p, float2(41, 289)))); 
		}

		appdata vert(appdata v)
		{
			v.uv = hash22(v.uv);
			return v;
		}

		UnityTessellationFactors hullconst(InputPatch<appdata, 3> v)
		{
			UnityTessellationFactors o;
			#if defined(USING_STEREO_MATRICES)
			float4 offset = float4(_WorldSpaceCameraPos - unity_StereoWorldSpaceCameraPos[0], 0);
			float4 tf = UnityDistanceBasedTess(v[0].pos + offset, v[1].pos + offset, v[2].pos + offset, _TessMin, _TessMax, _Tess);
			#else
			float4 tf = UnityDistanceBasedTess(v[0].pos, v[1].pos, v[2].pos, _TessMin, _TessMax, _Tess);
			#endif
			o.edge[0] = tf.x;
			o.edge[1] = tf.y;
			o.edge[2] = tf.z;
			o.inside = tf.w;
			return o;
		}

		[UNITY_domain("tri")]
		[UNITY_partitioning("fractional_odd")]
		[UNITY_outputtopology("triangle_cw")]
		[UNITY_patchconstantfunc("hullconst")]
		[UNITY_outputcontrolpoints(3)]
		appdata hull(InputPatch<appdata, 3> v, uint id : SV_OutputControlPointID)
		{
			return v[id];
		}

		[UNITY_domain("tri")]
		appdata doma(UnityTessellationFactors tessFactors, const OutputPatch<appdata, 3> vi, float3 bary : SV_DomainLocation)
		{
			appdata v;
			UNITY_INITIALIZE_OUTPUT(appdata, v);
			v.pos = vi[0].pos * bary.x + vi[1].pos * bary.y + vi[2].pos * bary.z;
			v.uv = vi[0].uv * bary.x + vi[1].uv * bary.y + vi[2].uv * bary.z;
			return v;
		}

		[maxvertexcount(9)]
		void geom(line appdata input[2], inout TriangleStream<g2f> outStream)
		{
			g2f o;
			UNITY_INITIALIZE_OUTPUT(g2f, o);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

			float seed[4] = {(input[0].uv.x + input[1].uv.x), (input[0].uv.y + input[1].uv.y) * 0.5, (input[0].uv.x + input[1].uv.y) * 0.5, (input[0].uv.y + input[1].uv.x)};
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
			float scale = 1.0 + seed[1] * seed[1] * seed[1];
			float wave = 0.01 * sin(_Time.y / scale + seed[3] * UNITY_TWO_PI);
			scale *= _Size;
			float3 worldPos;
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
					worldPos = pos + mul(rotationMatrix, float4(float2((x - 0.5) * (1.0 - y * 0.25) * width, y * 0.25) * scale, 0, 0));
					worldPos.x += y * y * wave * scale;
					#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
					o.uv = float2(x, y * 0.25);
					o.worldPos = worldPos;
					o.pos = UnityWorldToClipPos(o.worldPos);
					UNITY_TRANSFER_SHADOW(o, o.uv);
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
			#pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap
			#pragma multi_compile_fog

			fixed4 frag(g2f IN, fixed facing : VFACE) : SV_Target
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
