using System.Collections.Generic;
using UnityEngine;

public class VisionDefectManager : MonoBehaviour
{
    private readonly Dictionary<string, IVisionDefect> _defects = new();

    public IVisionDefect CurrentDefect { get; private set; } = null;
    public IReadOnlyCollection<string> RegisteredDefectTypes => _defects.Keys;

    [Header("Podgląd / Test w Inspectorze (Play Mode)")]
    [SerializeField] private string initialDefectType = "";
    [SerializeField, Range(0f, 1f)] private float currentIntensity = 1.0f;
    [SerializeField, Range(0f, 1f)] private float currentIntensity2 = 0.5f;

    public float CurrentIntensity => currentIntensity;
    public float CurrentIntensity2 => currentIntensity2;

    private void Awake()
    {
        RefreshDefectsList();
    }

    private void Start()
    {
        if (!string.IsNullOrEmpty(initialDefectType))
        {
            ActivateDefect(initialDefectType, currentIntensity, currentIntensity2);
        }
    }

    public void RefreshDefectsList()
    {
        _defects.Clear();
        var foundDefects = GetComponentsInChildren<IVisionDefect>(true);

        foreach (var defect in foundDefects)
        {
            if (string.IsNullOrEmpty(defect.DefectType)) continue;

            if (!_defects.ContainsKey(defect.DefectType))
            {
                _defects.Add(defect.DefectType, defect);
                defect.DisableDefect();
            }
            else
            {
                Debug.LogWarning($"[VisionDefectManager] Duplikat wady '{defect.DefectType}' w hierarchii!");
            }
        }
    }

    public void ActivateDefect(string type, float initialIntensity = 1.0f, float initialIntensity2 = 0.5f)
    {
        currentIntensity = Mathf.Clamp01(initialIntensity);
        currentIntensity2 = Mathf.Clamp01(initialIntensity2);

        if (CurrentDefect != null && CurrentDefect.DefectType == type)
        {
            CurrentDefect.SetIntensity(currentIntensity);
            CurrentDefect.SetIntensity2(currentIntensity2);
            return;
        }

        DeactivateAll();

        if (!string.IsNullOrEmpty(type) && _defects.TryGetValue(type, out var newDefect))
        {
            newDefect.EnableDefect();
            newDefect.SetIntensity(currentIntensity);
            newDefect.SetIntensity2(currentIntensity2);
            CurrentDefect = newDefect;
            initialDefectType = type;
        }
        else if (!string.IsNullOrEmpty(type))
        {
            Debug.LogWarning($"[VisionDefectManager] Nie znaleziono wady o nazwie '{type}'. Dostępne: {string.Join(", ", _defects.Keys)}");
        }
    }

    /// <summary>
    /// Wygodna metoda typu On/Off pod przyciski UI: jeśli dana wada jest już aktywna, wyłącza ją; w przeciwnym razie włącza.
    /// </summary>
    public void SetEffect(string type)
    {
        ToggleDefect(type, currentIntensity, currentIntensity2);
    }

    public void ToggleDefect(string type, float initialIntensity = 1.0f)
    {
        ToggleDefect(type, initialIntensity, currentIntensity2);
    }

    public void ToggleDefect(string type, float initialIntensity, float initialIntensity2)
    {
        if (CurrentDefect != null && CurrentDefect.DefectType == type && CurrentDefect.IsActive)
        {
            DeactivateAll();
        }
        else
        {
            ActivateDefect(type, initialIntensity, initialIntensity2);
        }
    }

    public void DeactivateAll()
    {
        foreach (var defect in _defects.Values)
        {
            if (defect.IsActive)
            {
                defect.DisableDefect();
            }
        }
        CurrentDefect = null;
    }

    /// <summary>
    /// Suwak 1 w UI (np. widoczność mętów, siła rozmycia, zwężenie pola jaskry, wielkość mroczka AMD, zamglenie zaćmy).
    /// </summary>
    public void UpdateCurrentDefectIntensity(float intensity)
    {
        currentIntensity = Mathf.Clamp01(intensity);
        if (CurrentDefect != null && _defects.TryGetValue(CurrentDefect.DefectType, out var defect))
        {
            defect.SetIntensity(currentIntensity);
        }
    }

    /// <summary>
    /// Suwak 2 w UI (np. liczba/gęstość mętów, odległość ostrości dla wad refrakcji, falowanie boków AMD, miękkość jaskry).
    /// </summary>
    public void UpdateCurrentDefectIntensity2(float intensity2)
    {
        currentIntensity2 = Mathf.Clamp01(intensity2);
        if (CurrentDefect != null && _defects.TryGetValue(CurrentDefect.DefectType, out var defect))
        {
            defect.SetIntensity2(currentIntensity2);
        }
    }

    public void SetIntensities(float intensity, float intensity2)
    {
        currentIntensity = Mathf.Clamp01(intensity);
        currentIntensity2 = Mathf.Clamp01(intensity2);
        if (CurrentDefect != null && _defects.TryGetValue(CurrentDefect.DefectType, out var defect))
        {
            defect.SetIntensity(currentIntensity);
            defect.SetIntensity2(currentIntensity2);
        }
    }

    public bool TryGetDefect(string type, out IVisionDefect defect)
    {
        return _defects.TryGetValue(type, out defect);
    }

    private void OnValidate()
    {
        if (Application.isPlaying && CurrentDefect != null)
        {
            UpdateCurrentDefectIntensity(currentIntensity);
            UpdateCurrentDefectIntensity2(currentIntensity2);
        }
    }
}
