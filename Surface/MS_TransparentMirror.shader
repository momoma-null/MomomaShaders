// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Surface/TransparentMirror"
{
	Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Metallic ("Metallic", Range(0,1)) = 1.0
		_Glossiness ("Smoothness", Range(0,1)) = 0.75
		[HideInInspector] _ReflectionTex0("", 2D) = "white" {}
		[HideInInspector] _ReflectionTex1("", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
		CGPROGRAM
		#pragma surface surf Standard addshadow fullforwardshadows alpha
		#pragma target 3.0

		struct Input
		{
			float2 uv_MainTex;
			float3 worldPos;
		};

		fixed4 _Color;
		sampler2D _MainTex;
		half _Glossiness;
		half _Metallic;
		sampler2D _ReflectionTex0;
		sampler2D _ReflectionTex1;
		
		UNITY_INSTANCING_BUFFER_START(Props)
		UNITY_INSTANCING_BUFFER_END(Props)

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			float4 uv = UNITY_PROJ_COORD(ComputeNonStereoScreenPos(UnityWorldToClipPos(IN.worldPos)));
			c *= unity_StereoEyeIndex == 0 ? tex2Dproj(_ReflectionTex0, uv) : tex2Dproj(_ReflectionTex1, uv);
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
		}
		ENDCG
	}
	FallBack "Standard"
}
