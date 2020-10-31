// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Fragment/Splatter"
{
	Properties
	{
		[NoScaleOffset] _MainTex ("Texture00", 2D) = "white" {}
		[NoScaleOffset] _MainTex01 ("Texture01", 2D) = "white" {}
		_TexRatio ("Texture Ratio", Range(0.0, 1.0)) = 0.9
		_Division ("Division", Range(1.0, 100.0)) = 3.0
		_Fineness ("Fineness", Range(1.0, 100.0)) = 20.0
	}
	SubShader
	{
		Tags { "RenderType" = "TransparentCutout" "Queue" = "AlphaTest" }
		Pass
		{
			Cull Off
			AlphaToMask On

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 pos : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(3)
			};

			sampler2D _MainTex;
			sampler2D _MainTex01;
			fixed _TexRatio, _Division, _Fineness;
			
			#define LAYER 10.0

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.pos);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

		   	inline float hash(float2 p)
			{
				return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
			}

			fixed4 frag(v2f i, float facing : VFACE) : SV_Target
			{
				float2 id, uv, duv, dx, dy;
				fixed4 sampleColor, c = 0;

				[unroll]
				for(float k = 0.1; k < LAYER; ++k)
				{
					uv = (i.uv + float2(hash(k / LAYER), hash(1 - k / LAYER))) * _Fineness;
					id = floor(uv) / _Fineness;
					duv = float2(hash(id), hash(1 - id)) - 1;
					uv = frac(uv) * _Division + duv * (_Division - 1);
					dx = ddx(i.uv) * _Fineness * _Division;
					dy = ddy(i.uv) * _Fineness * _Division;
					sampleColor = lerp(tex2Dgrad(_MainTex, uv, dx, dy), tex2Dgrad(_MainTex01, uv, dx, dy), hash(duv) > _TexRatio);
					sampleColor.a *= all(0 < uv) && all(uv < 1);
					c.rgb = lerp(c.rgb, sampleColor.rgb, sampleColor.a);
					c.a = max(c.a, sampleColor.a);
				}

				UNITY_APPLY_FOG(i.fogCoord, c);
				return c;
			}
			ENDCG
		}
	}
}
