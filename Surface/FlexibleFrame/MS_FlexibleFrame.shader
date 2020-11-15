// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Surface/FlexibleFrame"
{
	Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		_MainTex ("Texture", 2D) = "white" {}
		[Normal] _NormalMap ("Normal", 2D) = "bump" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_Width ("Width", Float) = 1.0
		[Enum(Off, 0, On, 1)] _AutoUVScale ("Auto UV Scale", Float) = 1.0
	}
	SubShader
	{
		Tags { "DisableBatching" = "true" }
		CGPROGRAM
		#pragma surface surf Standard addshadow fullforwardshadows vertex:vert nolightmap
		
		struct Input
		{
			float2 uv_MainTex;
			float2 uv_NormalMap;
			float4 color : COLOR;
		};

		sampler2D _MainTex;
		sampler2D _NormalMap;
		fixed4 _Color;
		half _Glossiness;
		half _Metallic;
		fixed _Width;
		fixed _AutoUVScale;
		
		void vert(inout appdata_full i)
		{
			float3 scale = float3(length(unity_WorldToObject[0].xyz), length(unity_WorldToObject[1].xyz), length(unity_WorldToObject[2].xyz));
			i.vertex.xy += (1.0 - _Width * scale.xy) * (0.5 * sign(i.vertex.xy) - i.vertex.xy);
			if (_AutoUVScale)
				i.texcoord.xy = i.vertex.xy / scale.xy + i.vertex.z * i.normal.xy / scale.z;
		}

		UNITY_INSTANCING_BUFFER_START(Props)
		UNITY_INSTANCING_BUFFER_END(Props)

		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			o.Albedo = IN.color * _Color.rgb * tex2D(_MainTex, IN.uv_MainTex);
			o.Normal = UnpackNormal(tex2D(_NormalMap, IN.uv_NormalMap));
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = _Color.a;
		}
		ENDCG
	}
	FallBack "Standard"
}
