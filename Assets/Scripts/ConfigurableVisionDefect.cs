using UnityEngine;

public class ConfigurableVisionDefect : MonoBehaviour, IVisionDefect
{
    [Header("Identyfikator wady")]
    [SerializeField] private string defectName = "Zacma";

    [Header("Referencje")]
    [SerializeField] private OVRPassthroughLayer passthroughLayer;
    [SerializeField] private MeshRenderer overlayQuadRenderer;

    [Header("Ustawienia Passthrough (opcjonalne)")]
    [SerializeField] private bool useColorAdjustment = false;
    [SerializeField][Range(-1f, 1f)] private float targetBrightness = 0f;
    [SerializeField][Range(-1f, 1f)] private float targetContrast = 0f;
    [SerializeField][Range(-1f, 1f)] private float targetSaturation = 0f;

    [SerializeField] private bool useColorLut = false;
    [SerializeField] private Texture2D lutTexture;

    [SerializeField] private bool useEdgeRendering = false;
    [SerializeField] private Color targetEdgeColor = new Color(1f, 1f, 1f, 0.5f);

    [Header("Ustawienia Shadera na Quadzie (opcjonalne)")]
    [SerializeField] private Material defectOverlayMaterial;
    [SerializeField] private string intensityShaderProperty = "_Intensity";

    private OVRPassthroughColorLut _passthroughLut;

    // Implementacja właściwości z IVisionDefect
    public string DefectType => defectName;
    public bool IsActive { get; private set; }

    private void Awake()
    {
        if (useColorLut && lutTexture != null)
        {
            _passthroughLut = new OVRPassthroughColorLut(lutTexture, false);
        }
    }

    public void EnableDefect()
    {
        IsActive = true;

        if (overlayQuadRenderer != null && defectOverlayMaterial != null)
        {
            overlayQuadRenderer.sharedMaterial = defectOverlayMaterial;
            overlayQuadRenderer.enabled = true;
        }

        if (passthroughLayer != null && useEdgeRendering)
        {
            passthroughLayer.edgeRenderingEnabled = true;
        }
    }

    public void DisableDefect()
    {
        IsActive = false;

        if (overlayQuadRenderer != null)
        {
            overlayQuadRenderer.enabled = false;
        }

        if (passthroughLayer != null)
        {
            passthroughLayer.DisableColorMap();
            passthroughLayer.edgeRenderingEnabled = false;
        }
    }

    public void SetIntensity(float intensity)
    {
        if (!IsActive) return;

        // 1. Sterowanie Passthrough API
        if (passthroughLayer != null)
        {
            if (useColorAdjustment)
            {
                passthroughLayer.SetBrightnessContrastSaturation(
                    Mathf.Lerp(0f, targetBrightness, intensity),
                    Mathf.Lerp(0f, targetContrast, intensity),
                    Mathf.Lerp(0f, targetSaturation, intensity)
                );
            }
            else if (useColorLut && _passthroughLut != null)
            {
                passthroughLayer.SetColorLut(_passthroughLut, intensity);
            }

            if (useEdgeRendering)
            {
                Color c = targetEdgeColor;
                c.a = Mathf.Lerp(0f, targetEdgeColor.a, intensity);
                passthroughLayer.edgeColor = c;
            }
        }

        // 2. Sterowanie nakładką (Quad / Shader)
        if (overlayQuadRenderer != null && defectOverlayMaterial != null)
        {
            defectOverlayMaterial.SetFloat(intensityShaderProperty, intensity);
        }
    }

    private void OnDestroy()
    {
        _passthroughLut?.Dispose();
    }
}