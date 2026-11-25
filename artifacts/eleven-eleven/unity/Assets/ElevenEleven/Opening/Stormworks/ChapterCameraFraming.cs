using System;
using UnityEngine;

namespace ElevenEleven.Opening
{
    [DisallowMultipleComponent]
    public sealed class ChapterCameraFraming : MonoBehaviour
    {
        [Serializable]
        public struct Room
        {
            [SerializeField] private string label;
            [Tooltip("Optional coordinate space for the box. An empty reference uses scene coordinates.")]
            [SerializeField] private Transform reference;
            [SerializeField] private Vector3 center;
            [SerializeField] private Vector3 size;
            [Min(.05f)] [SerializeField] private float blendMargin;
            [Range(45f, 70f)] [SerializeField] private float verticalFov;
            [Range(2.2f, 5.2f)] [SerializeField] private float armLength;
            [Range(-.65f, .65f)] [SerializeField] private float shoulderOffset;
            [Range(-.28f, .38f)] [SerializeField] private float heightOffset;
            [Range(0f, 4f)] [SerializeField] private float movementFov;

            public Room(string label, Transform reference, Vector3 center, Vector3 size, float blendMargin,
                float verticalFov, float armLength, float shoulderOffset, float heightOffset, float movementFov)
            {
                this.label = label;
                this.reference = reference;
                this.center = center;
                this.size = size;
                this.blendMargin = blendMargin;
                this.verticalFov = verticalFov;
                this.armLength = armLength;
                this.shoulderOffset = shoulderOffset;
                this.heightOffset = heightOffset;
                this.movementFov = movementFov;
            }

            internal Frame Composition => new Frame(
                Mathf.Clamp(verticalFov, 45f, 70f), Mathf.Clamp(armLength, 2.2f, 5.2f),
                Mathf.Clamp(shoulderOffset, -.65f, .65f), Mathf.Clamp(heightOffset, -.28f, .38f),
                Mathf.Clamp(movementFov, 0f, 4f));

            internal float Weight(Vector3 worldPoint) => BoxWeight(worldPoint, reference, center, size, blendMargin);
        }

        [Serializable]
        public struct ApproachArm
        {
            [SerializeField] private Transform reference;
            [SerializeField] private Vector3 center;
            [SerializeField] private Vector3 size;
            [Min(.05f)] [SerializeField] private float blendMargin;
            [Min(.25f)] [SerializeField] private float maximumArm;

            public ApproachArm(Transform reference, Vector3 center, Vector3 size, float blendMargin, float maximumArm)
            {
                this.reference = reference;
                this.center = center;
                this.size = size;
                this.blendMargin = blendMargin;
                this.maximumArm = maximumArm;
            }

            internal float Limit(Vector3 feet, Vector3 armDirection, float length)
            {
                var rear = -Vector3.Dot(armDirection, reference ? reference.forward : Vector3.forward);
                var weight = BoxWeight(feet, reference, center, size, blendMargin) * Mathf.InverseLerp(.30f, .78f, rear);
                return Mathf.Lerp(length, Mathf.Min(length, Mathf.Max(.25f, maximumArm)), weight);
            }
        }

        private static float BoxWeight(Vector3 worldPoint, Transform reference, Vector3 center, Vector3 size, float margin)
        {
            if (size.x <= 0f || size.y <= 0f || size.z <= 0f) return 0f;
            var point = (reference ? reference.InverseTransformPoint(worldPoint) : worldPoint) - center;
            var half = size * .5f;
            var outside = new Vector3(
                Mathf.Max(0f, Mathf.Abs(point.x) - half.x),
                Mathf.Max(0f, Mathf.Abs(point.y) - half.y),
                Mathf.Max(0f, Mathf.Abs(point.z) - half.z)).magnitude;
            return 1f - Mathf.SmoothStep(0f, 1f, outside / Mathf.Max(.05f, margin));
        }

        [Tooltip("Volumes blend at their edges. Later entries take precedence where their boxes overlap.")]
        [SerializeField] private Room[] rooms = Array.Empty<Room>();

        [Tooltip("Shorten the rear follow arm where visible architecture needs additional camera clearance.")]
        [SerializeField] private ApproachArm[] approachArms = Array.Empty<ApproachArm>();

        public void Configure(params Room[] layout) => rooms = layout ?? Array.Empty<Room>();

        public void ConfigureApproachArm(params ApproachArm[] limits) => approachArms = limits ?? Array.Empty<ApproachArm>();

        internal float LimitApproachArm(Vector3 feet, Vector3 armDirection, float distance)
        {
            foreach (var limit in approachArms)
                distance = limit.Limit(feet, armDirection, distance);
            return distance;
        }

        internal Frame Sample(Vector3 feet)
        {
            var result = Frame.Default;
            foreach (var room in rooms)
            {
                var weight = room.Weight(feet);
                if (weight > 0f) result = Frame.Blend(result, room.Composition, weight);
            }
            return result;
        }

        internal readonly struct Frame
        {
            internal static readonly Frame Default = new Frame(59f, 3.6f, .14f, 0f, 2.5f);
            internal static readonly Frame Reduced = new Frame(60f, 3.6f, 0f, 0f, 0f);

            internal readonly float Fov;
            internal readonly float Arm;
            internal readonly float Shoulder;
            internal readonly float Height;
            private readonly float movementFov;

            internal Frame(float fov, float arm, float shoulder, float height, float movementFov)
            {
                Fov = fov;
                Arm = arm;
                Shoulder = shoulder;
                Height = height;
                this.movementFov = movementFov;
            }

            internal Frame WithMovementLens(float speed) =>
                new Frame(Fov + movementFov * speed, Arm, Shoulder, Height, movementFov);

            internal static Frame Blend(Frame from, Frame to, float weight) => new Frame(
                Mathf.Lerp(from.Fov, to.Fov, weight),
                Mathf.Lerp(from.Arm, to.Arm, weight),
                Mathf.Lerp(from.Shoulder, to.Shoulder, weight),
                Mathf.Lerp(from.Height, to.Height, weight),
                Mathf.Lerp(from.movementFov, to.movementFov, weight));
        }
    }
}
