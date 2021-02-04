- [Dev Weeks: URP 셰이더 뜯어보기](https://www.youtube.com/watch?v=9K1uOihvNyg)
- 
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


## 6장. 스펙컬러 구현

## 7장. 서피스 셰이더

## 8장. 물리 기반 셰이딩이란?

## 9장. 물리 기반 셰이더 제작하기

## 10장. 후처리 효과

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