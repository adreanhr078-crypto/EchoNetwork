using UnityEngine;

namespace EchoNetwork.UnityG0
{
    /// <summary>Bounded third-person movement proof; it does not own progression or rewards.</summary>
    [RequireComponent(typeof(CharacterController))]
    public sealed class ThirdPersonController : MonoBehaviour
    {
        [SerializeField] private float walkSpeed = 2.6f;
        [SerializeField] private float rotationSpeed = 12f;
        [SerializeField] private float gravity = -18f;
        [SerializeField] private float interactionRadius = 2.2f;
        [SerializeField] private Transform cameraTarget;

        private CharacterController controller;
        private Camera followCamera;
        private float verticalVelocity;

        private void Awake()
        {
            controller = GetComponent<CharacterController>();
            followCamera = Camera.main;
            if (cameraTarget == null)
                cameraTarget = transform;
        }

        private void Update()
        {
            if (controller == null)
                return;

            var input = new Vector2(
                (Input.GetKey(KeyCode.D) ? 1f : 0f) - (Input.GetKey(KeyCode.A) ? 1f : 0f),
                (Input.GetKey(KeyCode.W) ? 1f : 0f) - (Input.GetKey(KeyCode.S) ? 1f : 0f));
            input = Vector2.ClampMagnitude(input, 1f);

            var forward = followCamera != null ? followCamera.transform.forward : Vector3.forward;
            forward.y = 0f;
            forward.Normalize();
            var right = new Vector3(forward.z, 0f, -forward.x);
            var direction = (forward * input.y) + (right * input.x);

            if (direction.sqrMagnitude > 0.001f)
            {
                var targetRotation = Quaternion.LookRotation(direction, Vector3.up);
                transform.rotation = Quaternion.Slerp(
                    transform.rotation,
                    targetRotation,
                    rotationSpeed * Time.deltaTime);
            }

            if (controller.isGrounded && verticalVelocity < 0f)
                verticalVelocity = -2f;
            verticalVelocity += gravity * Time.deltaTime;
            controller.Move((direction * walkSpeed + Vector3.up * verticalVelocity) * Time.deltaTime);

            if (Input.GetKeyDown(KeyCode.E))
                InteractWithNearest();

            UpdateFollowCamera();
        }

        private void InteractWithNearest()
        {
            var hits = Physics.OverlapSphere(transform.position, interactionRadius);
            G0Interactable closest = null;
            var closestDistance = float.MaxValue;
            foreach (var hit in hits)
            {
                var candidate = hit.GetComponentInParent<G0Interactable>();
                if (candidate == null)
                    continue;
                var distance = (candidate.transform.position - transform.position).sqrMagnitude;
                if (distance < closestDistance)
                {
                    closest = candidate;
                    closestDistance = distance;
                }
            }

            closest?.Interact();
        }

        private void UpdateFollowCamera()
        {
            if (followCamera == null)
                return;

            var desired = cameraTarget.position + new Vector3(0.55f, 1.55f, 2.5f);
            followCamera.transform.position = Vector3.Lerp(
                followCamera.transform.position,
                desired,
                8f * Time.deltaTime);
            var lookPoint = cameraTarget.position + Vector3.up * 1.35f;
            followCamera.transform.rotation = Quaternion.Slerp(
                followCamera.transform.rotation,
                Quaternion.LookRotation(lookPoint - followCamera.transform.position, Vector3.up),
                10f * Time.deltaTime);
        }

        private void OnDrawGizmosSelected()
        {
            Gizmos.color = new Color(0.15f, 0.85f, 1f, 0.35f);
            Gizmos.DrawWireSphere(transform.position, interactionRadius);
        }
    }
}
