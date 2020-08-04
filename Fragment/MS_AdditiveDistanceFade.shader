// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Fragment/AdditiveDistanceFade"
{
	Properties
	{
		_Color ("Main Color", Color) = (1, 1, 1, 1)
		_MainTex ("Base", 2D) = "white" {}
		[NoScaleOffset] _OcclusionMap ("Occlusion Map", 2D) = "white" {}
		[NoScaleOffset] _EmissionMap ("Emission Map", 2D) = "black" {}
		_EmissionIntencity ("Emission Intencity", Range(0.0, 5.0)) = 1.0
		_FadeEnd ("Fade End Distance", Float) = 1.0
		_FadeStart ("Fade Start Distance", Float) = 3.0
		_BlinkSpeed ("Blink Speed", Float) = 3.0
		[Enum(Off, 0, On, 1)] _PeriodicFlash ("Periodic Flash", float) = 0
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "IgnoreProjector" = "True" }
		Pass
		{
			Cull Off
			Blend One One
			ZWrite Off
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _OcclusionMap;
			sampler2D _EmissionMap;
			fixed4 _Color;
			fixed _EmissionIntencity;
			fixed _FadeEnd;
			fixed _FadeStart;
			fixed _BlinkSpeed;
			bool _PeriodicFlash;
			
			struct appdata
			{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
			};
			
			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float fade : TEXCOORD1;
			};
			
			float hash(float2 p)
			{
				uint n = asuint(p.x * 122.0 + p.y);
				n = (n << 13u) ^ n;
				n = n * (n * n * 15731u + 789221u) + 1376312589u;
				return asfloat((n>>9u) | asuint(1.0f)) - 1.0;
			}

			float noise(float p)
			{
				float2 i = floor(p);
				float f = frac(p);
				float u = f * f * (3.0 - 2.0 * f);
    
				float a = hash(i + float2(0.0, 0.0));
				float b = hash(i + float2(1.0, 0.0));
				float c = hash(i + float2(0.0, 1.0));
				float d = hash(i + float2(1.0, 1.0));
				
				return abs(lerp(lerp(a, b, u), lerp(c, d, u), u));
			}

			v2f vert (appdata v)
			{
				v2f o;

				#if defined(USING_STEREO_MATRICES)
					float3 cameraPos = (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]) * 0.5;
				#else
					float3 cameraPos = _WorldSpaceCameraPos;
				#endif

				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.fade = smoothstep(_FadeEnd, _FadeStart, distance(cameraPos, worldPos));
				if(_PeriodicFlash)
					o.fade *= (cos(_Time.y * _BlinkSpeed) + 1.0) * 0.5;
				else
					o.fade *= noise(_Time.y * _BlinkSpeed);
				
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 c = _Color * tex2D(_MainTex, i.uv) * tex2D(_OcclusionMap, i.uv);
				c += tex2D(_EmissionMap, i.uv) * _EmissionIntencity;
				c.rgb *= i.fade;
				return c;
			}
			ENDCG			
		}
	}
}
