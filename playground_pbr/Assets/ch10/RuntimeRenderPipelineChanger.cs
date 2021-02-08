using UnityEngine;
using UnityEngine.Rendering;

public class RuntimeRenderPipelineChanger : MonoBehaviour
{
    public Material material;
    public RenderPipelineAsset renderPipelineAsset;

    void Start()
    {
        GraphicsSettings.renderPipelineAsset = renderPipelineAsset;
    }
}
