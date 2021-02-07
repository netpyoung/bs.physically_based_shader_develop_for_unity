Shader "shader/ch09"
{
    Properties
    {
        _Color("Color", Color) = (1, 0, 0, 1)
        _DiffuseTex("Texture", 2D) = "white" {}
        _Ambient("Ambient", Range(0, 1)) = 0.25
        _SpecColor("Specular Material Color", Color) = (1, 1, 1, 1)
        _Shininess("Shininess", Float) = 10

        [Toggle] _ModifiedMode("Modified?", Float) = 0
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

            // There is a maximum of 64 unique local keywords per shader.
            // #pragma shader_feature __ _MODIFIEDMODE_ON

            #pragma shader_feature _MODIFIEDMODE_OFF _MODIFIEDMODE_ON
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_DiffuseTex);
            SAMPLER(sampler_DiffuseTex);

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                float4 _DiffuseTex_ST;
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
                float3 normalOS     : TEXCOORD2;
                float4 normalTexCoord : TEXCOORD4;
            };

            Varyings vert(Attributes IN)
            {
                //Varyings OUT;
                Varyings OUT = (Varyings)0;;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalOS = IN.normalOS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _DiffuseTex);
                return OUT;
            }

            half3 LightingPhong(half3 lightColor, half3 lightDir, half3 normal, half3 viewDir, half4 specularColor, half3 albedo, half shininess)
            {
                half NdotL = saturate(dot(normal, lightDir));
                half3 diffuseTerm = NdotL * albedo * lightColor;

                half3 reflectionDirection = reflect(-lightDir, normal);
                half3 specularDot = max(0.0, dot(viewDir, reflectionDirection));
                half3 specular = pow(specularDot, shininess);
                half3 specularTerm = specularColor.rgb * specular * lightColor;

                return diffuseTerm + specularTerm;
            }

            half3 LightingPhongModified(half3 lightColor, half3 lightDir, half3 normal, half3 viewDir, half4 specularColor, half3 albedo, half shininess)
            {
                half NdotL = saturate(dot(normal, lightDir));
                half3 diffuseTerm = NdotL * albedo * lightColor;

                half norm = (shininess + 2) / (2 * PI);

                half3 reflectionDirection = reflect(-lightDir, normal);
                half3 specularDot = max(0.0, dot(viewDir, reflectionDirection));

                half3 specular = norm * pow(specularDot, shininess);

                half3 specularTerm = specularColor.rgb * specular * lightColor;

                return diffuseTerm + specularTerm;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 N = normalize(IN.normalOS);
                float3 V = normalize(TransformWorldToView(IN.normalOS));
                
                // texture
                float4 tex = SAMPLE_TEXTURE2D(_DiffuseTex, sampler_DiffuseTex, IN.uv);

                Light light = GetMainLight();

#if _MODIFIEDMODE_ON
                float3 finalColor = LightingPhongModified(light.color, light.direction, N, V, _SpecColor, (_Color * tex).rgb, _Shininess); 
#else
                float3 finalColor = LightingPhong(light.color, light.direction, N, V, _SpecColor, (_Color * tex).rgb, _Shininess);
#endif                
                return half4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}
