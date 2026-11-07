using UnityEngine;

public class HandMenuController : MonoBehaviour
{
    [Tooltip("Obiekt UI (dziecko nadgarstka), który ma się włączać i wyłączać")]
    [SerializeField] private GameObject menuUI;
    [Tooltip("Kamera gracza (CenterEyeAnchor). Jeśli puste, pobierze Camera.main")]
    [SerializeField] private Transform headCamera;
    [Tooltip("Która lokalna oś nadgarstka wychodzi z wnętrza dłoni? (Dla LeftHandAnchor zazwyczaj (0, -1, 0))")]
    [SerializeField] private Vector3 localPalmAxis = Vector3.down;
    [Tooltip("Czułość kąta (1 = idealnie na wprost twarzy, 0.7 = ok. 45 stopni)")]
    [SerializeField, Range(0.3f, 0.95f)] private float threshold = 0.7f;
    private float lastLookTimestamp = 0f;
    private bool lastUIState = false;
    private void Start()
    {
        if (headCamera == null && Camera.main != null)
            headCamera = Camera.main.transform;
            menuUI.SetActive(false);
    }
    private void Update()
    {
        if (menuUI == null || headCamera == null) return;
        Vector3 palmNormal = transform.TransformDirection(localPalmAxis);
        Vector3 toHead = (headCamera.position - transform.position).normalized;
        bool isLookingAtPalm = Vector3.Dot(palmNormal, toHead) >= threshold;
        if(isLookingAtPalm) lastLookTimestamp = Time.time;
        bool shouldShowUI = (Time.time - lastLookTimestamp) < 0.5f;
        if(shouldShowUI != lastUIState)
        {
            menuUI.SetActive(shouldShowUI);
            lastUIState = shouldShowUI;
        }
    }
}
