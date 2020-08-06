// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Fragment/Unlit"
{
	Properties
	{
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Culling", Float) = 0
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color", Color) = (1, 1, 1, 1)
		_UScroll ("U Scroll", Float) = 0
		_VScroll ("V Scroll", Float) = 0
		_EmissionMap ("Emission Map", 2D) = "white" {}
		_EmissionColor ("Emission Color", Color) = (0, 0, 0, 0)
		_EmissionUScroll ("Emission U Scroll", Float) = 0
		_EmissionVScroll ("Emission V Scroll", Float) = 0
		_Rimpower ("Rim Power", Range(0.0, 20.0)) = 5.0
		_RimColor ("Rim Color", Color) = (0, 0, 0, 0)
	}
	SubShader
	{
		Pass
		{
			Cull [_Cull]

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float2 uv_Emission : TEXCOORD1;
				float3 normal : TEXCOORD2;
				float3 worldPos : TEXCOORD3;
				UNITY_FOG_COORDS(4)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			fixed _UScroll;
			fixed _VScroll;
			sampler2D _EmissionMap;
			float4 _EmissionMap_ST;
			fixed4 _EmissionColor;
			fixed _EmissionUScroll;
			fixed _EmissionVScroll;
			fixed _Rimpower;
			fixed4 _RimColor;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex) + float2(_UScroll, _VScroll) * _Time.y;
				o.uv_Emission = TRANSFORM_TEX(v.uv, _EmissionMap) + float2(_EmissionUScroll, _EmissionVScroll) * _Time.y;
				o.normal = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				UNITY_TRANSFER_FOG(o, o.pos);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float3 dir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				float3 normal = normalize(i.normal);
				float rim = 1.0 - saturate(dot(dir, normal));
				fixed4 c = _Color * tex2D(_MainTex, i.uv);
				c += _EmissionColor * tex2D(_EmissionMap, i.uv_Emission);
				c += _RimColor * pow(rim, _Rimpower);
				c.a = 1;
				UNITY_APPLY_FOG(i.fogCoord, c);
				return c;
			}
			ENDCG
		}
		
		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
			
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile_shadowcaster
			
			#include "UnityCG.cginc"

			struct v2f
			{
				V2F_SHADOW_CASTER;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert( appdata_base v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				return o;
			}

			float4 frag( v2f i ) : SV_Target
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
}
