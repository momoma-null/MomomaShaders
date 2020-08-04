// Copyright (c) 2020 momoma
// Released under the MIT license
// https://opensource.org/licenses/mit-license.php

Shader "MomomaShader/Fragment/FakeSkybox"
{
    Properties
    {
        _Tint ("Tint Color", Color) = (.5, .5, .5, .5)
        _Exposure ("Exposure", Range(0, 8)) = 1.0
        [NoScaleOffset] _Tex ("Cubemap", Cube) = "grey" {}
        _Rotation ("Rotation", Range(0, 360)) = 0
        [Enum(Off, 0, On, 1)] _Mirror ("Mirror", Float) = 0
        [Enum(Off, 0, On, 1)] _ZWrite ("ZWrite", Float) = 1
    }

    SubShader
    {
        Tags { "DisableBatching" = "True" }
        Cull Off
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"

            samplerCUBE _Tex;
            float4 _Tex_HDR;
            fixed4 _Tint;
            fixed _Exposure;
            fixed _Rotation;
            fixed _Mirror;
            fixed _ZWrite;

            float3 RotateAroundYInDegrees (float3 vertex, float degrees)
            {
                float t = degrees * UNITY_PI / 180.0;
                float s, c;
                sincos(t, s, c);
                return float3(mul(float2x2(c, -s, s, c), vertex.xz), vertex.y).xzy;
            }

            struct appdata
            {
                float4 vertex : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 viewDir : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.viewDir = RotateAroundYInDegrees(mul(unity_ObjectToWorld, v.vertex) - _WorldSpaceCameraPos, _Rotation);
                if (_Mirror) o.viewDir.z *= -1;
                if (!_ZWrite) o.vertex.z *= 0.01;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 c = DecodeHDR(texCUBE(_Tex, i.viewDir), _Tex_HDR);
                c *= _Tint.rgb * unity_ColorSpaceDouble.rgb * _Exposure;
                return float4(c, 1);
            }
            ENDCG
        }
    }
}
