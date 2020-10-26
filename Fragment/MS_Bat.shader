// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Fragment/Bat"
{
	Properties
	{
	}
	SubShader
	{
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o, o.vertex);
				return o;
			}

			inline float hash21(float2 p)
			{
				float h = dot(p, float2(127.1, 311.7));
				return frac(sin(h) * 43758.5453123);
			}

			inline float2 hash22(float2 p)
			{
				static const float2 k = float2(0.3183099, 0.3678794);
				p = p * k + k.yx;
				return frac(16.0 * k * frac(p.x * p.y * (p.x + p.y)));
			}

			inline float circle(float2 p, float r)
			{
				return length(p) - r;
			}
			
			// --------------------------------
			// main image
			
			fixed4 frag(v2f i) : SV_Target
			{
				float4 c = float4(0, 0, 0, 1);
				float sint, d;
				float2 uv, id;
				[unroll]
				for (float k = 0; k < 2.9; ++k)
				{
					uv = i.uv + float2(0.05, -0.01) * _Time.y * (1.0 + k * 1.05);
					id = floor(uv * (6.0 - k));
					uv = frac(uv * (6.0 - k)) - 0.5;
					sint = (exp(sin(_Time.y * 10 + hash21(id + 0.1))) - 1.5) / 1.2;
					uv *= 3.0 + hash21(id) * 2.0;
					uv += hash22(id) * 2.0 - 1.0;
					uv.x = abs(uv.x);
					uv.x /= 0.8 + 0.2 * sint;
					d = circle(uv * float2(1.0, 2.5), 0.5);
					d = max(d, -circle(uv * float2(1.8, 3.0) + float2(-0.8, 0.3), 0.3));
					d = max(d, -circle(uv * float2(1.8, 3.0) + float2(-0.3, 0.6), 0.3));
					d = max(d, -circle(uv * float2(1.5, 4.0) + float2(0, -0.6), 0.5));
					uv.x *= 0.8 + 0.2 * sint;
					d = min(d, circle(uv * float2(1.8, 1.8) + float2(0, 0), 0.15));
					d = min(d, circle(uv * float2(8.0, 1.5) + float2(-0.25, -0.05), 0.15));
					c.rgb = d < 0 ? 0.6 + k * 0.2 : c.rgb;
				}
				
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
