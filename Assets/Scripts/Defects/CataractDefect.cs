using UnityEngine;

/// <summary>
/// Symulacja Zaćmy (Cataract):
/// - intensity: ogólne zmętnienie soczewki, mleczno-żółta mgła oraz spadek kontrastu Passthrough.
/// - intensity2: stopień niejednorodności zmętnienia ("brudna szyba") oraz rozproszenia światła wokół źródeł (efekt olśnienia).
/// </summary>
public class CataractDefect : VisionDefectBase
{
    [Header("Parametry Zaćmy - Passthrough (intensity)")]
    [SerializeField, Range(-1f, 0f)] private float maxContrastReduction = -0.45f;
    [SerializeField, Range(-1f, 0f)] private float maxSaturationReduction = -0.55f;
    [SerializeField, Range(-0.5f, 0.5f)] private float maxBrightnessShift = -0.05f;

    [Header("Parametry Zaćmy - Nakładka (intensity2 -> niejednorodność i rozproszenie światła)")]
    [SerializeField] private Color hazeColor = new Color(0.95f, 0.89f, 0.72f, 0.78f);
    [SerializeField, Range(0.1f, 1f)] private float maxCloudiness = 0.75f;
    [SerializeField, Range(0.02f, 0.25f)] private float maxFrostScatter = 0.14f;

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

    protected override void ApplyDefect(float currentIntensity, float currentIntensity2)
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

        // 2. Shader nakładki: zmętnienie soczewki (intensity2 reguluje plamistość i rozproszenie światła)
        if (RuntimeMaterial != null)
        {
            float activeCloudiness = Mathf.Lerp(0.15f, maxCloudiness, currentIntensity2);
            float activeScatter = Mathf.Lerp(0.01f, maxFrostScatter, currentIntensity2);

            RuntimeMaterial.SetColor(HazeColorProp, hazeColor);
            RuntimeMaterial.SetFloat(CloudinessProp, activeCloudiness);
            RuntimeMaterial.SetFloat(FrostScatterProp, activeScatter);
        }
    }
}
