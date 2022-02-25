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
		_Metallic ("Metallic", Range(0,1)) = 1.0
		_Glossiness ("Smoothness", Range(0,1)) = 0.75
		_BackReflectivity ("Back Reflectivity", Range(0,1)) = 0.5
		[HideInInspector] _ReflectionTex0("", 2D) = "white" {}
		[HideInInspector] _ReflectionTex1("", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }

		Cull [_Cull]
		ZWrite Off

		CGPROGRAM
		#pragma surface surf Standard addshadow fullforwardshadows alpha
		#pragma target 3.0

		#include "UnityStandardBRDF.cginc"

		struct Input
		{
			float2 uv_MainTex;
			float3 worldPos;
			float3 worldNormal;
			float3 viewDir;
			float facing : VFACE;
		};

		UNITY_DECLARE_TEX2D(_MainTex);
		UNITY_DECLARE_TEX2D(_ReflectionTex0);
		UNITY_DECLARE_TEX2D(_ReflectionTex1);
		
		UNITY_INSTANCING_BUFFER_START(Props)
		UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
		UNITY_DEFINE_INSTANCED_PROP(half, _Glossiness)
		UNITY_DEFINE_INSTANCED_PROP(half, _Metallic)
		UNITY_DEFINE_INSTANCED_PROP(half, _BackReflectivity)
		UNITY_INSTANCING_BUFFER_END(Props)

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			fixed4 c = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv_MainTex) * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
			float4 oPos = mul(unity_WorldToObject, float4(IN.worldPos, 1));
			float4 oCPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
			oPos.z *= exp(-abs(oPos.z - oCPos.z) * 10);
			float4 projUv = UNITY_PROJ_COORD(ComputeNonStereoScreenPos(UnityObjectToClipPos(oPos)));
			float2 uv = projUv.xy / projUv.w;
			float4 giSpecular= unity_StereoEyeIndex == 0 ? UNITY_SAMPLE_TEX2D(_ReflectionTex0, uv) : UNITY_SAMPLE_TEX2D(_ReflectionTex1, uv);
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			o.Metallic = UNITY_ACCESS_INSTANCED_PROP(Props, _Metallic) * (IN.facing > 0 ? 1 : UNITY_ACCESS_INSTANCED_PROP(Props, _BackReflectivity));
			o.Smoothness = UNITY_ACCESS_INSTANCED_PROP(Props, _Glossiness);

			
			half surfaceReduction;
			half perceptualRoughness = SmoothnessToPerceptualRoughness(o.Smoothness);
			half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
			#ifdef UNITY_COLORSPACE_GAMMA
				surfaceReduction = 1.0-0.28*roughness*perceptualRoughness;
			#else
				surfaceReduction = 1.0 / (roughness*roughness + 1.0);
			#endif
			half grazingTerm = saturate(o.Smoothness + 0.5);
			o.Albedo += surfaceReduction * giSpecular * FresnelLerp(1.0, grazingTerm, saturate(dot(IN.worldNormal * IN.facing, IN.viewDir)));
		}
		ENDCG
	}
	FallBack "Standard"
}
