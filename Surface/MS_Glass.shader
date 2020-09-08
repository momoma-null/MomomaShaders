// Copyright (c) 2019 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Surface/Glass"
{
	Properties
	{
		[Enum(Front, 1, Back, 2)] _Cull ("Cull", Float) = 1
		_Color ("Color", Color) = (1,1,1,0.25)
		_MainTex ("Albedo", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 1.0
		_Metallic ("Metallic", Range(0,1)) = 1.0
		[Normal] _BumpMap ("NormalMap", 2D) = "bump" {}
		_EmissionMap ("Emission", 2D) = "black" {}
		_RefractiveIndex ("Refractive Index", Range(0.01, 1.0)) = 0.9
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent+10" }

		Cull [_Cull]
		ZWrite Off

		GrabPass
		{
			"_BackgroundTexture"
		}

		CGPROGRAM
		#pragma surface surf Standard addshadow fullforwardshadows finalcolor:final
		#pragma target 3.0

		struct Input
		{
			float2 uv_MainTex;
			float2 uv_BumpMap;
			float2 uv_EmissionMap;
			float3 worldPos;
			float3 viewDir;
			float4 screenPos;
			float3 worldNormal;
			INTERNAL_DATA
		};

		sampler2D _BackgroundTexture;

		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _EmissionMap;
		fixed4 _Color;
		half _Glossiness;
		half _Metallic;
		fixed _RefractiveIndex;
		fixed _Cull;

		UNITY_INSTANCING_BUFFER_START(Props)
		UNITY_INSTANCING_BUFFER_END(Props)

		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap)) * 2.0 * (_Cull - 1.5);
			o.Emission = tex2D(_EmissionMap, IN.uv_EmissionMap);
		}

		void final(Input IN, SurfaceOutputStandard o, inout fixed4 c)
		{
			float3 refractPos = IN.worldPos + refract(normalize(IN.worldPos - _WorldSpaceCameraPos), o.Normal, _RefractiveIndex) * 1.0;
			float4 refractScreenPos = ComputeGrabScreenPos(UnityWorldToClipPos(refractPos));
			float2 grabUV = refractScreenPos.xy / refractScreenPos.w;
			float2 rowUV = IN.screenPos.xy / IN.screenPos.w;
			grabUV = lerp(grabUV, rowUV, smoothstep(0.0, 0.5, abs(grabUV - 0.5)));
			c = lerp(c, tex2D(_BackgroundTexture, grabUV), 1.0 - o.Alpha);
		}

		ENDCG
	}
	FallBack "Transparent/Diffuse"
}
