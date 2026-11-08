using UnityEngine;

public class BoxController : MonoBehaviour
{
    private void OnTriggerEnter(Collider other)
    {
        if(other.TryGetComponent(out Rigidbody rb) && rb.isKinematic == false)
        {
            Destroy(rb.gameObject);
        }
    }
}
