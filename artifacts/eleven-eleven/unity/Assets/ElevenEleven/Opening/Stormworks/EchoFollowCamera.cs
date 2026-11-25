using UnityEngine;

namespace ElevenEleven.Opening
{
    internal sealed class EchoFollowCamera
    {
        private const float AnchorHeight = 1.4f;
        private Vector3 smoothedLookAhead;
        private ChapterCameraFraming.Frame current = ChapterCameraFraming.Frame.Default;
        private Camera owner;
        private ChapterCameraFraming roomFraming;
        private bool framingReady;
        private float distance = 3.6f;
        private float bank;
        private float landing;
        private float landingVelocity;

        internal void Reset()
        {
            smoothedLookAhead = Vector3.zero;
            current = ChapterCameraFraming.Frame.Default;
            framingReady = false;
            distance = 3.6f;
            bank = landing = landingVelocity = 0f;
        }

        internal void Land(float impact) => landingVelocity = -Mathf.Min(2.3f, impact * 0.14f);

        internal void Draw(Camera camera, Vector3 feet, Vector3 velocity, float pitch, float yaw,
            float lookInput, LayerMask obstacles, StormworksRoute route, float dt)
        {
            if (owner != camera)
            {
                owner = camera;
                roomFraming = camera.GetComponent<ChapterCameraFraming>();
                Reset();
            }

            var reduced = ChapterSceneLink.ReducedMotion;
            var factor = 1f - Mathf.Exp(-8f * dt);
            var tuned = ChapterCameraFraming.Frame.Default;
            if (reduced)
            {
                tuned = ChapterCameraFraming.Frame.Reduced;
                smoothedLookAhead = Vector3.zero;
                bank = landing = landingVelocity = 0f;
            }
            else
            {
                if (roomFraming && roomFraming.isActiveAndEnabled) tuned = roomFraming.Sample(feet);
                var planarVelocity = Vector3.ProjectOnPlane(velocity, Vector3.up);
                smoothedLookAhead = Vector3.Lerp(smoothedLookAhead,
                    Vector3.ClampMagnitude(planarVelocity * .14f, .44f), factor);
                bank = Mathf.Lerp(bank, Mathf.Clamp(-lookInput * .18f, -.9f, .9f), factor);
                if (dt > 0f)
                    landing = Mathf.SmoothDamp(landing, 0f, ref landingVelocity, .19f, 10f, dt);
                var speed = Mathf.InverseLerp(1.65f, 3.45f, planarVelocity.magnitude);
                tuned = tuned.WithMovementLens(speed);
            }

            var firstFrame = !framingReady;
            var frameBlend = reduced || firstFrame ? 1f : 1f - Mathf.Exp(-4.5f * dt);
            current = ChapterCameraFraming.Frame.Blend(current, tuned, frameBlend);
            framingReady = true;

            var anchor = feet + Vector3.up * AnchorHeight;
            var orbit = Quaternion.Euler(pitch, yaw, 0f);
            var shoulder = orbit * Vector3.right * current.Shoulder;
            var target = anchor + Vector3.up * (current.Height + landing) + smoothedLookAhead + shoulder * .38f;
            var destination = target + orbit * Vector3.back * current.Arm + shoulder * .62f;
            var weight = reduced || route == null || route.Vista == null || route.VistaFocus == null
                ? 0f : route.RevealWeight;
            if (weight > 0f)
            {
                destination = Vector3.Lerp(destination, route.Vista.position, weight);
                target = Vector3.Lerp(target, route.VistaFocus.position, weight);
            }

            var fov = Mathf.Lerp(current.Fov, 53f, weight);
            var arm = destination - anchor;
            var requested = arm.magnitude;
            var clearance = 1f;
            var aim = target - destination;
            if (requested > .001f)
            {
                var direction = arm / requested;
                var allowed = roomFraming && roomFraming.isActiveAndEnabled
                    ? roomFraming.LimitApproachArm(feet, direction, requested) : requested;
                if (Physics.SphereCast(anchor, ClearanceRadius(camera, fov), direction, out var hit, allowed,
                    obstacles, QueryTriggerInteraction.Ignore))
                    allowed = Mathf.Max(0f, hit.distance - .08f);

                // Contract on this frame, expand gradually after the obstruction leaves the view.
                distance = firstFrame || reduced || weight > 0f || allowed < distance
                    ? allowed : Mathf.Lerp(distance, allowed, factor);
                clearance = Mathf.Clamp01(distance / requested);
                destination = anchor + direction * distance;
                if (weight > 0f) aim = target - destination;
            }

            var rotation = aim.sqrMagnitude > .0001f ? Quaternion.LookRotation(aim, Vector3.up) : orbit;
            rotation *= Quaternion.AngleAxis(bank * clearance * (1f - weight), Vector3.forward);
            camera.fieldOfView = fov;
            camera.transform.SetPositionAndRotation(destination, rotation);
        }

        private static float ClearanceRadius(Camera camera, float fov)
        {
            var near = camera.nearClipPlane;
            var height = near * Mathf.Tan(fov * Mathf.Deg2Rad * .5f);
            var width = height * camera.aspect;
            var nearCornerDistance = Mathf.Sqrt(near * near + width * width + height * height);
            return Mathf.Max(.19f, nearCornerDistance + .025f);
        }
    }
}
