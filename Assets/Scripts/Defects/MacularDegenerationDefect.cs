using UnityEngine;

/// <summary>
/// Symulacja Zwyrodnienia Plamki Żółtej (AMD):
/// 1. Ciemna/rozmyta plama w centrum pola widzenia (mroczek centralny) - sterowana przez intensity.
/// 2. Postać wysiękowa: falowanie prostych linii i metamorfopsja po bokach plamy - sterowana przez intensity2.
/// </summary>
public class MacularDegenerationDefect : VisionDefectBase
{
    [Header("Parametry AMD - Mroczek centralny (intensity -> rozmiar i gęstość plamy)")]
    [SerializeField] private Color scotomaColor = new Color(0.04f, 0.04f, 0.04f, 0.96f);
    [SerializeField, Range(0.04f, 0.35f)] private float maxScotomaRadius = 0.16f;
    [SerializeField, Range(0.02f, 0.25f)] private float edgeSoftness = 0.08f;

    [Header("Parametry AMD - Postać wysiękowa (intensity2 -> falowanie boków / metamorfopsja)")]
    [SerializeField] private bool enableWetFormDistortion = true;
    [SerializeField, Range(0.01f, 0.08f)] private float maxWaveAmplitude = 0.045f;
    [SerializeField, Range(5f, 40f)] private float waveFrequency = 18.0f;

    protected override string DefaultShaderName => "Ocularis/Defects/AMD";
    protected override string DefaultDefectType => "AMD";

    private static readonly int ScotomaColorProp = Shader.PropertyToID("_ScotomaColor");
    private static readonly int MaxRadiusProp = Shader.PropertyToID("_MaxRadius");
    private static readonly int SoftnessProp = Shader.PropertyToID("_Softness");
    private static readonly int WaveAmplitudeProp = Shader.PropertyToID("_WaveAmplitude");
    private static readonly int WaveFrequencyProp = Shader.PropertyToID("_WaveFrequency");

    private void Reset()
    {
        defectType = "AMD";
    }

    protected override void InitializeDefect()
    {
        if (string.IsNullOrEmpty(defectType) || defectType == "Defect")
        {
            defectType = "AMD";
        }
    }

    protected override void ApplyDefect(float currentIntensity, float currentIntensity2)
    {
        if (RuntimeMaterial != null)
        {
            float activeWaveAmp = enableWetFormDistortion ? Mathf.Lerp(0f, maxWaveAmplitude, currentIntensity2) : 0f;

            RuntimeMaterial.SetColor(ScotomaColorProp, scotomaColor);
            RuntimeMaterial.SetFloat(MaxRadiusProp, maxScotomaRadius);
            RuntimeMaterial.SetFloat(SoftnessProp, edgeSoftness);
            RuntimeMaterial.SetFloat(WaveAmplitudeProp, activeWaveAmp);
            RuntimeMaterial.SetFloat(WaveFrequencyProp, waveFrequency);
        }
    }
}
