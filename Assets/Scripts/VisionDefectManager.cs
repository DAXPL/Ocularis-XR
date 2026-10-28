using System.Collections.Generic;
using UnityEngine;

public class VisionDefectManager : MonoBehaviour
{
    private Dictionary<string, IVisionDefect> _defects = new();
    public IVisionDefect CurrentDefect { get; private set; } = null;

    private void Awake()
    {
        var foundDefects = GetComponentsInChildren<IVisionDefect>(true);

        foreach (var defect in foundDefects)
        {
            if (!_defects.ContainsKey(defect.DefectType))
            {
                _defects.Add(defect.DefectType, defect);
                defect.DisableDefect();
            }
            else
            {
                Debug.LogWarning($"Duplikat wady {defect.DefectType} w hierarchii!");
            }
        }
    }
    
    public void ActivateDefect(string type, float initialIntensity = 1.0f)
    {
        if (CurrentDefect?.DefectType == type) return;

        DeactivateAll();

        if (type != string.Empty && _defects.TryGetValue(type, out var newDefect))
        {
            newDefect.EnableDefect();
            newDefect.SetIntensity(initialIntensity);
            CurrentDefect = newDefect;
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
        if (CurrentDefect != null && _defects.TryGetValue(CurrentDefect.DefectType, out var defect))
        {
            defect.SetIntensity(Mathf.Clamp01(intensity));
        }
    }
}
