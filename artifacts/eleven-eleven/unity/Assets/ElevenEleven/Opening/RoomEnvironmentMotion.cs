using System;
using UnityEngine;

namespace ElevenEleven.Opening
{
    [DisallowMultipleComponent]
    public sealed class RoomEnvironmentMotion : MonoBehaviour
    {
        public enum Movement { Drift, Hinge, Spin, Slide }

        [Serializable]
        public struct Piece
        {
            public Transform target;
            public Movement movement;
            public Vector3 direction;
            public float rate;
            public float amplitude;
            public float phase;
        }

        [SerializeField] private Transform observer;
        [SerializeField] private float activeRadius = 28f;
        [SerializeField] private Piece[] pieces = Array.Empty<Piece>();
        [SerializeField] private LineRenderer arc;
        [SerializeField] private Vector3 arcEnd;
        [SerializeField] private ParticleSystem atmosphere;
        private Vector3[] positions;
        private Quaternion[] rotations;
        private readonly Vector3[] arcPoints = new Vector3[9];
        private float elapsed;
        private bool parked = true;

        public int PieceCount => pieces.Length;

        private void Awake()
        {
            positions = new Vector3[pieces.Length];
            rotations = new Quaternion[pieces.Length];
            for (var i = 0; i < pieces.Length; i++)
            {
                positions[i] = pieces[i].target.localPosition;
                rotations[i] = pieces[i].target.localRotation;
            }
        }

        private void LateUpdate()
        {
            var nearby = observer && (observer.position - transform.position).sqrMagnitude < activeRadius * activeRadius;
            if (!nearby || ChapterSceneLink.ReducedMotion)
            {
                if (!parked) Park();
                return;
            }

            if (parked && atmosphere) atmosphere.Play();
            parked = false;
            var delta = Time.deltaTime;
            if (delta <= 0f) return;
            elapsed += delta;

            for (var i = 0; i < pieces.Length; i++)
            {
                var piece = pieces[i];
                var phase = elapsed * piece.rate + piece.phase;
                var wave = Mathf.Sin(phase);
                switch (piece.movement)
                {
                    case Movement.Drift:
                        piece.target.localPosition = positions[i] + piece.direction * (piece.amplitude * wave);
                        piece.target.localRotation = rotations[i] * Quaternion.Euler(wave * 14f,
                            Mathf.Sin(phase * .61f) * 29f, Mathf.Sin(phase * 1.23f) * 18f);
                        break;
                    case Movement.Hinge:
                        piece.target.localRotation = rotations[i] * Quaternion.AngleAxis(wave * piece.amplitude, piece.direction);
                        break;
                    case Movement.Spin:
                        piece.target.localRotation = rotations[i] * Quaternion.AngleAxis(
                            Mathf.Repeat(elapsed * piece.rate + piece.phase, 360f), piece.direction);
                        break;
                    case Movement.Slide:
                        piece.target.localPosition = positions[i] + piece.direction * (piece.amplitude * wave);
                        break;
                }
            }

            if (arc) DrawArc();
        }

        private void OnDisable()
        {
            if (!parked) Park();
        }

        private void Park()
        {
            parked = true;
            for (var i = 0; i < pieces.Length; i++)
            {
                if (!pieces[i].target) continue;
                pieces[i].target.SetLocalPositionAndRotation(positions[i], rotations[i]);
            }
            if (arc) arc.enabled = false;
            if (atmosphere) atmosphere.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
        }

        private void DrawArc()
        {
            const float cycle = 4.7f;
            var window = Mathf.Repeat(elapsed, cycle);
            arc.enabled = window < 0.22f;
            if (!arc.enabled) return;

            var tick = Mathf.Floor(elapsed * 18f);
            for (var i = 0; i < arcPoints.Length; i++)
            {
                var fraction = i / (float)(arcPoints.Length - 1);
                var bend = Mathf.Sin(fraction * Mathf.PI) * .14f;
                arcPoints[i] = arcEnd * fraction + bend * new Vector3(
                    Mathf.Sin(i * 13.1f + tick), Mathf.Cos(i * 9.4f + tick), Mathf.Sin(i * 5.8f - tick));
            }
            arc.SetPositions(arcPoints);
        }

#if UNITY_EDITOR
        public void Configure(Transform player, float radius, Piece[] movingPieces, LineRenderer discharge,
            Vector3 dischargeEnd, ParticleSystem air)
        {
            observer = player;
            activeRadius = radius;
            pieces = movingPieces;
            arc = discharge;
            arcEnd = dischargeEnd;
            atmosphere = air;
        }
#endif
    }
}
