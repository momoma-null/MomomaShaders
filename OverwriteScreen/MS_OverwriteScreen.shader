// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/OverwriteScreen/OverwriteScreen"
{
	Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		_MainTex ("Main Texture", 2D) = "white" {}
		_Size ("Size", Range(0,1.0)) = 1
		_CullDistance ("Cull Distance", Float) = -1
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Overlay+6000" "IgnoreProjector" = "True" }
		Pass
		{
			ZTest Always
			ZWrite Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;
			fixed4 _Color;
			fixed _Size;
			fixed _CullDistance;

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			v2f vert (float4 uv : TEXCOORD0)
			{
				v2f o;
				
				#if defined(UNITY_SINGLE_PASS_STEREO)
					o.pos = 0;
				#else
					float ratio = (_MainTex_TexelSize.x * _ScreenParams.x) / (_MainTex_TexelSize.y * _ScreenParams.y);
					float2 size = _Size * lerp(float2(1, ratio), float2(1.0 / ratio, 1), ratio < 1);
					o.pos = float4(2.0 * uv.x * size.x - 1.0, 1.0 -  2.0 * uv.y * size.y, 1, 1);
					o.pos *= _CullDistance < 0 || distance(mul(unity_ObjectToWorld, float4(0, 0, 0, 1)), _WorldSpaceCameraPos) < _CullDistance;
				#endif
				o.uv = TRANSFORM_TEX(uv, _MainTex);

				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				return _Color * tex2D(_MainTex, i.uv);
			}
			ENDCG
		}
	} 
}
