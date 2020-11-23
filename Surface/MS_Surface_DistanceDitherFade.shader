// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Surface/DistanceDitherFade"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		[Normal][NoScaleOffset] _BumpMap ("NormalMap", 2D) = "bump" {}
		[NoScaleOffset] _EmissionMap ("Emission", 2D) = "black" {}
		_Distance ("Disappearance distance" , Range(0,30)) = 5.0
		_DitherAmount ("Dither Amount", Range(0, 1)) = 0.5
		[Enum(Off, 0, On, 1)] _FadeReverse ("Fade Reverse", Float) = 0
	}
	SubShader
	{
		Tags { "RenderType" = "TransparentCutout" "Queue" = "AlphaTest" }

		AlphaToMask On

		CGINCLUDE

		fixed _Distance;
		fixed _DitherAmount;
		fixed _FadeReverse;

		inline fixed dither(float3 worldPos, float2 seed)
		{
			float d0 = distance(worldPos, _WorldSpaceCameraPos);
			float d1 = _Distance * lerp(1, frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453), _DitherAmount);
			return saturate((d0 - d1) * (_FadeReverse * 2 - 1));
		}

		ENDCG

		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows alphatest:_
		#pragma target 3.0

		struct Input
		{
			float2 uv_MainTex;
			float3 worldPos;
		};

		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _EmissionMap;
		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		UNITY_INSTANCING_BUFFER_START(Props)
		UNITY_INSTANCING_BUFFER_END(Props)

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Alpha = c.a * dither(IN.worldPos, IN.uv_MainTex);
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
			o.Emission = tex2D(_EmissionMap, IN.uv_MainTex);
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
				float3 worldPos : TEXCOORD2;
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
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				return o;
			}

			sampler2D _MainTex;
			fixed4 _Color;

			inline float3 shadow()
			{
				SHADOW_CASTER_FRAGMENT(i)
			}

			float4 frag( v2f i ) : SV_Target
			{
				fixed a = tex2D (_MainTex, i.uv).a * _Color.a;
				a *= dither(i.worldPos, i.uv);
				return float4(shadow(), a);
			}
			ENDCG
		}
	}
	Fallback "Standard"
}
