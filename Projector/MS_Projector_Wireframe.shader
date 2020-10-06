// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Projector/Wireframe"
{
	Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		[PowerSlider(2.0)] _Width ("Width", Range(0.001, 0.2)) = 0.01
	}
	Subshader
	{
		Tags { "Queue" = "Transparent+100" }
		Pass
		{
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			Offset -1,-1

			CGPROGRAM
			#pragma target 5.0
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct g2f
			{
				float4 pos : SV_POSITION;
				float4 uvShadow : TEXCOORD0;
				float4 uvFalloff : TEXCOORD1;
				float3 weight : TEXCOORD2;
			};

			float4x4 unity_Projector;
			float4x4 unity_ProjectorClip;

			fixed4 _Color;
			fixed _Width;

			float4 vert(float4 pos : POSITION) : TEXCOORD0
			{
				return pos;
			}

			[maxvertexcount(3)]
			void geom(triangle float4 input[3] : TEXCOORD0, inout TriangleStream<g2f> outStream)
			{
				g2f o;

				float3 p0 = UnityObjectToViewPos(input[0]);
				float3 p1 = UnityObjectToViewPos(input[1]);
				float3 p2 = UnityObjectToViewPos(input[2]);

				float3 edge[3];
				edge[0] = p2 - p1;
				edge[1] = p0 - p2;
				edge[2] = p1 - p0;

				float3 len = float3(length(edge[0]), length(edge[1]), length(edge[2]));
				float s = (len.x + len.y + len.z) * 0.5;
				float r = sqrt((s - len.x) * (s - len.y) * (s - len.z) / s);
				float area = length(cross(edge[1], edge[2]));

				[unroll]
				for(uint i = 0; i < 3; i++)
				{
					o.pos = UnityObjectToClipPos(input[i]);
					o.uvShadow = mul(unity_Projector, input[i]);
					o.uvFalloff = mul(unity_ProjectorClip, input[i]);

					o.weight = 0;
					o.weight[i] = 1.0 - r / (area / len[i]);

					outStream.Append(o);
				}
				outStream.RestartStrip();
			}

			fixed4 frag(g2f i) : SV_Target
			{
				fixed4 uv = UNITY_PROJ_COORD(i.uvShadow);
				fixed4 uvF = UNITY_PROJ_COORD(i.uvFalloff);

				clip(uvF.x * (1.0 - uvF.x));
				clip(uv.x * (uv.w - uv.x));
				clip(uv.y * (uv.w - uv.y));

				float4 c = _Color;
				c.a = smoothstep(_Width, 0, min(min(i.weight.x, i.weight.y), i.weight.z));
				return c;
			}
			ENDCG
		}
	}
}