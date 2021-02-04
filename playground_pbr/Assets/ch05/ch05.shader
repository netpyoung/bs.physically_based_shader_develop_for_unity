Shader "shader/ch05"
{
    Properties
    {
        _Color("Color", Color) = (1, 0, 0, 1)
        _DiffuseTex("Texture", 2D) = "white" {}
        _Ambient("Ambient", Range(0, 1)) = 0.25
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_DiffuseTex);
            SAMPLER(sampler_DiffuseTex);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                float4 _DiffuseTex_ST;
            CBUFFER_END

            float _Ambient;

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                //Varyings OUT;
                Varyings OUT = (Varyings)0;;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normalWS = TransformObjectToWorld(IN.normalOS);
                OUT.uv = TRANSFORM_TEX(IN.uv, _DiffuseTex);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 normalWS = normalize(IN.normalWS);

                float4 tex = SAMPLE_TEXTURE2D(_DiffuseTex, sampler_DiffuseTex, IN.uv);

                // ===== Light struct =====
                // Light light = GetMainLight();
                // float NdotL = max(0.0, dot(normalWS, light.direction));
                // float4 diffuseTerm = NdotL * _Color * float4(light.color, 1);

                float NdotL = max(_Ambient, dot(normalWS, _MainLightPosition.xyz));
                float4 diffuseTerm = NdotL * _Color * tex * _MainLightColor;
                return diffuseTerm;
            }
            ENDHLSL
        }
    }
}
