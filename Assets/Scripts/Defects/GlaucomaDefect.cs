using UnityEngine;

/// <summary>
/// Symulacja Jaskry (Glaucoma):
/// Stopniowe zanikanie obwodowego pola widzenia aż do tzw. widzenia lunetowego.
/// Parametry:
/// - intensity: stopień zwężenia pola widzenia (od szerokiego pola do widzenia lunetowego)
/// - intensity2: miękkość i charakter brzegu ubytku (od ostrej granicy mroczka do miękkiej winiety)
/// </summary>
public class GlaucomaDefect : VisionDefectBase
{
    [Header("Parametry Jaskry (intensity -> stopień ubytku pola)")]
    [SerializeField] private Color vignetteColor = new Color(0.01f, 0.01f, 0.01f, 1.0f);
    [SerializeField, Range(0.08f, 0.45f)] private float minTunnelRadius = 0.26f;
    [SerializeField, Range(0.5f, 1.2f)] private float maxOpenRadius = 0.85f;

    [Header("Parametry Jaskry (intensity2 -> miękkość brzegu)")]
    [SerializeField, Range(0.04f, 0.25f)] private float minEdgeSoftness = 0.08f;
    [SerializeField, Range(0.15f, 0.50f)] private float maxEdgeSoftness = 0.35f;
    [SerializeField, Range(0f, 0.08f)] private float edgeIrregularity = 0.015f;

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

    protected override void ApplyDefect(float currentIntensity, float currentIntensity2)
    {
        if (RuntimeMaterial == null) return;

        float calculatedSoftness = Mathf.Lerp(minEdgeSoftness, maxEdgeSoftness, currentIntensity2);

        RuntimeMaterial.SetColor(VignetteColorProp, vignetteColor);
        RuntimeMaterial.SetFloat(MinRadiusProp, minTunnelRadius);
        RuntimeMaterial.SetFloat(MaxRadiusProp, maxOpenRadius);
        RuntimeMaterial.SetFloat(EdgeSoftnessProp, calculatedSoftness);
        RuntimeMaterial.SetFloat(EdgeIrregularityProp, edgeIrregularity);
    }
}
