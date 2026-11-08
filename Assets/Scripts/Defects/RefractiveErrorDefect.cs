using UnityEngine;

/// <summary>
/// Symulacja wad refrakcji zależnych od odległości:
/// - Krótkowzroczność (Myopia): pacjent widzi ostro z bliska, ale obraz w oddali jest zamazany.
///   intensity -> siła rozmycia (rozmiar dioptrii / blur radius).
///   intensity2 -> odległość ostrego widzenia (punkt dali wzrokowej: od 0.35m do 2.5m).
/// - Nadwzroczność (Hyperopia): pacjent widzi ostro w oddali, ale obiekty blisko oczu (dłonie, tekst) są zamazane.
///   intensity -> siła rozmycia.
///   intensity2 -> odległość bliży wzrokowej (jak daleko przed oczy sięga rozmycie: od 0.25m do 1.3m).
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

    [Header("Parametry rozmycia (intensity -> siła nieostrości)")]
    [Tooltip("Świetlisty, aksamitny odcień dyfuzji soczewkowej (brak szarego nalotu)")]
    [SerializeField] private Color blurTint = new Color(0.97f, 0.98f, 1.0f, 0.85f);
    [Tooltip("Maksymalny promień krążka rozproszenia CoC (Bokeh)")]
    [SerializeField, Range(0.005f, 0.060f)] private float maxBlurRadius = 0.035f;

    [Header("Parametry odległości ostrości (intensity2 -> dystans w metrach)")]
    [Tooltip("Krótkowzroczność: odległość ostrego widzenia przy intensity2 = 1 (silna wada, ostro tylko z bliska)")]
    [SerializeField] private float myopiaMinDistance = 0.35f;
    [Tooltip("Krótkowzroczność: odległość ostrego widzenia przy intensity2 = 0 (łagodna wada, ostro do 2.5m)")]
    [SerializeField] private float myopiaMaxDistance = 2.50f;

    [Tooltip("Nadwzroczność: odległość rozmycia przy intensity2 = 0 (tylko obiekty tuż przy twarzy)")]
    [SerializeField] private float hyperopiaMinDistance = 0.25f;
    [Tooltip("Nadwzroczność: odległość rozmycia przy intensity2 = 1 (rozmyte całe pole zasięgu rąk)")]
    [SerializeField] private float hyperopiaMaxDistance = 1.30f;

    protected override string DefaultShaderName
    {
        get
        {
            string dedicatedShader = mode == RefractionMode.Myopia_Krotkowzrocznosc ? "Ocularis/Defects/Myopia" : "Ocularis/Defects/Hyperopia";
            if (Shader.Find(dedicatedShader) != null)
                return dedicatedShader;
            return "Ocularis/Defects/DepthBlur";
        }
    }

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

    protected override void ApplyDefect(float currentIntensity, float currentIntensity2)
    {
        bool isHyperopia = mode == RefractionMode.Hyperopia_Nadwzrocznosc;

        float focusDistance;
        float near;
        float far;

        if (isHyperopia)
        {
            // Nadwzroczność: intensity2 reguluje bliż wzrokową
            focusDistance = Mathf.Lerp(hyperopiaMinDistance, hyperopiaMaxDistance, currentIntensity2);
            near = focusDistance * 0.70f;
            far = focusDistance * 1.25f;
        }
        else
        {
            // Krótkowzroczność: intensity2 reguluje punkt dali wzrokowej
            focusDistance = Mathf.Lerp(myopiaMaxDistance, myopiaMinDistance, currentIntensity2);
            near = focusDistance * 0.80f;
            far = focusDistance * 1.30f;
        }

        if (RuntimeMaterial != null)
        {
            if (RuntimeMaterial.HasProperty(InvertDepthProp))
            {
                RuntimeMaterial.SetFloat(InvertDepthProp, isHyperopia ? 1.0f : 0.0f);
            }
            RuntimeMaterial.SetFloat(FocusNearProp, near);
            RuntimeMaterial.SetFloat(FocusFarProp, far);
            RuntimeMaterial.SetColor(BlurTintProp, blurTint);
            RuntimeMaterial.SetFloat(BlurRadiusProp, Mathf.Lerp(0.008f, maxBlurRadius, currentIntensity));
        }
    }
}
