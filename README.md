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
- [Dev Weeks: URP 셰이더 뜯어보기](https://www.youtube.com/watch?v=9K1uOihvNyg)

``` tree
Packages/
|-- Core RP Library/
|  |-- ShaderLibrary/
|-- Universal RP/
|  |-- Shaders/
```

```
Create> Rendering> Universal Render Pipeline> Pipeline Asset(Forward Renderer)

Assets/
|-- UniversalRenderPipelineAsset.asset
|-- UniversalRenderPipelineAsset_Renderer.asset

Project Settings> Graphics> Scriptable Render Pipeline Settings> UniversalRenderPipelineAsset.asset
```

- [URP unlit basic shader](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@10.3/manual/writing-shaders-urp-basic-unlit-structure.html)


Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
Tags { "LightMode" = "SRPDefaultUnlit" } // 라이트 모드 태그 기본값

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

## etc

- [Microfacet BRDF](http://www.pbr-book.org/3ed-2018/Reflection_Models/Microfacet_Models.html#)
- http://www.pbr-book.org/