﻿// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Surface/TransparecyLM"
{
	Properties
	{
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Culling", Float) = 0
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		[Normal][NoScaleOffset] _BumpMap ("Normal Map", 2D) = "bump" {}
		_Metallic ("Metallic", Range(0,1)) = 0.0
		[NoScaleOffset] _MetalicMap ("Metalic Map", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		[NoScaleOffset] _GlossMap ("Smoothness Map", 2D) = "white" {}
		[Space(30)]
		_TransparencyLM ("Transmission", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }

		Cull [_Cull]
		ZWrite Off

		CGPROGRAM
		#pragma surface surf Standard addshadow fullforwardshadows alpha:fade
		#pragma target 3.0

		struct Input
		{
			float2 uv_MainTex;
			float facing : VFACE;
		};

		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _MetalicMap;
		sampler2D _GlossMap;
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
			o.Alpha = c.a;
			o.Normal = IN.facing * UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
			o.Metallic = tex2D (_MetalicMap, IN.uv_MainTex) * _Metallic;
			o.Smoothness = tex2D (_GlossMap, IN.uv_MainTex) * _Glossiness;
		}
		ENDCG
	}
	FallBack "Standard"
}
