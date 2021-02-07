Shader "shader/ch07"
{
    Properties
    {
        _Color("Color", Color) = (1, 0, 0, 1)
        _DiffuseTex("Texture", 2D) = "white" {}
        _NormalMap("Normal Map", 2D) = "bump" {}
        _Ambient("Ambient", Range(0, 1)) = 0.25
        _SpecColor("Specular Material Color", Color) = (1, 1, 1, 1)
        _Shininess("Shininess", Float) = 10
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "LightMode" = "UniversalForward" }
        Pass
        {
            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_DiffuseTex);
            SAMPLER(sampler_DiffuseTex);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                float4 _DiffuseTex_ST;
                float4 _NormalMap_ST;
                half4 _SpecColor;
                half _Shininess;
                float _Ambient;
            CBUFFER_END

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
                float3 positionWS   : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float4 normalTexCoord : TEXCOORD4;
            };

            Varyings vert(Attributes IN)
            {
                //Varyings OUT;
                Varyings OUT = (Varyings)0;;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS = TransformObjectToWorld(IN.normalOS);
                OUT.uv = TRANSFORM_TEX(IN.uv, _DiffuseTex);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 N = normalize(IN.normalWS);
                float3 V = normalize(TransformWorldToView(IN.normalWS));
                Light light = GetMainLight();
                float3 L = light.direction;

                // float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv));

                // texture
                float4 tex = SAMPLE_TEXTURE2D(_DiffuseTex, sampler_DiffuseTex, IN.uv);

                // diffuse
                float NdotL = max(_Ambient, dot(N, L));
                float4 diffuseTerm = NdotL * _Color * tex * float4(light.color, 1);

                // specular
                float3 R = reflect(-L, N);
                float3 VdotR = max(0.0, dot(V, R));
                float3 specular = pow(VdotR, _Shininess);
                float4 specularTerm = float4(specular, 1) * _SpecColor * float4(light.color, 1);

                float4 finalColor = diffuseTerm + specularTerm;
                return finalColor;
            }
            ENDHLSL
        }
    }
}
