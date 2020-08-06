// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/OverwriteScreen/ScreenTexture"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "black" {}
		_Alpha ("Alpha", Range(0, 1)) = 1.0
		_ClipTex ("Clip Texture", 2D) = "black" {}
		_Clip ("Clip", Range(0, 1)) = 0.5
		_Scale ("Main Scale", Range(0, 1)) = 1.0
		_BackgroundColor ("Background Color", Color) = (0, 0, 0, 1)
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Overlay+6000" "IgnoreProjector" = "True" "DisableBatching" = "True" }
		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha
			ZTest Always
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};
			
			sampler2D _MainTex;
			fixed _Alpha;
			sampler2D _ClipTex;
			fixed _Clip;
			fixed _Scale;
			fixed4 _BackgroundColor;
			
			v2f vert (float2 uv : TEXCOORD0)
			{
				v2f o;
				
				#if defined(USING_STEREO_MATRICES)
					float3 cameraPos = (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]) * 0.5;
					float3 forward = (mul((float3x3)unity_StereoMatrixInvV[0], float3(0, 0, 1)) + mul((float3x3)unity_StereoMatrixInvV[1], float3(0, 0, 1))) * 0.5;
					float2 scale = max(1.0 / float2(unity_StereoMatrixP[0]._m00, -unity_StereoMatrixP[0]._m11), 1.0 / float2(unity_StereoMatrixP[1]._m00, -unity_StereoMatrixP[1]._m11));
				#else
					float3 cameraPos = _WorldSpaceCameraPos;
					float3 forward = mul((float3x3)UNITY_MATRIX_I_V, float3(0, 0, 1));
					float2 scale = 1.0 / float2(UNITY_MATRIX_P._m00, -UNITY_MATRIX_P._m11);
				#endif

				scale = max(scale.x, scale.y) * 1.5;

				float3x3 matrixBillboard = 0;
				matrixBillboard._m02 = forward.x;
				matrixBillboard._m12 = forward.y;
				matrixBillboard._m22 = forward.z;
				float3 xAxis = normalize(float3(-forward.z, 0, forward.x));
				matrixBillboard._m00 = xAxis.x;
				matrixBillboard._m10 = 0;
				matrixBillboard._m20 = xAxis.z;
				float3 yAxis = normalize(cross(xAxis, forward));
				matrixBillboard._m01 = yAxis.x;
				matrixBillboard._m11 = yAxis.y;
				matrixBillboard._m21 = yAxis.z;

				forward *= -5.0;

				o.pos = float4((uv - 0.5) * 10.0 * scale, 0.0, 1.0);
				o.pos = UnityWorldToClipPos(mul(matrixBillboard, o.pos.xyz) + cameraPos + forward);
				o.pos.z = o.pos.w;

				o.uv = (uv - 0.5) * scale;

				return o;
			}

			fixed4 frag (v2f i) : SV_TARGET
			{
				float2 uv = i.uv / _Scale;
				bool isTex = !any(abs(uv) > 0.5);
				float4 texColor = tex2D(_MainTex, uv + 0.5);
				float4 c = _BackgroundColor;
				c.a *= lerp(1.0, 1.0 - tex2D(_ClipTex, uv + 0.5).r, _Clip * isTex);
				c.rgb = lerp(c, texColor, _Alpha * isTex * texColor.a).rgb;
				c.a = max(c.a, _Alpha * isTex * texColor.a);
				return c;
			}
			ENDCG
		}
	}
}
