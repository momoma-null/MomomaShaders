// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Projector/UV"
{
	Subshader
	{
		Tags { "Queue" = "Transparent+100" }
		Pass
		{
			Cull Off
			Offset -1, -1

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog

			#include "UnityCG.cginc"
			
			struct appdata
			{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
			};
			
			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 uvShadow : TEXCOORD0;
				float4 uvFalloff : TEXCOORD1;
				float2 uv : TEXCOORD2;
				UNITY_FOG_COORDS(3)
			};
			
			float4x4 unity_Projector;
			float4x4 unity_ProjectorClip;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uvShadow = mul(unity_Projector, v.vertex);
				o.uvFalloff = mul(unity_ProjectorClip, v.vertex);
				o.uv = v.texcoord;
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

			float3 hsv2rgb (float3 c)
			{
				return c.z * lerp(1.0 - c.y, 1.0, saturate(abs(frac(c.x + float3(0.0, 2.0 / 3.0, 1.0 / 3.0)) - 0.5) * 6.0 - 1.0));
			}

			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 uv = UNITY_PROJ_COORD(i.uvShadow);
				fixed4 uvF = UNITY_PROJ_COORD(i.uvFalloff);
				
				clip(uvF.x * (1.0 - uvF.x));
				clip(uv.x * (uv.w - uv.x));
				clip(uv.y * (uv.w - uv.y));

				float4 c;
				c.rg = floor(i.uv * 16.0) / 16.0;
				c.g = c.g * 0.5 + 0.5;
				c.b = (frac(i.uv.x * 16.0) < 0.5) == (frac(i.uv.y * 16.0) < 0.5);
				c = float4(hsv2rgb(c.rgb), 1.0);
				
				UNITY_APPLY_FOG(i.fogCoord, c);

				return c;
			}
			ENDCG
		}
	}
}