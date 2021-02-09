Shader "shader/ch14"
{
    Properties
    {
        _ColorTint("Color", Color) = (1, 0, 0, 1)
        _MainTex("Texture", 2D) = "white" {}
        _SpecColor("Specular Color", Color) = (1, 1, 1, 1)
        _BumpMap("Normal Map", 2D) = "bump" {}

        // 0 : NdotL
        // 1 : CookTorrance
        [Toggle] _EnableCookTorrance("CookTorrance?", Float) = 0

        _Roughness("Roughness(CookTorrance)", Range(0, 1)) = 0.5

        //Translucency
        _Thickness("Thickness (R)", 2D) = "white" {}
        _Power("Power Factor", Range(0.1, 10.0)) = 1.0
        _Distortion("Distortion", Range(0.0, 10.0)) = 0.0
        _Scale("Scale Factor", Range(0.0, 10.0)) = 0.5
        _SubsurfaceColor("Subsurface Color", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        Pass
        {
            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma shader_feature _ENABLECOOKTORRANCE_OFF _ENABLECOOKTORRANCE_ON

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
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_Thickness);
            SAMPLER(sampler_Thickness);

            CBUFFER_START(UnityPerMaterial)
                half4 _ColorTint;
                float4 _MainTex_ST;
                half4 _SpecColor;
                float4 _BumpMap_ST;
                half _Roughness;
                float4 _Thickness_ST;
                float _Power;
                float _Distortion;
                float _Scale;
                float4 _SubsurfaceColor;
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
            inline void ExtractTBN(in half3 normalOS, in float4 tangent, inout half3 T, inout half3  B, inout half3 N)
            {
                N = TransformObjectToWorldNormal(normalOS);
                T = TransformObjectToWorldDir(tangent.xyz);
                B = cross(N, T) * tangent.w * unity_WorldTransformParams.w;
            }

            inline half3 CombineTBN(in half3 tangentNormal, in half3 T, in half3  B, in half3 N)
            {
                return mul(tangentNormal, float3x3(normalize(T), normalize(B), normalize(N)));
            }

            Varyings vert(Attributes IN)
            {
                //Varyings OUT;
                Varyings OUT = (Varyings)0;;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);

                ExtractTBN(IN.normalOS, IN.tangent, OUT.T, OUT.B, OUT.N);

                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            // ---------------
            inline float sqr(float value)
            {
                return value * value;
            }

            inline float FresnelSchlick(float value)
            {
                return pow(clamp(1 - value, 0, 1), 5);
            }

            inline float G1(float k, float x)
            {
                return x / (x * (1 - k) + k);
            }

            float3 SpecularCookTorrance(float NdotL, float LdotH, float NdotH, float NdotV, float roughness, float F0)
            {
                // F0 : reflectance ratio
                // ref: https://academy.substance3d.com/courses/the-pbr-guide-part-1

                float alpha = sqr(roughness);

                // D
                float alphaSqr = sqr(alpha);
                float denom = sqr(NdotH) * (alphaSqr - 1.0) + 1.0f;
                float D = alphaSqr / (PI * sqr(denom));

                // F
                float LdotH5 = FresnelSchlick(LdotH);
                float F = F0 + (1.0 - F0) * LdotH;

                // G
                float r = _Roughness + 1;
                float k = sqr(r) / 8;
                float g1L = G1(k, NdotL);
                float g1V = G1(k, NdotV);
                float G = g1L * g1V;

                float specular = NdotL * D * F * G;

                // ref: https://computergraphics.stackexchange.com/questions/3946/correct-specular-term-of-the-cook-torrance-torrance-sparrow-model
                //float specular = (D * F * G) / (4.0 * NdotV * NdotL + 0.000001);
                return specular;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                float3 tangentNormal = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, IN.uv));
                tangentNormal.xy *= 6.5f; // BumpMap Strength.

                Light light = GetMainLight();

                //float3 N = normalize(IN.T); //CombineTBN(tangentNormal, IN.T, IN.B, IN.N);
                float3 N = CombineTBN(tangentNormal, IN.T, IN.B, IN.N);
                float3 V = normalize(GetWorldSpaceViewDir(IN.positionWS));
                float3 L = normalize(light.direction);
                float3 H = normalize(L + V);

                float NdotL = saturate(dot(N, L));
                float NdotH = saturate(dot(N, H));
                float NdotV = saturate(dot(N, V));
                float VdotH = saturate(dot(V, H));
                float LdotH = saturate(dot(L, H));

                half3 lightColor = light.color;

                half3 albedo = (_ColorTint * tex).rgb;
                half3 diffuse = NdotL * albedo;
#if _ENABLECOOKTORRANCE_ON
                half3 specular = SpecularCookTorrance(NdotL, LdotH, NdotH, NdotV, _Roughness, _SpecColor.r);
#else
                half3 R = reflect(-L, N);
                half3 VdotR = max(0.0, dot(V, R));
                half3 specular = pow(VdotR, 22);
#endif

                //Translucency
                float thickness = SAMPLE_TEXTURE2D(_Thickness, sampler_Thickness, IN.uv).r;
                float3 translucencyLightDir = L + N * _Distortion;
                float translucencyDot = pow(saturate(dot(V, -translucencyLightDir)), _Power) * _Scale;
                float3 translucency = translucencyDot * thickness * _SubsurfaceColor.rgb;
                diffuse += translucency;

                return half4((diffuse + specular * _SpecColor.rgb) * lightColor, 1);
            }
            ENDHLSL
        }
    }
}
