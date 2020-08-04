// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Fragment/Fire"
{
	Properties
	{
		_Color ("Color", Color) = (0.8, 0.5, 0.1, 1.0)
		_MirrorColor ("Color in Mirror", Color) = (0.8, 0.5, 0.1, 1.0)
		_Offset ("Offset", Vector) = (1, 1, 0, 0)
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

			fixed4 _Color, _MirrorColor, _Offset;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv * _Offset.xy + _Offset.zw;
				UNITY_TRANSFER_FOG(o, o.vertex);
				return o;
			}
			
			bool inMirror()
			{
				return dot(cross(UNITY_MATRIX_V[0], UNITY_MATRIX_V[1]), UNITY_MATRIX_V[2]) > 0;
			}

			float2 hash22(float2 p)
			{
				static const float2 k = float2(0.3183099, 0.3678794);
				p = p * k + k.yx;
				return frac(16.0 * k * frac(p.x * p.y * (p.x + p.y))) * 2.0 - 1.0;
			}

			float simplexNoise2D(float2 p)
			{
				const float K1 = 0.366025404;//(sqrt(3)-1)/2;
				const float K2 = 0.211324865;//(3-sqrt(3))/6;
	
				float2 i = floor(p + (p.x + p.y) * K1);
				float2 a = p - i + (i.x + i.y) * K2;
				float2 o = (a.x > a.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
				float2 b = a - o + K2;
				float2 c = a - 1.0 + 2.0 * K2;
				float3 h = max(0.5 - float3(dot(a, a), dot(b, b), dot(c, c) ), 0.0);	
				float3 n = h * h * h * h * float3(dot(a, hash22(i)), dot(b, hash22(i + o)), dot(c, hash22(i + 1.0)));
	
				return (n.x + n.y + n.z) * 35.0 + 0.5;
			}

			float fbm(float2 p)
			{
				float2x2 mat = float2x2(1.6, 1.2, -1.2, 1.6);
				float t = 0;
				t += simplexNoise2D(p) * 0.5;
				p = mul(mat, p);
				t += simplexNoise2D(p) * 0.25;
				p = mul(mat, p);
				t += simplexNoise2D(p) * 0.125;
				p = mul(mat, p);
				t += simplexNoise2D(p) * 0.0625;
				return t / 0.9375;
			}
			
			// --------------------------------
			// main image
			
			fixed4 frag (v2f i) : SV_Target
			{
				float4 c = inMirror() ? _MirrorColor : _Color;
				float2 uv = float2(abs(0.5 - i.uv.x), i.uv.y);
				float f = fbm(uv * 10.0 + float2(0.0, -fmod(5.0 * _Time.y, 100.0)));
				c.rgb *= f + f * f * c.rgb + f * f * f * c.rgb * c.rgb;
				c.rgb *= pow(1.0 - uv.y, 2.0);
				
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
