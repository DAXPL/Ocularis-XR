using UnityEngine;

/// <summary>
/// Symulacja wad refrakcji zależnych od odległości:
/// - Krótkowzroczność (Myopia): pacjent widzi ostro z bliska, ale obraz w oddali jest zamazany.
/// - Nadwzroczność (Hyperopia): pacjent widzi ostro w oddali, ale obiekty blisko oczu (np. dłonie, tekst) są zamazane.
/// Wykorzystuje Meta Depth API (_EnvironmentDepthTexture z [BuildingBlock] Occlusion).
/// </summary>
public class RefractiveErrorDefect : VisionDefectBase
{
    public enum RefractionMode
    {
        Myopia_Krotkowzrocznosc = 0,
        Hyperopia_Nadwzrocznosc = 1
    }

    [Header("Tryb wady refrakcji")]
    [SerializeField] private RefractionMode mode = RefractionMode.Myopia_Krotkowzrocznosc;

    [Header("Zakres ostrości (w metrach)")]
    [Tooltip("Początek strefy przejścia między ostrym a rozmytym obrazem (w metrach)")]
    [SerializeField, Range(0.15f, 2.5f)] private float transitionNearMeters = 0.50f;
    [Tooltip("Koniec strefy przejścia między ostrym a rozmytym obrazem (w metrach)")]
    [SerializeField, Range(0.35f, 5.0f)] private float transitionFarMeters = 1.25f;

    [Header("Parametry rozmycia")]
    [SerializeField] private Color blurTint = new Color(0.88f, 0.90f, 0.92f, 0.72f);
    [SerializeField, Range(0f, 0.035f)] private float maxBlurRadius = 0.016f;

    protected override string DefaultShaderName => "Ocularis/Defects/DepthBlur";
    protected override string DefaultDefectType => mode == RefractionMode.Myopia_Krotkowzrocznosc ? "Krotkowzrocznosc" : "Nadwzrocznosc";

    private static readonly int InvertDepthProp = Shader.PropertyToID("_InvertDepth");
    private static readonly int FocusNearProp = Shader.PropertyToID("_FocusNear");
    private static readonly int FocusFarProp = Shader.PropertyToID("_FocusFar");
    private static readonly int BlurTintProp = Shader.PropertyToID("_BlurTint");
    private static readonly int BlurRadiusProp = Shader.PropertyToID("_BlurRadius");

    private void Reset()
    {
        defectType = mode == RefractionMode.Myopia_Krotkowzrocznosc ? "Krotkowzrocznosc" : "Nadwzrocznosc";
    }

    protected override void InitializeDefect()
    {
        if (string.IsNullOrEmpty(defectType) || defectType == "Defect")
        {
            defectType = mode == RefractionMode.Myopia_Krotkowzrocznosc ? "Krotkowzrocznosc" : "Nadwzrocznosc";
        }
    }

    protected override void ApplyDefect(float currentIntensity)
    {
        bool isHyperopia = mode == RefractionMode.Hyperopia_Nadwzrocznosc;

        // Shader DepthBlur (korzystający z Meta Depth API dla pokoju oraz dłoni)
        if (RuntimeMaterial != null)
        {
            RuntimeMaterial.SetFloat(InvertDepthProp, isHyperopia ? 1.0f : 0.0f);
            RuntimeMaterial.SetFloat(FocusNearProp, transitionNearMeters);
            RuntimeMaterial.SetFloat(FocusFarProp, transitionFarMeters);
            RuntimeMaterial.SetColor(BlurTintProp, blurTint);
            RuntimeMaterial.SetFloat(BlurRadiusProp, maxBlurRadius);
        }
    }
}
