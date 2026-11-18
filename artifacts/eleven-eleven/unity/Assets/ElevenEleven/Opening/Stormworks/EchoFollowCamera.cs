using UnityEngine;

namespace ElevenEleven.Opening
{
    internal sealed class EchoFollowCamera
    {
        private Vector3 smoothedLookAhead;
        private float distance = 3.6f;
        private float lens = 60f;
        private float bank;
        private float landing;
        private float landingVelocity;

        internal void Reset()
        {
            smoothedLookAhead = Vector3.zero;
            distance = 3.6f;
            lens = 60f;
            bank = landing = landingVelocity = 0f;
        }

        internal void Land(float impact) => landingVelocity = -Mathf.Min(2.3f, impact * 0.14f);

        internal void Draw(Camera camera, Vector3 feet, Vector3 velocity, float pitch, float yaw,
            float lookInput, LayerMask obstacles, StormworksRoute route, float dt)
        {
            var reduced = ChapterSceneLink.ReducedMotion;
            var factor = 1f - Mathf.Exp(-8f * dt);
            smoothedLookAhead = reduced ? Vector3.zero :
                Vector3.Lerp(smoothedLookAhead, Vector3.ClampMagnitude(velocity * 0.16f, 0.55f), factor);
            bank = reduced ? 0f : Mathf.Lerp(bank, Mathf.Clamp(-lookInput * 0.33f, -2f, 2f), factor);
            landing = reduced ? 0f : Mathf.SmoothDamp(landing, 0f, ref landingVelocity, 0.19f, 10f, dt);
            lens = reduced ? 60f : Mathf.Lerp(lens, 60f + Mathf.InverseLerp(1.5f, 3.45f, velocity.magnitude) * 7f, factor);

            var anchor = feet + Vector3.up * 1.4f;
            var target = anchor + Vector3.up * landing + smoothedLookAhead;
            var rotation = Quaternion.Euler(pitch, yaw, bank);
            var back = rotation * Vector3.back;
            var weight = reduced ? 0f : route.RevealWeight;
            var destination = target + back * 3.6f;
            if (weight > 0f)
            {
                destination = Vector3.Lerp(destination, route.Vista.position, weight);
                target = Vector3.Lerp(target, route.VistaFocus.position, weight);
                rotation = Quaternion.LookRotation(target - destination);
            }

            var arm = destination - anchor;
            var requested = arm.magnitude;
            if (requested > 0.001f)
            {
                var dir = arm / requested;
                var allowed = requested;
                if (Physics.SphereCast(anchor, 0.19f, dir, out var hit, requested, obstacles, QueryTriggerInteraction.Ignore))
                    allowed = Mathf.Max(0.12f, hit.distance - 0.08f);
                distance = allowed < distance || reduced || weight > 0f ? allowed : Mathf.Lerp(distance, allowed, factor);
                destination = anchor + dir * distance;
            }

            camera.fieldOfView = Mathf.Lerp(lens, 53f, weight);
            camera.transform.SetPositionAndRotation(destination, rotation);
        }
    }
}

