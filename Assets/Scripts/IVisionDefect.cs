using UnityEngine;

public interface IVisionDefect
{
    public string DefectType { get; }
    public bool IsActive { get; }

    public void EnableDefect();
    public void DisableDefect();
    public void SetIntensity(float intensity);
    public void SetIntensity2(float intensity2);
}
