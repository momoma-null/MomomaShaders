// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Surface/ScreenSpaceReflection"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		[Normal] _BumpMap ("NormalMap", 2D) = "bump" {}
	}
	SubShader
	{
		Tags { "Queue" = "AlphaTest+10" }

		GrabPass
		{
			"_BackgroundTexture"
		}
		
		CGPROGRAM
		#pragma surface surf Standard addshadow fullforwardshadows
		#pragma target 3.0

		struct Input
		{
			float2 uv_MainTex;
			float2 uv_BumpMap;
			float3 worldPos;
			float3 worldRefl;
			INTERNAL_DATA
		};

		sampler2D_float _CameraDepthTexture;
		sampler2D _BackgroundTexture;

		sampler2D _MainTex;
		sampler2D _BumpMap;
		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		UNITY_INSTANCING_BUFFER_START(Props)
		UNITY_INSTANCING_BUFFER_END(Props)

		float compute_depth(float4 pos)
		{
			#if UNITY_UV_STARTS_AT_TOP
				return pos.z / pos.w;
			#else
				return (pos.z / pos.w) * 0.5 + 0.5;   
			#endif
		}
		
		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
			
			const static int loopNum = 10;
			float step = 0.5 * length(IN.worldPos - _WorldSpaceCameraPos);
			float step2 = step * -0.5;
			float rayDepth, depth, alpha;
			float3 ray, rayPos;
			float4 rayScreenPos, screenUV;
			float3 worldRefl = WorldReflectionVector(IN, o.Normal);
			[unroll]
			for (int k = 1; k <= loopNum; k++)
			{
				ray = k * step * worldRefl;
				rayPos = IN.worldPos + ray;
				rayScreenPos = mul(UNITY_MATRIX_VP, float4(rayPos, 1));
				screenUV = UNITY_PROJ_COORD(ComputeGrabScreenPos(rayScreenPos));
				if (any(abs(screenUV.xy / screenUV.w - 0.5) > 0.5)) break;
				rayDepth = LinearEyeDepth(compute_depth(rayScreenPos));
				depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, screenUV));
				if (rayDepth > depth && rayDepth - depth < step * 2.0)
				{
					[unroll]
					for (int l = 0; l < 8; l++)
					{
						ray += step2 * worldRefl;
						rayPos = IN.worldPos + ray;
						rayScreenPos = mul(UNITY_MATRIX_VP, float4(rayPos, 1));
						screenUV = UNITY_PROJ_COORD(ComputeGrabScreenPos(rayScreenPos));
						rayDepth = LinearEyeDepth(compute_depth(rayScreenPos));
						depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, screenUV));
						step2 = abs(step2) * (rayDepth > depth ? -0.5 : 0.5);
					}
					alpha = 1.0 - saturate(pow(2.0 * length(screenUV.xy / screenUV.w - 0.5), 4.0));
					alpha *= 1.0 - saturate(pow(ray / (step * loopNum), 2.0));
					c.rgb = lerp(c.rgb, tex2Dproj(_BackgroundTexture, screenUV), _Glossiness * alpha);
					break;
				}
			}
			
			o.Albedo = c.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
