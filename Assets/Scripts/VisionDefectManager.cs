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

    private void Awake()
    {
        RefreshDefectsList();
    }

    private void Start()
    {
        if (!string.IsNullOrEmpty(initialDefectType))
        {
            ActivateDefect(initialDefectType, currentIntensity);
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

    public void ActivateDefect(string type, float initialIntensity = 1.0f)
    {
        currentIntensity = Mathf.Clamp01(initialIntensity);

        if (CurrentDefect != null && CurrentDefect.DefectType == type)
        {
            CurrentDefect.SetIntensity(currentIntensity);
            return;
        }

        DeactivateAll();

        if (!string.IsNullOrEmpty(type) && _defects.TryGetValue(type, out var newDefect))
        {
            newDefect.EnableDefect();
            newDefect.SetIntensity(currentIntensity);
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
    public void ToggleDefect(string type, float initialIntensity = 1.0f)
    {
        if (CurrentDefect != null && CurrentDefect.DefectType == type && CurrentDefect.IsActive)
        {
            DeactivateAll();
        }
        else
        {
            ActivateDefect(type, initialIntensity);
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

    public void UpdateCurrentDefectIntensity(float intensity)
    {
        currentIntensity = Mathf.Clamp01(intensity);
        if (CurrentDefect != null && _defects.TryGetValue(CurrentDefect.DefectType, out var defect))
        {
            defect.SetIntensity(currentIntensity);
        }
    }

    public bool TryGetDefect(string type, out IVisionDefect defect)
    {
        return _defects.TryGetValue(type, out defect);
    }

    private void OnValidate()
    {
        if (!Application.isPlaying || _defects.Count == 0) return;

        if (string.IsNullOrEmpty(initialDefectType))
        {
            if (CurrentDefect != null) DeactivateAll();
        }
        else if (CurrentDefect == null || CurrentDefect.DefectType != initialDefectType)
        {
            ActivateDefect(initialDefectType, currentIntensity);
        }
        else
        {
            UpdateCurrentDefectIntensity(currentIntensity);
        }
    }
}
