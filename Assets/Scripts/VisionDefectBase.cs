using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// Klasa bazowa dla pojedynczej wady wzroku działającej w architekturze "On/Off" (osobny GameObject na wadę).
/// Umieść obiekt z klasą pochodną jako dziecko CenterEyeAnchor (wewnątrz hierarchii VisionDefectManager).
/// Obsługuje dwa parametry kontrolne:
/// - intensity: podstawowa intensywność / wyrazistość wady (0..1)
/// - intensity2: drugi wymiar efektu (np. odległość ostrości dla wad refrakcji, liczba mętów dla floaters itp.)
/// </summary>
public abstract class VisionDefectBase : MonoBehaviour, IVisionDefect
{
    [Header("Identyfikacja i intensywność")]
    [SerializeField] protected string defectType = "Defect";
    [SerializeField, Range(0f, 1f)] protected float intensity = 1.0f;
    [SerializeField, Range(0f, 1f)] protected float intensity2 = 0.5f;

    [Header("Referencje wspólne (automatycznie wykrywane jeśli puste)")]
    [SerializeField] protected OVRPassthroughLayer passthroughLayer;
    [SerializeField] protected Volume globalVolume;
    [SerializeField] protected MeshRenderer overlaySphereRenderer;

    [Header("Konfiguracja Sfery nakładki (wokół głowy)")]
    [SerializeField] protected Shader defectShader;
    [SerializeField] protected Material customMaterialTemplate;
    [Tooltip("Średnica sfery otaczającej głowę (w metrach). Wartość 1.0 oznacza promień 0.5m wokół oczu (powyżej nearClipPlane 0.1m).")]
    [SerializeField, Range(0.4f, 3.0f)] protected float sphereDiameter = 1.0f;

    protected Material RuntimeMaterial { get; private set; }
    protected VolumeProfile RuntimeVolumeProfile => globalVolume != null ? globalVolume.profile : null;
    protected virtual string DefaultShaderName => null;
    protected virtual string DefaultDefectType => "Defect";

    public string DefectType => (string.IsNullOrEmpty(defectType) || defectType == "Defect") ? DefaultDefectType : defectType;
    public bool IsActive { get; private set; }
    public float Intensity => intensity;
    public float Intensity2 => intensity2;

    protected static readonly int IntensityPropId = Shader.PropertyToID("_Intensity");
    protected static readonly int Intensity2PropId = Shader.PropertyToID("_Intensity2");

    protected virtual void Awake()
    {
        ResolveReferences();
        EnsureOverlaySphere();
        InitializeDefect();
    }

    protected virtual void ResolveReferences()
    {
        if (passthroughLayer == null)
        {
            passthroughLayer = FindAnyObjectByType<OVRPassthroughLayer>();
        }

        if (globalVolume == null)
        {
            globalVolume = FindAnyObjectByType<Volume>();
        }
    }

    /// <summary>
    /// Tworzy lub konfiguruje odwróconą Sferę (renderowaną od wewnątrz dzięki Cull Front w shaderze)
    /// otaczającą głowę użytkownika w pełnych 360 stopniach bez widocznych krawędzi.
    /// </summary>
    protected virtual void EnsureOverlaySphere()
    {
        if (defectShader == null && !string.IsNullOrEmpty(DefaultShaderName))
        {
            defectShader = Shader.Find(DefaultShaderName);
        }

        if (customMaterialTemplate == null && defectShader == null && overlaySphereRenderer == null)
        {
            return;
        }

        Transform legacyQuad = transform.Find("OverlayQuad");
        if (legacyQuad != null)
        {
            if (Application.isPlaying) Destroy(legacyQuad.gameObject);
            else DestroyImmediate(legacyQuad.gameObject);
        }

        if (overlaySphereRenderer == null)
        {
            Transform existingSphere = transform.Find("OverlaySphere");
            if (existingSphere != null)
            {
                overlaySphereRenderer = existingSphere.GetComponent<MeshRenderer>();
            }
        }

        if (overlaySphereRenderer == null)
        {
            GameObject sphereObj = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            sphereObj.name = "OverlaySphere";
            sphereObj.transform.SetParent(transform, false);

            Collider col = sphereObj.GetComponent<Collider>();
            if (col != null)
            {
                if (Application.isPlaying) Destroy(col);
                else DestroyImmediate(col);
            }

            overlaySphereRenderer = sphereObj.GetComponent<MeshRenderer>();
        }

        float safeDiameter = sphereDiameter > 0.25f ? sphereDiameter : 1.0f;
        overlaySphereRenderer.transform.localPosition = Vector3.zero;
        overlaySphereRenderer.transform.localRotation = Quaternion.identity;
        overlaySphereRenderer.transform.localScale = new Vector3(safeDiameter, safeDiameter, safeDiameter);
        overlaySphereRenderer.shadowCastingMode = ShadowCastingMode.Off;
        overlaySphereRenderer.receiveShadows = false;
        overlaySphereRenderer.lightProbeUsage = LightProbeUsage.Off;
        overlaySphereRenderer.reflectionProbeUsage = ReflectionProbeUsage.Off;

        if (customMaterialTemplate != null)
        {
            RuntimeMaterial = new Material(customMaterialTemplate);
        }
        else if (defectShader != null)
        {
            RuntimeMaterial = new Material(defectShader);
        }
        else if (overlaySphereRenderer.sharedMaterial != null)
        {
            RuntimeMaterial = new Material(overlaySphereRenderer.sharedMaterial);
        }

        if (RuntimeMaterial != null)
        {
            overlaySphereRenderer.sharedMaterial = RuntimeMaterial;
        }
    }

    public virtual void EnableDefect()
    {
        ResolveReferences();
        IsActive = true;
        gameObject.SetActive(true);

        if (overlaySphereRenderer != null)
        {
            if (RuntimeMaterial == null)
            {
                EnsureOverlaySphere();
            }
            overlaySphereRenderer.enabled = true;
        }

        OnDefectEnabled();
        SetIntensities(intensity, intensity2);
    }

    public virtual void DisableDefect()
    {
        bool wasActive = IsActive;
        IsActive = false;

        if (overlaySphereRenderer != null)
        {
            overlaySphereRenderer.enabled = false;
        }

        if (wasActive)
        {
            ResetSharedSystems();
            OnDefectDisabled();
        }

        gameObject.SetActive(false);
    }

    public virtual void SetIntensity(float newIntensity)
    {
        intensity = Mathf.Clamp01(newIntensity);
        if (!IsActive) return;

        UpdateShaderIntensityProperties();
        ApplyDefect(intensity, intensity2);
    }

    public virtual void SetIntensity2(float newIntensity2)
    {
        intensity2 = Mathf.Clamp01(newIntensity2);
        if (!IsActive) return;

        UpdateShaderIntensityProperties();
        ApplyDefect(intensity, intensity2);
    }

    public virtual void SetIntensities(float newIntensity, float newIntensity2)
    {
        intensity = Mathf.Clamp01(newIntensity);
        intensity2 = Mathf.Clamp01(newIntensity2);
        if (!IsActive) return;

        UpdateShaderIntensityProperties();
        ApplyDefect(intensity, intensity2);
    }

    protected virtual void UpdateShaderIntensityProperties()
    {
        if (RuntimeMaterial != null)
        {
            if (RuntimeMaterial.HasProperty(IntensityPropId))
            {
                RuntimeMaterial.SetFloat(IntensityPropId, intensity);
            }
            if (RuntimeMaterial.HasProperty(Intensity2PropId))
            {
                RuntimeMaterial.SetFloat(Intensity2PropId, intensity2);
            }
        }
    }

    /// <summary>
    /// Przywraca domyślny stan współdzielonego OVRPassthroughLayer, aby wyłączona wada nie zostawiała zmian.
    /// </summary>
    protected virtual void ResetSharedSystems()
    {
        if (passthroughLayer != null)
        {
            passthroughLayer.DisableColorMap();
            passthroughLayer.edgeRenderingEnabled = false;
            passthroughLayer.textureOpacity = 1.0f;
        }
    }

    protected virtual void InitializeDefect() { }
    protected virtual void OnDefectEnabled() { }
    protected virtual void OnDefectDisabled() { }

    /// <summary>
    /// Domyślne wywołanie dla klas pochodnych implementujących tylko jedno intensity.
    /// </summary>
    protected virtual void ApplyDefect(float currentIntensity) { }

    /// <summary>
    /// Główna metoda aktualizująca parametry wady na podstawie obu suwaków:
    /// - currentIntensity (0..1)
    /// - currentIntensity2 (0..1)
    /// Domyślnie deleguje do jednoparametrowego ApplyDefect(currentIntensity).
    /// </summary>
    protected virtual void ApplyDefect(float currentIntensity, float currentIntensity2)
    {
        ApplyDefect(currentIntensity);
    }

    protected virtual void OnValidate()
    {
        if (Application.isPlaying && IsActive)
        {
            SetIntensities(intensity, intensity2);
        }
    }

    protected virtual void OnDestroy()
    {
        if (RuntimeMaterial != null)
        {
            if (Application.isPlaying) Destroy(RuntimeMaterial);
            else DestroyImmediate(RuntimeMaterial);
        }
    }
}
