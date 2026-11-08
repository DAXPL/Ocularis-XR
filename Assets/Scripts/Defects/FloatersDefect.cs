using UnityEngine;

/// <summary>
/// Symulacja Mętów Ciała Szklistego (Vitreous Floaters):
/// Półprzezroczyste kropki, nitki i wstążki, które poruszają się z bezwładnością
/// przy ruchach głowy/oczu i powoli dryfują w dół pod wpływem grawitacji.
/// Parametry:
/// - intensity: widoczność i wyrazistość mętów (od ledwo widocznych cieni do ciemnych nitek)
/// - intensity2: liczba i gęstość mętów (od 2-3 nitek do gęstego roju mętów)
/// </summary>
public class FloatersDefect : VisionDefectBase
{
    [Header("Parametry wyglądu mętów")]
    [SerializeField] private Color floaterColor = new Color(0.08f, 0.08f, 0.09f, 0.68f);
    [Tooltip("Rozmiar mętów")]
    [SerializeField, Range(0.5f, 2.5f)] private float floaterSize = 1.0f;

    [Header("Parametry drugiego suwaka (intensity2 -> ilość mętów)")]
    [Tooltip("Minimalna gęstość przy intensity2 = 0 (kilka pojedynczych mętów)")]
    [SerializeField, Range(0.2f, 1.2f)] private float minDensity = 0.45f;
    [Tooltip("Maksymalna gęstość przy intensity2 = 1 (duża liczba nitek i muszek)")]
    [SerializeField, Range(1.5f, 4.0f)] private float maxDensity = 2.8f;

    [Header("Fizyka pływania w ciele szklistym (Bezwładność)")]
    [SerializeField, Range(0.05f, 1.5f)] private float inertiaSensitivity = 0.42f;
    [SerializeField, Range(0.1f, 2.0f)] private float dampingTime = 0.65f;
    [SerializeField, Range(0.05f, 0.5f)] private float maxLagOffset = 0.24f;
    [SerializeField, Range(0f, 0.05f)] private float gravitySwimSpeed = 0.015f;

    protected override string DefaultShaderName => "Ocularis/Defects/Floaters";
    protected override string DefaultDefectType => "Mety";

    private static readonly int FloaterColorProp = Shader.PropertyToID("_FloaterColor");
    private static readonly int InertiaOffsetProp = Shader.PropertyToID("_InertiaOffset");
    private static readonly int DensityProp = Shader.PropertyToID("_Density");
    private static readonly int FloaterSizeProp = Shader.PropertyToID("_FloaterSize");

    private Vector3 _lastForward;
    private Vector2 _currentOffset;
    private Vector2 _offsetVelocity;
    private float _swimPhase;

    private void Reset()
    {
        defectType = "Mety";
    }

    protected override void InitializeDefect()
    {
        if (string.IsNullOrEmpty(defectType) || defectType == "Defect")
        {
            defectType = "Mety";
        }
    }

    protected override void OnDefectEnabled()
    {
        _lastForward = transform.forward;
        _currentOffset = Vector2.zero;
        _offsetVelocity = Vector2.zero;
    }

    private void Update()
    {
        if (!IsActive || RuntimeMaterial == null) return;

        // Obliczamy obrót głowy od ostatniej klatki w lokalnym układzie oka
        Vector3 currentForward = transform.forward;
        Vector3 localDelta = transform.InverseTransformDirection(currentForward - _lastForward);
        _lastForward = currentForward;

        // Ruch głowy nadaje mętom pęd, a następnie ciecz szklista powoli wyhamowuje je do środka
        Vector2 impulse = new Vector2(localDelta.x, localDelta.y) * inertiaSensitivity;
        _currentOffset = Vector2.ClampMagnitude(_currentOffset + impulse, maxLagOffset);
        _currentOffset = Vector2.SmoothDamp(_currentOffset, Vector2.zero, ref _offsetVelocity, dampingTime);

        // Powolny dryf organiczny (delikatne opadanie i pływanie w cieczy)
        _swimPhase += Time.deltaTime * gravitySwimSpeed;
        Vector2 gentleDrift = new Vector2(
            Mathf.Sin(_swimPhase * 3.1f) * 0.018f,
            Mathf.Cos(_swimPhase * 2.3f) * 0.024f
        );

        Vector2 totalOffset = _currentOffset + gentleDrift;
        RuntimeMaterial.SetVector(InertiaOffsetProp, new Vector4(totalOffset.x, totalOffset.y, 0f, 0f));
    }

    protected override void ApplyDefect(float currentIntensity, float currentIntensity2)
    {
        if (RuntimeMaterial == null) return;

        // intensity -> widoczność i wyrazistość mętów (przezroczystość bufora w shaderze: _Intensity)
        // intensity2 -> gęstość i ilość mętów (Shader: _Density)
        float calculatedDensity = Mathf.Lerp(minDensity, maxDensity, currentIntensity2);

        RuntimeMaterial.SetColor(FloaterColorProp, floaterColor);
        RuntimeMaterial.SetFloat(DensityProp, calculatedDensity);
        RuntimeMaterial.SetFloat(FloaterSizeProp, floaterSize);
    }
}
