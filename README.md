- [Dev Weeks: URP 기본 구성과 흐름](https://www.youtube.com/watch?v=QRlz4-pAtpY)
- [Dev Weeks: URP 셰이더 뜯어보기](https://www.youtube.com/watch?v=9K1uOihvNyg)

``` tree
Packages/
|-- Core RP Library/
|  |-- ShaderLibrary/
|  |  |-- SpaceTransform.hlsl - 공간변환 행렬. Tangent<->World행렬
|  |  |-- Common.hlsl - 각종 수학. 텍스쳐 유틸, 뎁스 계산 ..
|  |  |-- >>> EntityLighting.hlsl - SH, ProveVolume, Lightmap계산 ???
|  |  |-- ImageBasedLighting - IBL관련 부분(GGX, Anisotropy, ImportanceSample)
|-- Universal RP/
|  |-- ShaderLibrary/
|  |  |-- Core.hlsl - 버텍스 인풋 구조체, 스크린UV계산,Fog계산
|  |  |-- Lighting.hlsl - 라이트 구조체, diffuse, specular, GI
|  |  |-- Shadows.hlsl - 쉐도우맵 샘플링, 캐스케이드 계산, ShadowCoord계산 , Shadow Bias계산
|  |-- Shaders/
```


## 1장. 셰이더 개발 과정

### Forward

``` ruby
for object in objects
    for light in lights
        FrameBuffer = LightModel(object, light);
    end
end

for light in lights
    for object in GetObjectsAffectedByLight(light)
        FrameBuffer += LightModel(object, light);
    end
end
```

![./forward-v2.png](./forward-v2.png)
라이트 갯수 증가> 연산량 증가

### Deferred

``` ruby
for object in objects:
  GBuffer = GetLightingProperties(object)
end

for light in lights
  Framebuffer += LightModel(GBuffer, light)
end
```

![./deferred-v2.png](./deferred-v2.png)

- 반투명 불가
- URP - 현재(10.3.1)지원 안함.
  - [URP 로드맵](https://portal.productboard.com/8ufdwj59ehtmsvxenjumxo82/tabs/3-universal-render-pipeline)
- [블라인드 렌더러 -  새로운 기법 != 새 장난감](https://kblog.popekim.com/2012/02/blog-post.html)

## 2장. 첫 유니티 셰이더

- [Built-in vs URP](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@10.3/manual/universalrp-builtin-feature-comparison.html)

``` txt
Create> Rendering> Universal Render Pipeline> Pipeline Asset(Forward Renderer)

Assets/
|-- UniversalRenderPipelineAsset.asset
|-- UniversalRenderPipelineAsset_Renderer.asset

Project Settings> Graphics> Scriptable Render Pipeline Settings> UniversalRenderPipelineAsset.asset

UniversalRenderPipelineAsset.asset> Quality> HDR check

Project Settings> Player> Other Settings> Color Space> Linear
```

- [URP unlit basic shader](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@10.3/manual/writing-shaders-urp-basic-unlit-structure.html)

``` hlsl
Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
Tags { "LightMode" = "SRPDefaultUnlit" } // 라이트 모드 태그 기본값
```

- [URP ShaderLab Pass tags](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@10.3/manual/urp-shaders/urp-shaderlab-pass-tags.html)

| LightMode            | URP Support |
|----------------------|-------------|
| UniversalForward     | O           |
| UniversalGBuffer     | O           |
| UniversalForwardOnly | O           |
| Universal2D          | O           |
| ShadowCaster         | O           |
| DepthOnly            | O           |
| Meta                 | O           |
| SRPDefaultUnlit      | O(기본값)   |
| Always               | X           |
| ForwardAdd           | X           |
| PrepassBase          | X           |
| PrepassFinal         | X           |
| Vertex               | X           |
| VertexLMRGBM         | X           |
| VertexLM             | X           |

## 3장. 그래픽스 파이프라인

``` cs
// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
// |-- #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

// Core RP Library/ShaderLibrary/SpaceTransforms.hlsl

// UNITY_MATRIX_M * (UNITY_MATRIX_VP * positionOS)

float4 TransformObjectToHClip(float3 positionOS)
{
    // More efficient than computing M*VP matrix product
    return mul(GetWorldToHClipMatrix(), mul(GetObjectToWorldMatrix(), float4(positionOS, 1.0)));
}
```

## 4장. 좌표 공간 변환

| Space |                        |
|-------|------------------------|
| WS    | world space            |
| VS    | view space             |
| OS    | object space           |
| CS    | Homogenous clip spaces |
| TS    | tangent space          |
| TXS   | texture space          |

| built-in(legacy)         | URP                          |
|--------------------------|------------------------------|
| UnityObjectToWorldDir    | TransformObjectToWorldDir    |
| UnityObjectToWorldNormal | TransformObjectToWorldNormal |
| UnityWorldSpaceViewDir   | TransformWorldToViewDir      |
| UnityWorldSpaceLightDir  | x                            |

``` hlsl
float4x4 GetObjectToWorldMatrix() UNITY_MATRIX_M;
float4x4 GetWorldToObjectMatrix() UNITY_MATRIX_I_M;
float4x4 GetWorldToViewMatrix()   UNITY_MATRIX_V;
float4x4 GetWorldToHClipMatrix()  UNITY_MATRIX_VP;
float4x4 GetViewToHClipMatrix()   UNITY_MATRIX_P;
```

| built-in(legacy)     | URP                    |
|----------------------|------------------------|
| UnityObjectToClipPos | TransformObjectToHClip |
| UnityWorldToClipPos  | TransformWorldToHClip  |
| UnityViewToClipPos   | TransformWViewToHClip  |

- <https://github.com/Unity-Technologies/Graphics/tree/master/com.unity.render-pipelines.core>
- <https://github.com/Unity-Technologies/Graphics/tree/master/com.unity.render-pipelines.universal>

## 5장. 최초 라이팅 셰이더

``` hlsl
// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
struct Light
{
    half3   direction;
    half3   color;
    half    distanceAttenuation;
    half    shadowAttenuation;
};

Light GetMainLight()

Light GetMainLight(float4 shadowCoord)

// #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Macros.hlsl"
#define TRANSFORM_TEX(tex, name) ((tex.xy) * name##_ST.xy + name##_ST.zw)


// #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/API/D3D11.hlsl"
#define SAMPLE_TEXTURE2D(textureName, samplerName, coord2)                               textureName.Sample(samplerName, coord2)
```

- [URP - Drawing a texture](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@10.3/manual/writing-shaders-urp-unlit-texture.html)

## 6장. 스펙큘러 구현

- TODO 더 많은 광원 지원하기(2 Directional Light)
- <https://catlikecoding.com/unity/tutorials/scriptable-render-pipeline/lights/>

## 7장. 서피스 셰이더

Skip

## 8장. 물리 기반 셰이딩이란?

빛을 측정하는 방법
입체각 Solid Angle - 단위는 sr(steradian)
단위 구로 어떠한 형상을 사영한 것.

파워 W(power) 여러 방향에서 표면을 통과해 전달되는 에너지 크기
일레디안스 모든 광선에서 점에 전달되는 빛의 크기  Irradiance E (W/m^2)
레디안스 하나의 광선에서 점에 전달되는 빛의 크기 Radiance L_0 (W/(m^2 * sr))

재질을 표현하는 방법
양방향 반사 분포 함수 BRDF Bidirectional Reflectance Distribution Function
빛이 표면에서 어떻게 반사될지에 대해 정의한 함수.

| BRDF 속성              |                                                                                              |
|------------------------|----------------------------------------------------------------------------------------------|
| positivity             | BRDF값은 0이상이다                                                                           |
| symmetry (reciprocity) | 빛이 들어오는 방향과 반사되는 방향의 값은 동일하다                                           |
| conservation of energy | 나가는 빛의 양은 들어오는 빛의 양을 넘어설 수 없다(물체가 자체적으로 빛을 발산하지 않는다면) |


미세면 이론
|              |   |
|--------------|---|
| 프레넬       | F |
| 정규분포함수 | D |
| 기하함수     | G |

## 9장. 물리 기반 셰이더 제작하기

phong

``` hlsl
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

// Lafortune and Willems (1994)
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
```

## 10장. 후처리 효과

``` hlsl
// com.unity.render-pipelines.core/ShaderLibrary/API/D3D11.hlsl
#define SAMPLE_TEXTURE2D(textureName, samplerName, coord2)                               textureName.Sample(samplerName, coord2)
#define SAMPLE_DEPTH_TEXTURE(textureName, samplerName, coord2)          SAMPLE_TEXTURE2D(textureName, samplerName, coord2).r
```

``` hlsl
// com.unity.render-pipelines.core/ShaderLibrary/API/Common.hlsl
// Z buffer to linear 0..1 depth (0 at near plane, 1 at far plane).
// Does NOT correctly handle oblique view frustums.
// Does NOT work with orthographic projection.
// zBufferParam = { (f-n)/n, 1, (f-n)/n*f, 1/f }
float Linear01DepthFromNear(float depth, float4 zBufferParam)
{
    return 1.0 / (zBufferParam.x + zBufferParam.y / depth);
}

// Z buffer to linear 0..1 depth (0 at camera position, 1 at far plane).
// Does NOT work with orthographic projections.
// Does NOT correctly handle oblique view frustums.
// zBufferParam = { (f-n)/n, 1, (f-n)/n*f, 1/f }
float Linear01Depth(float depth, float4 zBufferParam)
{
    return 1.0 / (zBufferParam.x * depth + zBufferParam.y);
}

// Z buffer to linear depth.
// Does NOT correctly handle oblique view frustums.
// Does NOT work with orthographic projection.
// zBufferParam = { (f-n)/n, 1, (f-n)/n*f, 1/f }
float LinearEyeDepth(float depth, float4 zBufferParam)
{
    return 1.0 / (zBufferParam.z * depth + zBufferParam.w);
}

// Z buffer to linear depth.
// Correctly handles oblique view frustums.
// Does NOT work with orthographic projection.
// Ref: An Efficient Depth Linearization Method for Oblique View Frustums, Eq. 6.
float LinearEyeDepth(float2 positionNDC, float deviceDepth, float4 invProjParam)
{
    float4 positionCS = float4(positionNDC * 2.0 - 1.0, deviceDepth, 1.0);
    float  viewSpaceZ = rcp(dot(positionCS, invProjParam));

    // If the matrix is right-handed, we have to flip the Z axis to get a positive value.
    return abs(viewSpaceZ);
}

// Z buffer to linear depth.
// Works in all cases.
// Typically, this is the cheapest variant, provided you've already computed 'positionWS'.
// Assumes that the 'positionWS' is in front of the camera.
float LinearEyeDepth(float3 positionWS, float4x4 viewMatrix)
{
    float viewSpaceZ = mul(viewMatrix, float4(positionWS, 1.0)).z;

    // If the matrix is right-handed, we have to flip the Z axis to get a positive value.
    return abs(viewSpaceZ);
}
```
|        | Built-in      | URP                   |
|--------|---------------|-----------------------|
| Camera | Camera:       | RenderPipelineManager |
|        | OnPreCull     | beginFrameRendering   |
|        | OnPreRender   | beginCameraRendering  |
|        | OnPostRender  | endCameraRendering    |
|        | OnRenderImage | endFrameRendering     |


Create> Rendering> Universal Render Pipeline> Renderer Feature

|                            | 자동 생성됨 |                                   |
|----------------------------|-------------|-----------------------------------|
| _CameraDepthTexture        | O           | Pipeline Settings> Depth Texture  |
| _CameraOpaqueTexture       | O           | Pipeline Settings> Opaque Texture |
| _CameraColorTexture        | ??          |                                   |
| _CameraDepthNormalsTexture | X           |                                   |

- <https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@10.3/manual/integration-with-post-processing.html>

``` txt
- Camera> Rendering> Post-Processing 체크
- Hierachy> Volume> Global Volume
- Global Volume> Volume> Profile> New
- Global Volume> Volume> Add Override
```

## 11장. BRDF 누가 누구인가?

## 12장. BRDF 구현하기

## 13장. 표준 셰이더 후킹

## 14장. 고급 기술 구현

## 15장. 아티스트가 사용할 셰이더 제작

## 16장. 복잡도와 우버셰이더

## 17장. 셰이더가 정상작동하지 않을 때

## 18장. 최선 트렌드 따라잡기


| RWS   | Camera-Relative world space. A space where the translation of the Camera have already been substract in order to improve precision |

// normalized / unormalized vector
// normalized direction are almost everywhere, we tag unormalized vector with un.
// Example: unL for unormalized light vector

// use capital letter for regular vector, vector are always pointing outward the current pixel position (ready for lighting equation)
// capital letter mean the vector is normalize, unless we put 'un' in front of it.
// V: View vector  (no eye vector)
// L: Light vector
// N: Normal vector
// H: Half vector


## etc

- [Microfacet BRDF](http://www.pbr-book.org/3ed-2018/Reflection_Models/Microfacet_Models.html#)
- http://www.pbr-book.org/