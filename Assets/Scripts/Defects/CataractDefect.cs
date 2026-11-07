using UnityEngine;

/// <summary>
/// Symulacja Zaćmy (Cataract):
/// 1. Obniżenie kontrastu i nasycenia barw w OVRPassthroughLayer (świat rzeczywisty).
/// 2. Nakładka na Quadzie z efektem mleczno-żółtej mgły i "zabrudzonej soczewki" (VisionDefect_Cataract.shader).
/// Uwaga: Nie używamy URP Post-Processing (Bloom/ColorAdjustments), ponieważ w trybie Underlay Passthrough
/// przebieg post-processingu URP nadpisuje kanał alfa bufora oka na 1.0, co daje czarny ekran Passthrough.
/// </summary>
public class CataractDefect : VisionDefectBase
{
    [Header("Parametry Zaćmy - Passthrough")]
    [SerializeField, Range(-1f, 0f)] private float maxContrastReduction = -0.45f;
    [SerializeField, Range(-1f, 0f)] private float maxSaturationReduction = -0.55f;
    [SerializeField, Range(-0.5f, 0.5f)] private float maxBrightnessShift = -0.05f;

    [Header("Parametry Zaćmy - Nakładka (Mgła i Brudna Szyba)")]
    [SerializeField] private Color hazeColor = new Color(0.95f, 0.89f, 0.72f, 0.78f);
    [SerializeField, Range(0f, 1f)] private float cloudiness = 0.5f;
    [SerializeField, Range(0f, 0.25f)] private float frostScatter = 0.09f;

    protected override string DefaultShaderName => "Ocularis/Defects/Cataract";
    protected override string DefaultDefectType => "Zacma";

    private static readonly int HazeColorProp = Shader.PropertyToID("_HazeColor");
    private static readonly int CloudinessProp = Shader.PropertyToID("_Cloudiness");
    private static readonly int FrostScatterProp = Shader.PropertyToID("_FrostScatter");

    private void Reset()
    {
        defectType = "Zacma";
    }

    protected override void InitializeDefect()
    {
        if (string.IsNullOrEmpty(defectType) || defectType == "Defect")
        {
            defectType = "Zacma";
        }
    }

    protected override void ApplyDefect(float currentIntensity)
    {
        // 1. Passthrough: mniejszy kontrast i wyblakłe kolory świata rzeczywistego
        if (passthroughLayer != null)
        {
            passthroughLayer.SetBrightnessContrastSaturation(
                Mathf.Lerp(0f, maxBrightnessShift, currentIntensity),
                Mathf.Lerp(0f, maxContrastReduction, currentIntensity),
                Mathf.Lerp(0f, maxSaturationReduction, currentIntensity)
            );
        }

        // 2. Shader nakładki: mleczno-żółta mgła i zmętnienie soczewki
        if (RuntimeMaterial != null)
        {
            RuntimeMaterial.SetColor(HazeColorProp, hazeColor);
            RuntimeMaterial.SetFloat(CloudinessProp, cloudiness);
            RuntimeMaterial.SetFloat(FrostScatterProp, frostScatter);
        }
    }
}
