Shader "shader/ch10_posteffect"
{
    Properties
    {
        _Color("Color", Color) = (1, 0, 0, 1)
        _MainTex("Texture", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            Name "Invert"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            float4 _MainTex_ST;
            float4 _CameraDepthTexture_ST;
            

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                //Varyings OUT;
                Varyings OUT = (Varyings)0;;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                col = 1 - col;
                return col;
            }
            ENDHLSL
        }

        Pass
        {
            Name "Depth"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            float4 _MainTex_ST;
            float4 _CameraDepthTexture_ST;

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                //Varyings OUT;
                Varyings OUT = (Varyings)0;;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // texture
                half depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, IN.uv);
                return float4(depth, depth, depth, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "LinearToGamma"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            float4 _MainTex_ST;
            float4 _CameraDepthTexture_ST;


            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                //Varyings OUT;
                Varyings OUT = (Varyings)0;;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 col = pow(saturate(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv)), 2.2);
                col = 1 - col;
                return pow(saturate(col), 1/2.2);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ToneMapping"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            float4 _MainTex_ST;
            float4 _CameraDepthTexture_ST;
            float _ToneMapperExposure;

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                //Varyings OUT;
                Varyings OUT = (Varyings)0;;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half3 HableOperator(half3 col)
            {
                half A = 0.15;
                half B = 0.50;
                half C = 0.10;
                half D = 0.20;
                half E = 0.02;
                half F = 0.30;
                return ((col * (col * A + B * C) + D * E) / (col * (col * A + B) + D * F)) - E / F;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                half3 toneMapped = col.rgb * _ToneMapperExposure * 4;
                toneMapped = HableOperator(toneMapped) / HableOperator(11.2);
                return half4(toneMapped, 1);
            }
            ENDHLSL
        }
    }
}
