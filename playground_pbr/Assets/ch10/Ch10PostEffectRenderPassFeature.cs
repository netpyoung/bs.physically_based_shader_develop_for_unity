using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class Ch10PostEffectRenderPassFeature : ScriptableRendererFeature
{
    public enum E_MODE
    {
        INVERT,
        DEPTH,
        GAMMA_TO_LINEAR,
        TONE_MAPPING,
        DEFAULT,
    }

    class Ch10PostEffectRenderPass : ScriptableRenderPass
    {
        private RenderTargetIdentifier _source;
        private RenderTargetHandle _tempTexture;
        private Ch10PostEffectRenderPassFeature _feature;

        public Ch10PostEffectRenderPass(Ch10PostEffectRenderPassFeature feature)
        {
            _feature = feature;
            _tempTexture.Init("_TempTex");
        }

        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in an performance manner.
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get($"{nameof(Ch10PostEffectRenderPass)}");
            {
                RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
                desc.depthBufferBits = 0;
                cmd.GetTemporaryRT(_tempTexture.id, desc, FilterMode.Bilinear);

                switch (_feature.Mode)
                {
                    case E_MODE.INVERT:
                        Blit(cmd, _source, _tempTexture.Identifier(), _feature.material, 0);
                        break;
                    case E_MODE.DEPTH:
                        Blit(cmd, _source, _tempTexture.Identifier(), _feature.material, 1);
                        break;
                    case E_MODE.GAMMA_TO_LINEAR:
                        // Project Settings> Player> Other Settings> Color Space> Gamma
                        Blit(cmd, _source, _tempTexture.Identifier(), _feature.material, 2);
                        break;
                    case E_MODE.TONE_MAPPING:
                        _feature.material.SetFloat("_ToneMapperExposure", _feature.ToneMapperExposure);
                        Blit(cmd, _source, _tempTexture.Identifier(), _feature.material, 3);
                        break;
                    case E_MODE.DEFAULT:
                        Blit(cmd, _source, _tempTexture.Identifier());
                        break;
                    default:
                        break;
                }
                Blit(cmd, _tempTexture.Identifier(), _source);

                context.ExecuteCommandBuffer(cmd);
            }
            CommandBufferPool.Release(cmd);
        }

        /// Cleanup any allocated resources that were created during the execution of this render pass.
        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(_tempTexture.id);
        }

        internal void SetSource(RenderTargetIdentifier cameraColorTarget)
        {
            this._source = cameraColorTarget;
        }
    }

    Ch10PostEffectRenderPass _scriptablePass;

    public Material material;
    public E_MODE Mode;
    [Range(1.0f, 10.0f)]
    public float ToneMapperExposure = 2.0f;

    public override void Create()
    {
        _scriptablePass = new Ch10PostEffectRenderPass(this);

        // Configures where the render pass should be injected.
        //m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        _scriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        _scriptablePass.SetSource(renderer.cameraColorTarget);
        renderer.EnqueuePass(_scriptablePass);
    }
}


