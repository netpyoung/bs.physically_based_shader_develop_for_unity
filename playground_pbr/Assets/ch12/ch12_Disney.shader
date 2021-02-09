Shader "shader/ch12_Disney"
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

        _Subsurface("Subsurface", Range(0,1)) = 0.5
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

            CBUFFER_START(UnityPerMaterial)
                half4 _ColorTint;
                float4 _MainTex_ST;
                half4 _SpecColor;
                float4 _BumpMap_ST;
                half _Roughness;
                float3 _Subsurface;
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
                float alpha = sqr(roughness);

                // D
                float alphaSqr = sqr(alpha);
                float denom = sqr(NdotH) * (alphaSqr - 1.0) + 1.0f;
                float D = alphaSqr / (PI * sqr(denom));

                // F
                float LdotH5 = FresnelSchlick(LdotH);
                float F = F0 + (1.0 - F0) * LdotH5;

                // G
                float r = _Roughness + 1;
                float k = sqr(r) / 8;
                float g1L = G1(k, NdotL);
                float g1V = G1(k, NdotV);
                float G = g1L * g1V;

                float specular = NdotL * D * F * G;
                return specular;
            }

            float3 DiffuseDisney(float3 albedo, float NdotL, float NdotV, float LdotH, float roughness)
            {
                // luminance approx.
                float albedoLuminosity = 0.3 * albedo.r + 0.6 * albedo.g + 0.1 * albedo.b;

                // normalize lum. to isolate hue+sat
                float3 albedoTint = 1;
                if (albedoLuminosity > 0)
                {
                    albedoTint = albedo / albedoLuminosity;
                }
                float fresnelL = FresnelSchlick(NdotL);
                float fresnelV = FresnelSchlick(NdotV);

                float fresnelDiffuse = 0.5 + 2 * sqr(LdotH) * roughness;

                float diffuse = albedoTint.r
                    * lerp(1.0, fresnelDiffuse, fresnelL)
                    * lerp(1.0, fresnelDiffuse, fresnelV);

                float fresnelSubsurface90 = sqr(LdotH) * roughness;

                float fresnelSubsurface = lerp(1.0, fresnelSubsurface90, fresnelL)
                    * lerp(1.0, fresnelSubsurface90, fresnelV);

                float ss = 1.25 * (fresnelSubsurface * (1 / (NdotL + NdotV) - 0.5) + 0.5);

                return saturate(lerp(diffuse, ss, _Subsurface) * (1 / PI) * albedo);
            }

            float3 FresnelSchlickFrostbite(float3 F0, float F90, float u)
            {
                return F0 + (F90 - F0) * pow(1 - u, 5);
            }

            float3 DiffuseDisneyFrostbite(float3 albedo, float NdotL, float NdotV, float LdotH, float roughness)
            {
                float energyBias = lerp(0, 0.5, roughness);
                float energyFactor = lerp(1.0, 1.0 / 1.51, roughness);
                float Fd90 = energyBias + 2.0 * sqr(LdotH) * roughness;
                float3 F0 = float3 (1, 1, 1);
                float lightScatter = FresnelSchlickFrostbite(F0, Fd90, NdotL).r;
                float viewScatter = FresnelSchlickFrostbite(F0, Fd90, NdotV).r;
                return ((lightScatter * viewScatter * energyFactor) * albedo) /PI;
            }

            half DiffuseOrenNayar_Fakey(half3 N, half3 L, half3 V, half roughness)
            {
                // ref: https://kblog.popekim.com/2011/11/blog-post_16.html

                // Through brute force iteration I found this approximation. Time to test it out.
                half LdotN = dot(L, N);
                half VdotN = dot(V, N);
                half result = saturate(LdotN);
                half soft_rim = saturate(1 - VdotN / 2); //soft view dependant rim
                half fakey = pow(1 - result * soft_rim, 2);//modulate lambertian by rim lighting
                half fakey_magic = 0.62;
                //(1-fakey)*fakey_magic to invert and scale down the lighting
                fakey = fakey_magic - fakey * fakey_magic;
                return lerp(result, fakey, roughness);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                float3 tangentNormal = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, IN.uv));
               // tangentNormal.xy *= 6.5f; // BumpMap Strength.

                Light light = GetMainLight();

                float3 N = CombineTBN(tangentNormal, IN.T, IN.B, IN.N);
                float3 V = normalize(GetWorldSpaceViewDir(IN.positionWS));
                float3 L = light.direction;
                float3 H = normalize(L + V);

                float NdotL = saturate(dot(N, L));
                float NdotH = saturate(dot(N, H));
                float NdotV = saturate(dot(N, V));
                float VdotH = saturate(dot(V, H));
                float LdotH = saturate(dot(L, H));

                half3 lightColor = light.color;

                half3 albedo = (_ColorTint * tex).rgb;
                half3 diffuse = DiffuseDisney(albedo, NdotL, NdotV, LdotH, _Roughness) * lightColor;
                //half3 diffuse = DiffuseDisneyFrostbite(albedo,  NdotL, NdotV, LdotH, _Roughness) * lightColor;
                //half3 diffuse = DiffuseOrenNayar_Fakey(N, L, V, _Roughness) * lightColor * albedo;
#if _ENABLECOOKTORRANCE_ON
                half3 specular = SpecularCookTorrance(NdotL, LdotH, NdotH, NdotV, _Roughness, _SpecColor.r) * _SpecColor.rgb * lightColor;
#else
                half3 R = reflect(-L, N);
                half3 VdotR = max(0.0, dot(V, R));
                half3 specPower = pow(VdotR, 22);
                half3 specular = _SpecColor.rgb * specPower * lightColor;
#endif
                return half4(diffuse + specular, 1);
            }
            ENDHLSL
        }
    }
}
