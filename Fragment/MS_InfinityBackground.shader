// Copyright (c) 2024 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Fragment/InfinityBackground"
{
	Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		_MainTex ("Albedo (RGB)", 2D) = "white" { }
		_Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5
	}
	Subshader
	{
		Tags { "RenderType" = "TransparentCutout" "Queue" = "Geometry+501" }
		Pass
		{
			AlphaToMask On
			// Offset -1, -1
			ZClip Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing

			#include "UnityCG.cginc"

			struct v2f
			{
				UNITY_POSITION(pos);
				float2 uv : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			UNITY_DECLARE_TEX2D(_MainTex);
			float4 _MainTex_ST;

			UNITY_INSTANCING_BUFFER_START(Props)
			UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
			UNITY_DEFINE_INSTANCED_PROP(fixed, _Cutoff)
			UNITY_INSTANCING_BUFFER_END(Props)

			v2f vert(appdata_base v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_OUTPUT(v2f, o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.pos = UnityObjectToClipPos(v.vertex);
				// o.pos.z = o.pos.w * (1.0 - _ZBufferParams.y) / _ZBufferParams.x;
				o.uv = TRANSFORM_TEX(v.texcoord.xy, _MainTex);
				return o;
			}

			float4 frag(v2f IN) : SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(IN);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
				float4 color = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv) * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
				float threshold = UNITY_ACCESS_INSTANCED_PROP(Props, _Cutoff);
				color.a = saturate((color.a - threshold) / max(fwidth(color.a), 1e-3) + 0.5);
				return color;
			}
			ENDCG
		}
	}
}