using UnityEngine;

namespace ElevenEleven.Opening
{
    [DisallowMultipleComponent]
    public sealed class EchoExperimentInjuries : MonoBehaviour
    {
        [SerializeField] private GameObject[] marks;
        internal void Apply(bool present)
        {
            foreach (var mark in marks) mark.SetActive(present);
        }
    }
}
