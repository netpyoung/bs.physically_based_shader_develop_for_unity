using System.Collections;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

public class NewBehaviourScript : MonoBehaviour
{
    [SerializeField] public ForwardRendererData rendererData;
    [SerializeField] public bool isOn;
    public Material material;
    public RenderPipelineAsset renderPipelineAsset;
    void Start()
    {
        //ScriptableRendererFeature feature = rendererData.rendererFeatures.FirstOrDefault(x => x.name == "A");
        //var cp = feature as CustomRenderPassFeature;
        //cp.material.SetFloat("_On", 1);
        
        //var cc = ScriptableObject.CreateInstance<CustomRenderPassFeature>();
        //cc.material = material;
        //rendererData.rendererFeatures.Add(cc);
        GraphicsSettings.renderPipelineAsset = renderPipelineAsset;
    }
}
