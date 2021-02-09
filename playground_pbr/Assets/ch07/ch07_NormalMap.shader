Shader "shader/ch07_NormalMap"
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
                float4 tangent      : TANGENT;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS      : SV_POSITION;
                float2 uv               : TEXCOORD0;

                float3 T                : TEXCOORD1;
                float3 B                : TEXCOORD2;
                float3 N                : TEXCOORD3;

                float3 positionWS       : TEXCOORD4;
            };
            
            // ----------
            void ExtractTBN(half3 normalOS, float4 tangent, inout half3 T, inout half3  B, inout half3 N)
            {
                half fTangentSign = tangent.w * unity_WorldTransformParams.w;
                N = TransformObjectToWorldNormal(normalOS);
                T = TransformObjectToWorldDir(tangent.xyz);
                B = cross(N, T) * fTangentSign;
            }

            half3 CombineTBN(half3 tangentNormal, half3 T, half3  B, half3 N)
            {
                float3x3 TBN = float3x3(normalize(T), normalize(B), normalize(N));
                TBN = transpose(TBN);
                return mul(TBN, tangentNormal);
            }

            Varyings vert(Attributes IN)
            {
                //Varyings OUT;
                Varyings OUT = (Varyings)0;;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _DiffuseTex);

                ExtractTBN(IN.normalOS, IN.tangent, OUT.T, OUT.B, OUT.N);

                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

#if SHADER_LIBRARY_VERSION_MAJOR < 9
            // 
            // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
            float3 GetWorldSpaceViewDir(float3 positionWS)
            {
                if (unity_OrthoParams.w == 0)
                {
                    // Perspective
                    return _WorldSpaceCameraPos - positionWS;
                }
                else
                {
                    // Orthographic
                    float4x4 viewMat = GetWorldToViewMatrix();
                    return viewMat[2].xyz;
                }
            }
#endif

            half4 frag(Varyings IN) : SV_Target
            {
                float3 tangentNormal = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv));
                tangentNormal.xy *= 6.5f; // BumpMap Strength.

                float3 N = CombineTBN(tangentNormal, IN.T, IN.B, IN.N);

                float3 V = normalize(GetWorldSpaceViewDir(IN.positionWS));
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
