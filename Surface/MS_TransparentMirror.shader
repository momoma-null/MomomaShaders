// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Surface/TransparentMirror"
{
	Properties
	{
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Culling", Float) = 0
		_Color ("Color", Color) = (1, 1, 1, 1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_BackReflectivity ("Back Reflectivity", Range(0, 1)) = 0.5
		_ReflectionIntencity ("Reflection Intencity", Range(0, 10)) = 1
		[HideInInspector] _ReflectionTex0("", 2D) = "black" {}
		[HideInInspector] _ReflectionTex1("", 2D) = "black" {}
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }

		Cull [_Cull]
		ZWrite Off

		CGPROGRAM
		#pragma surface surf Mirror addshadow fullforwardshadows alpha:premul exclude_path:deferred
		#pragma target 3.0

		#include "UnityPBSLighting.cginc"

		struct Input
		{
			float2 uv_MainTex;
			float facing : VFACE;
		};

		UNITY_DECLARE_TEX2D(_MainTex);
		UNITY_DECLARE_TEX2D(_ReflectionTex0);
		UNITY_DECLARE_TEX2D(_ReflectionTex1);
		
		UNITY_INSTANCING_BUFFER_START(Props)
		UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
		UNITY_DEFINE_INSTANCED_PROP(half, _BackReflectivity)
		UNITY_DEFINE_INSTANCED_PROP(half, _ReflectionIntencity)
		UNITY_INSTANCING_BUFFER_END(Props)

		fixed facing;

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			fixed4 c = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv_MainTex) * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			o.Metallic = 0;
			o.Smoothness = 1;
			facing = IN.facing > 0;
		}

		inline half4 LightingMirror(SurfaceOutputStandard s, float3 viewDir, UnityGI gi)
		{
			s.Normal = normalize(s.Normal);
			half oneMinusReflectivity;
			half3 specColor;
			s.Albedo = DiffuseAndSpecularFromMetallic(s.Albedo, s.Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);
			half outputAlpha;
			s.Albedo = PreMultiplyAlpha(s.Albedo, s.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);
			half4 c = UNITY_BRDF_PBS(s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
			c.a = outputAlpha;
			return c;
		}

		inline void LightingMirror_GI(SurfaceOutputStandard s, UnityGIInput data, inout UnityGI gi)
		{
			LightingStandard_GI(s, data, gi);
			float4 oPos = mul(unity_WorldToObject, float4(data.worldPos, 1));
			float4 oCPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
			oPos.z *= exp(-abs(oPos.z - oCPos.z) * 10);
			float4 projUv = UNITY_PROJ_COORD(ComputeNonStereoScreenPos(UnityObjectToClipPos(oPos)));
			float2 uv = projUv.xy / projUv.w;
			float4 mirrorSpecular = unity_StereoEyeIndex == 0 ? UNITY_SAMPLE_TEX2D(_ReflectionTex0, uv) : UNITY_SAMPLE_TEX2D(_ReflectionTex1, uv);
			mirrorSpecular *= UNITY_ACCESS_INSTANCED_PROP(Props, _ReflectionIntencity);
			gi.indirect.specular = lerp(gi.indirect.specular, mirrorSpecular.rgb, mul((float3x3)unity_WorldToObject, data.worldViewDir).z < 0);
			gi.indirect.specular *= lerp(UNITY_ACCESS_INSTANCED_PROP(Props, _BackReflectivity), 1, facing > 0);
		}
		ENDCG
	}
	FallBack "Standard"
}
