// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

// The MIT License
// Copyright © 2017 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Shader "MomomaShader/Surface/Triplanar"
{
	Properties
	{
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Culling", Float) = 0
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		[Normal][NoScaleOffset] _BumpMap ("Normal Map", 2D) = "bump" {}
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		[NoScaleOffset] _NoiseTex ("Noise Texture", 2D) = "black" {}
		_NoiseScale ("Noise Scale", Range(0.001, 0.05)) = 0.02
	}
	SubShader
	{
		Cull [_Cull]

		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows addshadow vertex:vert
		#pragma target 3.0

		struct Input
		{
			float facing : VFACE;
			float3 objPos;
			float3 objNormal;
		};

		sampler2D _MainTex;
		float4 _MainTex_ST;
		sampler2D _BumpMap;
		half _Metallic;
		half _Glossiness;
		fixed4 _Color;
		sampler2D _NoiseTex;
		fixed _NoiseScale;

		void vert(inout appdata_full i, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			o.objPos = i.vertex;
			o.objNormal = i.normal;
		}

		UNITY_INSTANCING_BUFFER_START(Props)
		UNITY_INSTANCING_BUFFER_END(Props)

		inline float sum(float3 v)
		{
			return v.x + v.y + v.z;
		}

		float4 tex2Dtile(sampler2D samp, float2 uv)
		{
			float k = tex2D(_NoiseTex, _NoiseScale * uv).x * 8.0;
			float i = floor(k);
			float f = k - i;
			float2 offa = sin(float2(3.0, 7.0) * (i + 0.0));
			float2 offb = sin(float2(3.0, 7.0) * (i + 1.0));
			float2 dx = ddx(uv), dy = ddy(uv);
			float4 cola = tex2Dgrad(samp, uv + offa, dx, dy);
			float4 colb = tex2Dgrad(samp, uv + offb, dx, dy);
			return lerp(cola, colb, smoothstep(0.2, 0.8, f - 0.1 * sum(cola-colb)));
		}

		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			float3 weight = abs(IN.objNormal);
			weight /= (weight.x + weight.y + weight.z);
			float2 uv[3] = {TRANSFORM_TEX(IN.objPos.yz, _MainTex), TRANSFORM_TEX(IN.objPos.zx, _MainTex), TRANSFORM_TEX(IN.objPos.xy, _MainTex)};
			float4 c = tex2Dtile(_MainTex, uv[0]) * weight.x + tex2Dtile(_MainTex, uv[1]) * weight.y + tex2Dtile(_MainTex, uv[2]) * weight.z;
			c *= _Color;
			o.Albedo = c.rgb;
			o.Normal = IN.facing * UnpackNormal(tex2Dtile(_BumpMap, uv[0]) * weight.x + tex2Dtile(_BumpMap, uv[1]) * weight.y + tex2Dtile(_BumpMap, uv[2]) * weight.z);
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Standard"
}
