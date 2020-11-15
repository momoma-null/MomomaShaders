// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Surface/AlphaToCoverage_Roughness"
{
	Properties
	{
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Culling", Float) = 0
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		[Normal][NoScaleOffset] _BumpMap ("Normal Map", 2D) = "bump" {}
		_Metallic ("Metallic", Range(0,1)) = 0.0
		[NoScaleOffset] _MetalicMap ("Metalic Map", 2D) = "white" {}
		_Glossiness ("Roughness", Range(0,1)) = 0.5
		[NoScaleOffset] _SpecGlossMap ("Roughness Map", 2D) = "white" {}
		_ClipAlpha ("Clip Alpha", Range(0.15, 0.85)) = 0.5
	}
	SubShader
	{
		Tags { "RenderType" = "TransparentCutout" "Queue" = "AlphaTest" }

		Cull [_Cull]
		AlphaToMask On

		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows alphatest:_
		#pragma target 3.0

		struct Input
		{
			float2 uv_MainTex;
			float facing : VFACE;
		};

		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _MetalicMap;
		sampler2D _SpecGlossMap;
		half _Metallic;
		half _Glossiness;
		fixed4 _Color;
		fixed _ClipAlpha;

		UNITY_INSTANCING_BUFFER_START(Props)
		UNITY_INSTANCING_BUFFER_END(Props)

		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Normal = IN.facing * UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
			o.Metallic = tex2D (_MetalicMap, IN.uv_MainTex) * _Metallic;
			float roughness = tex2D(_SpecGlossMap, IN.uv_MainTex) * _Glossiness;
			o.Smoothness = 1 - sqrt(roughness);
			o.Alpha = saturate((c.a - _ClipAlpha) / max(fwidth(c.a), 0.0001) + 0.5);
		}
		ENDCG

		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"

			struct v2f
			{
				V2F_SHADOW_CASTER;
				float2  uv : TEXCOORD1;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			float4 _MainTex_ST;

			v2f vert(appdata_base v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				return o;
			}

			sampler2D _MainTex;
			fixed4 _Color;
			fixed _ClipAlpha;

			inline float3 shadow()
			{
				SHADOW_CASTER_FRAGMENT(i)
			}

			float4 frag( v2f i ) : SV_Target
			{
				fixed a = tex2D (_MainTex, i.uv).a * _Color.a;
				a = saturate((a - _ClipAlpha) / max(fwidth(a), 0.0001) + 0.5);
				return float4(shadow(), a);
			}
			ENDCG
		}
	}
	FallBack "Standard"
}
