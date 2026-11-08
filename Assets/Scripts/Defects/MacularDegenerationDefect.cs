using UnityEngine;

/// <summary>
/// Symulacja Zwyrodnienia Plamki Żółtej (AMD):
/// 1. Ciemna/rozmyta plama w centrum pola widzenia (mroczek centralny).
/// 2. W postaci wysiękowej: falowanie prostych linii i deformacja obrazu wokół plamki centralnej.
/// </summary>
public class MacularDegenerationDefect : VisionDefectBase
{
    [Header("Parametry AMD - Mroczek centralny")]
    [SerializeField] private Color scotomaColor = new Color(0.04f, 0.04f, 0.04f, 0.96f);
    [SerializeField, Range(0.04f, 0.35f)] private float maxScotomaRadius = 0.16f;
    [SerializeField, Range(0.02f, 0.25f)] private float edgeSoftness = 0.08f;

    [Header("Parametry AMD - Postać wysiękowa (Falowanie boków)")]
    [SerializeField] private bool enableWetFormDistortion = true;
    [SerializeField, Range(0f, 0.08f)] private float waveAmplitude = 0.035f;
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

    protected override void ApplyDefect(float currentIntensity)
    {
        if (RuntimeMaterial != null)
        {
            RuntimeMaterial.SetColor(ScotomaColorProp, scotomaColor);
            RuntimeMaterial.SetFloat(MaxRadiusProp, maxScotomaRadius);
            RuntimeMaterial.SetFloat(SoftnessProp, edgeSoftness);
            RuntimeMaterial.SetFloat(WaveAmplitudeProp, enableWetFormDistortion ? waveAmplitude : 0f);
            RuntimeMaterial.SetFloat(WaveFrequencyProp, waveFrequency);
        }
    }
}
