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
		[NoScaleOffset] _MetallicGlossMap ("Metallic Gloss Map", 2D) = "white" {}
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		[NoScaleOffset] _NoiseTex ("Noise Texture", 2D) = "black" {}
		_NoiseScale ("Noise Scale", Range(0.001, 0.05)) = 0.02
		_NoiseHeight ("Noise Height", Range(5.0, 20.0)) = 12.0
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

		struct TileInfo
		{
			float f;
			float2 offa;
			float2 offb;
			float mip;
		};

		UNITY_DECLARE_TEX2D(_MainTex);
		float4 _MainTex_ST;
		float4 _MainTex_TexelSize;
		UNITY_DECLARE_TEX2D_NOSAMPLER(_BumpMap);
		UNITY_DECLARE_TEX2D_NOSAMPLER(_MetallicGlossMap);
		half _Metallic;
		half _Glossiness;
		fixed4 _Color;
		UNITY_DECLARE_TEX2D(_NoiseTex);
		fixed _NoiseScale, _NoiseHeight;

		void vert(inout appdata_full i, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			o.objPos = i.vertex;
			o.objNormal = i.normal;
		}

		UNITY_INSTANCING_BUFFER_START(Props)
		UNITY_INSTANCING_BUFFER_END(Props)

		#define SAMPLE_TEX2DTILE_WIEGHT(tex, col) \
		TileInfo t0##tex = GetTileInfo(uv[0]);\
		TileInfo t1##tex = GetTileInfo(uv[1]);\
		TileInfo t2##tex = GetTileInfo(uv[2]);\
		SAMPLE_TEX2DTILE_SAMPLER_WIEGHT(tex, tex, col)

		#define SAMPLE_TEX2DTILE_SAMPLER_WIEGHT(tex, samplertex, col) \
		SAMPLE_TEX2DTILE_SAMPLER(tex, samplertex, uv[0], c0##col, t0##samplertex)\
		SAMPLE_TEX2DTILE_SAMPLER(tex, samplertex, uv[1], c1##col, t1##samplertex)\
		SAMPLE_TEX2DTILE_SAMPLER(tex, samplertex, uv[2], c2##col, t2##samplertex)\
		float4 col = c0##col * w.x + c1##col * w.y + c2##col * w.z;

		#define SAMPLE_TEX2DTILE_SAMPLER(tex, samplertex, coord, col, tileInfo) \
		float4 a##col = UNITY_SAMPLE_TEX2D_SAMPLER_LOD(tex, samplertex, coord + tileInfo.offa, tileInfo.mip);\
		float4 b##col = UNITY_SAMPLE_TEX2D_SAMPLER_LOD(tex, samplertex, coord + tileInfo.offb, tileInfo.mip);\
		float4 col = lerp(a##col, b##col, smoothstep(0.2, 0.8, tileInfo.f - 0.1 * sum(a##col - b##col)));

		inline float sum(float3 v)
		{
			return v.x + v.y + v.z;
		}

		inline float ComputeTextureLOD(float2 uvdx, float2 uvdy, float2 texelSize)
		{
			float2 ddx_ = texelSize * uvdx;
			float2 ddy_ = texelSize * uvdy;
			float  d = max(dot(ddx_, ddx_), dot(ddy_, ddy_));
			return max(0.5 * log2(d), 0.0);
		}

		inline TileInfo GetTileInfo(float2 uv)
		{
			TileInfo o;
			float k= UNITY_SAMPLE_TEX2D_LOD(_NoiseTex, _NoiseScale * uv, 0).x * _NoiseHeight;
			float i = floor(k);
			o.f = k - i;
			o.offa = sin(float2(3.0, 7.0) * (i + 0.0));
			o.offb = sin(float2(3.0, 7.0) * (i + 1.0));
			o.mip = ComputeTextureLOD(ddx(uv), ddy(uv), _MainTex_TexelSize.zw);
			return o;
		}

		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			float3 w = abs(IN.objNormal);
			w /= (w.x + w.y + w.z);
			float2 uv[3] = {TRANSFORM_TEX(IN.objPos.yz, _MainTex), TRANSFORM_TEX(IN.objPos.zx, _MainTex), TRANSFORM_TEX(IN.objPos.xy, _MainTex)};
			SAMPLE_TEX2DTILE_WIEGHT(_MainTex, c)
			c *= _Color;
			o.Albedo = c.rgb;
			SAMPLE_TEX2DTILE_SAMPLER_WIEGHT(_BumpMap, _MainTex, bump)
			o.Normal = IN.facing * UnpackNormal(bump);
			SAMPLE_TEX2DTILE_SAMPLER_WIEGHT(_MetallicGlossMap, _MainTex, mg)
			o.Metallic = _Metallic * mg.r;
			o.Smoothness = _Glossiness * mg.a;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Standard"
}
