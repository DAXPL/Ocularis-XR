using UnityEngine;

/// <summary>
/// Symulacja Jaskry (Glaucoma):
/// Stopniowe zanikanie obwodowego pola widzenia aż do tzw. widzenia lunetowego
/// (niewielki okrągły obszar widzenia centralnego przy pełnym natężeniu).
/// Shader uwzględnia osobny środek osi optycznej dla lewego i prawego oka w VR.
/// </summary>
public class GlaucomaDefect : VisionDefectBase
{
    [Header("Parametry Jaskry (Ubytek obwodowy)")]
    [SerializeField] private Color vignetteColor = new Color(0.01f, 0.01f, 0.01f, 1.0f);
    [SerializeField, Range(0.02f, 0.35f)] private float minTunnelRadius = 0.055f;
    [SerializeField, Range(0.4f, 1.2f)] private float maxOpenRadius = 0.82f;
    [SerializeField, Range(0.02f, 0.4f)] private float edgeSoftness = 0.14f;
    [SerializeField, Range(0f, 0.15f)] private float edgeIrregularity = 0.045f;

    protected override string DefaultShaderName => "Ocularis/Defects/Glaucoma";
    protected override string DefaultDefectType => "Jaskra";

    private static readonly int VignetteColorProp = Shader.PropertyToID("_VignetteColor");
    private static readonly int MinRadiusProp = Shader.PropertyToID("_MinRadius");
    private static readonly int MaxRadiusProp = Shader.PropertyToID("_MaxRadius");
    private static readonly int EdgeSoftnessProp = Shader.PropertyToID("_EdgeSoftness");
    private static readonly int EdgeIrregularityProp = Shader.PropertyToID("_EdgeIrregularity");

    private void Reset()
    {
        defectType = "Jaskra";
    }

    protected override void InitializeDefect()
    {
        if (string.IsNullOrEmpty(defectType) || defectType == "Defect")
        {
            defectType = "Jaskra";
        }
    }

    protected override void ApplyDefect(float currentIntensity)
    {
        if (RuntimeMaterial == null) return;

        RuntimeMaterial.SetColor(VignetteColorProp, vignetteColor);
        RuntimeMaterial.SetFloat(MinRadiusProp, minTunnelRadius);
        RuntimeMaterial.SetFloat(MaxRadiusProp, maxOpenRadius);
        RuntimeMaterial.SetFloat(EdgeSoftnessProp, edgeSoftness);
        RuntimeMaterial.SetFloat(EdgeIrregularityProp, edgeIrregularity);
    }
}
