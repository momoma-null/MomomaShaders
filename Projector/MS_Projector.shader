// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Projector/Projector"
{
	Properties
	{
		_MulColor ("Multiply Color", Color) = (1,1,1,1)
		_ScrColor ("Screen Color", Color) = (0,0,0,0)
		_ShadowTex ("Texture", 2D) = "white" {}
		[Enum(Off, 0, On, 1)] _OnlyProj ("Only Projection Surface", Float) = 1
	}
	Subshader
	{
		Tags { "Queue" = "Transparent+100" }
		Pass
		{
			Cull Off
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off
			Offset -1, -1

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog

			#include "UnityCG.cginc"
			
			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 uvShadow : TEXCOORD0;
				float4 uvFalloff : TEXCOORD1;
				float3 normal : TEXCOORD2;
				UNITY_FOG_COORDS(3)
			};
			
			float4x4 unity_Projector;
			float4x4 unity_ProjectorClip;

			fixed4 _MulColor;
			fixed4 _ScrColor;
			sampler2D _ShadowTex;
			fixed _OnlyProj;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uvShadow = mul(unity_Projector, v.vertex);
				o.uvFalloff = mul(unity_ProjectorClip, v.vertex);
				o.normal = v.normal;
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 uv = UNITY_PROJ_COORD(i.uvShadow);
				fixed4 uvF = UNITY_PROJ_COORD(i.uvFalloff);
				
				clip(uvF.x * (1 - uvF.x));
				clip(uv.x * (uv.w - uv.x));
				clip(uv.y * (uv.w - uv.y));

				if (_OnlyProj)
				{
					clip((mul((float3x3)unity_Projector, i.normal).z < 0) - 1);
				}

				fixed4 c = tex2Dproj(_ShadowTex, uv);
				c = 1.0 - (1.0 - _ScrColor) * (1.0 - c * _MulColor);
				
				UNITY_APPLY_FOG(i.fogCoord, c);

				return c;
			}
			ENDCG
		}
	}
}