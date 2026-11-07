using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// Klasa bazowa dla pojedynczej wady wzroku działającej w architekturze "On/Off" (osobny GameObject na wadę).
/// Umieść obiekt z klasą pochodną jako dziecko CenterEyeAnchor (wewnątrz hierarchii VisionDefectManager).
/// </summary>
public abstract class VisionDefectBase : MonoBehaviour, IVisionDefect
{
    [Header("Identyfikacja i intensywność")]
    [SerializeField] protected string defectType = "Defect";
    [SerializeField, Range(0f, 1f)] protected float intensity = 1.0f;

    [Header("Referencje wspólne (automatycznie wykrywane jeśli puste)")]
    [SerializeField] protected OVRPassthroughLayer passthroughLayer;
    [SerializeField] protected Volume globalVolume;
    [SerializeField] protected MeshRenderer overlayQuadRenderer;

    [Header("Konfiguracja Quada nakładki (przed kamerą)")]
    [SerializeField] protected Shader defectShader;
    [SerializeField] protected Material customMaterialTemplate;
    [SerializeField] protected float quadDistance = 0.12f;
    [SerializeField] protected float quadSize = 0.65f;

    protected Material RuntimeMaterial { get; private set; }
    protected VolumeProfile RuntimeVolumeProfile => globalVolume != null ? globalVolume.profile : null;
    protected virtual string DefaultShaderName => null;
    protected virtual string DefaultDefectType => "Defect";

    public string DefectType => (string.IsNullOrEmpty(defectType) || defectType == "Defect") ? DefaultDefectType : defectType;
    public bool IsActive { get; private set; }

    protected static readonly int IntensityPropId = Shader.PropertyToID("_Intensity");

    protected virtual void Awake()
    {
        ResolveReferences();
        EnsureOverlayQuad();
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
    /// Tworzy lub konfiguruje lekki Quad przed kamerą dla danej wady, jeśli wada korzysta z shadera/materiału.
    /// </summary>
    protected virtual void EnsureOverlayQuad()
    {
        if (defectShader == null && !string.IsNullOrEmpty(DefaultShaderName))
        {
            defectShader = Shader.Find(DefaultShaderName);
        }

        if (customMaterialTemplate == null && defectShader == null && overlayQuadRenderer == null)
        {
            return;
        }

        if (overlayQuadRenderer == null)
        {
            Transform existingQuad = transform.Find("OverlayQuad");
            if (existingQuad != null)
            {
                overlayQuadRenderer = existingQuad.GetComponent<MeshRenderer>();
            }
        }

        if (overlayQuadRenderer == null)
        {
            GameObject quadObj = GameObject.CreatePrimitive(PrimitiveType.Quad);
            quadObj.name = "OverlayQuad";
            quadObj.transform.SetParent(transform, false);

            Collider col = quadObj.GetComponent<Collider>();
            if (col != null)
            {
                if (Application.isPlaying) Destroy(col);
                else DestroyImmediate(col);
            }

            overlayQuadRenderer = quadObj.GetComponent<MeshRenderer>();
        }

        overlayQuadRenderer.transform.localPosition = new Vector3(0f, 0f, quadDistance);
        overlayQuadRenderer.transform.localRotation = Quaternion.identity;
        overlayQuadRenderer.transform.localScale = new Vector3(quadSize, quadSize, 1f);
        overlayQuadRenderer.shadowCastingMode = ShadowCastingMode.Off;
        overlayQuadRenderer.receiveShadows = false;
        overlayQuadRenderer.lightProbeUsage = LightProbeUsage.Off;
        overlayQuadRenderer.reflectionProbeUsage = ReflectionProbeUsage.Off;

        if (customMaterialTemplate != null)
        {
            RuntimeMaterial = new Material(customMaterialTemplate);
        }
        else if (defectShader != null)
        {
            RuntimeMaterial = new Material(defectShader);
        }
        else if (overlayQuadRenderer.sharedMaterial != null)
        {
            RuntimeMaterial = new Material(overlayQuadRenderer.sharedMaterial);
        }

        if (RuntimeMaterial != null)
        {
            overlayQuadRenderer.sharedMaterial = RuntimeMaterial;
        }
    }

    public virtual void EnableDefect()
    {
        ResolveReferences();
        IsActive = true;
        gameObject.SetActive(true);

        if (overlayQuadRenderer != null)
        {
            if (RuntimeMaterial == null)
            {
                EnsureOverlayQuad();
            }
            overlayQuadRenderer.enabled = true;
        }

        OnDefectEnabled();
        SetIntensity(intensity);
    }

    public virtual void DisableDefect()
    {
        bool wasActive = IsActive;
        IsActive = false;

        if (overlayQuadRenderer != null)
        {
            overlayQuadRenderer.enabled = false;
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

        if (RuntimeMaterial != null && RuntimeMaterial.HasProperty(IntensityPropId))
        {
            RuntimeMaterial.SetFloat(IntensityPropId, intensity);
        }

        ApplyDefect(intensity);
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

    /// <summary>
    /// Wywoływane raz w Awake po przygotowaniu referencji i Quada.
    /// </summary>
    protected virtual void InitializeDefect() { }

    /// <summary>
    /// Wywoływane przy włączeniu wady (EnableDefect).
    /// </summary>
    protected virtual void OnDefectEnabled() { }

    /// <summary>
    /// Wywoływane przy wyłączeniu wady (DisableDefect) w celu wyczyszczenia np. efektów Volume.
    /// </summary>
    protected virtual void OnDefectDisabled() { }

    /// <summary>
    /// Główna metoda aktualizująca parametry shadera, Passthrough i Volume na podstawie suwaka (0..1).
    /// </summary>
    protected abstract void ApplyDefect(float currentIntensity);

    protected virtual void OnValidate()
    {
        if (Application.isPlaying && IsActive)
        {
            SetIntensity(intensity);
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
