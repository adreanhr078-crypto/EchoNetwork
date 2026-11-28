using UnityEngine;

namespace ElevenEleven.Opening
{
    public sealed class WardGauzeCloth : MonoBehaviour
    {
        public const int Columns = 25;
        public const int Rows = 19;
        private const float Step = 1f / 120f;
        private const float DistanceLimit = .00075f;

        private struct Constraint
        {
            internal int A, B;
            internal float Rest, Compliance, Lambda;
        }

        [SerializeField, HideInInspector] private Vector3[] rest;
        private MeshFilter filter;
        private Mesh mesh;
        private Vector3[] position;
        private Vector3[] previous;
        private float[] inverseMass;
        private Constraint[] constraints;
        private Vector3 lastOrigin;
        private Vector3 lastVelocity;
        private float carry;
        private float breathPhase;
        private bool ready;

        private void OnEnable()
        {
            filter = GetComponent<MeshFilter>();
            if (!filter || !filter.sharedMesh) return;
            if (!mesh)
            {
                mesh = Instantiate(filter.sharedMesh);
                mesh.name = filter.sharedMesh.name + " cloth";
                filter.sharedMesh = mesh;
            }
            if (rest == null || rest.Length != mesh.vertexCount) rest = mesh.vertices;
            Setup();
            lastOrigin = transform.position;
            lastVelocity = Vector3.zero;
            carry = 0f;
            breathPhase = 0f;
        }

        private void LateUpdate()
        {
            if (!ready) return;
            if (ChapterSceneLink.ReducedMotion)
            {
                if (!AtRest())
                {
                    System.Array.Copy(rest, position, rest.Length);
                    System.Array.Copy(rest, previous, rest.Length);
                    Draw();
                }
                lastOrigin = transform.position;
                lastVelocity = Vector3.zero;
                return;
            }

            var dt = Time.deltaTime;
            if (dt <= 1e-6f) return;
            var velocity = (transform.position - lastOrigin) / dt;
            var acceleration = Vector3.ClampMagnitude(transform.InverseTransformDirection((velocity - lastVelocity) / dt), 7.5f);
            lastOrigin = transform.position;
            lastVelocity = velocity;

            carry = Mathf.Min(carry + dt, Step * 4f);
            while (carry >= Step)
            {
                breathPhase += Step * 2.15f;
                Simulate(acceleration);
                carry -= Step;
            }
            Draw();
        }

        private void Setup()
        {
            var count = rest.Length;
            position = (Vector3[])rest.Clone();
            previous = (Vector3[])rest.Clone();
            inverseMass = new float[count];
            for (var i = 0; i < count; i++)
            {
                if (Fixed(i))
                {
                    inverseMass[i] = 0f;
                    continue;
                }
                var col = i % Columns;
                var row = i / Columns;
                var centerU = 1f - Mathf.Abs((col / (float)(Columns - 1)) * 2f - 1f);
                var centerV = 1f - Mathf.Abs((row / (float)(Rows - 1)) * 2f - 1f);
                // Corners taped softly; middle & lower medical pad flex organically
                var mobility = Mathf.Lerp(0.45f, 1.35f, centerU * (0.4f + 0.6f * centerV));
                inverseMass[i] = mobility;
            }

            var list = new System.Collections.Generic.List<Constraint>(count * 5);
            void Link(int a, int b, float compliance)
            {
                list.Add(new Constraint
                {
                    A = a, B = b,
                    Rest = Vector3.Distance(rest[a], rest[b]),
                    Compliance = compliance,
                });
            }

            for (var r = 0; r < Rows; r++)
            {
                for (var c = 0; c < Columns; c++)
                {
                    var i = r * Columns + c;
                    if (c + 1 < Columns) Link(i, i + 1, .00008f);
                    if (r + 1 < Rows) Link(i, i + Columns, .00008f);
                    if (c + 1 < Columns && r + 1 < Rows)
                    {
                        Link(i, i + Columns + 1, .00028f);
                        Link(i + 1, i + Columns, .00028f);
                    }
                    if (c + 2 < Columns) Link(i, i + 2, .00065f);
                    if (r + 2 < Rows) Link(i, i + Columns * 2, .00065f);
                }
            }
            constraints = list.ToArray();
            ready = count == Columns * Rows;
        }

        private void Simulate(Vector3 inertia)
        {
            if (!ready) Setup();
            var dt2 = Step * Step;
            var pulseForce = new Vector3(0f, Mathf.Sin(breathPhase) * .020f, Mathf.Cos(breathPhase * 1.4f) * .055f);
            for (var i = 0; i < position.Length; i++)
            {
                if (inverseMass[i] <= 0f) continue;
                var row = i / Columns;
                var col = i % Columns;
                var u = (col / (float)(Columns - 1)) * 2f - 1f;
                var vCoord = (row / (float)(Rows - 1)) * 2f - 1f;
                var radial = Mathf.Clamp01(1f - (u * u + vCoord * vCoord));
                var flutterScale = radial * radial;
                var v = (position[i] - previous[i]) * .94f;
                previous[i] = position[i];
                var restore = (rest[i] - position[i]) * (row == Rows - 1 ? 58f : 38f);
                var force = restore - inertia * (.040f * flutterScale) + pulseForce * flutterScale;
                position[i] += v + force * (inverseMass[i] * dt2);
            }

            for (var i = 0; i < constraints.Length; i++) constraints[i].Lambda = 0f;
            for (var iter = 0; iter < 5; iter++)
                for (var i = 0; i < constraints.Length; i++)
                    Solve(ref constraints[i]);

            for (var i = 0; i < position.Length; i++)
            {
                if (inverseMass[i] <= 0f)
                {
                    position[i] = rest[i];
                    continue;
                }
                var delta = position[i] - rest[i];
                // Never sink backward through eyelid mesh
                if (delta.z < -0.00025f) delta.z = -0.00025f;
                if (delta.sqrMagnitude > DistanceLimit * DistanceLimit)
                    position[i] = rest[i] + delta.normalized * DistanceLimit;
                else
                    position[i] = rest[i] + delta;
            }
        }

        private void Solve(ref Constraint constraint)
        {
            var wA = inverseMass[constraint.A];
            var wB = inverseMass[constraint.B];
            var wSum = wA + wB;
            if (wSum <= 0f) return;

            var delta = position[constraint.A] - position[constraint.B];
            var len = delta.magnitude;
            if (len <= 1e-6f) return;

            var alpha = constraint.Compliance / (Step * Step);
            var err = len - constraint.Rest;
            var dLambda = -(err + alpha * constraint.Lambda) / (wSum + alpha);
            constraint.Lambda += dLambda;
            var corr = delta * (dLambda / len);
            if (wA > 0f) position[constraint.A] += corr * wA;
            if (wB > 0f) position[constraint.B] -= corr * wB;
        }

        private bool AtRest()
        {
            for (var i = 0; i < position.Length; i++)
                if ((position[i] - rest[i]).sqrMagnitude > 1e-12f) return false;
            return true;
        }

        private static bool Fixed(int i)
        {
            var col = i % Columns;
            var row = i / Columns;
            return col <= 1 || col >= Columns - 2 || row <= 1 || row >= Rows - 2;
        }

        private void Draw()
        {
            mesh.vertices = position;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
        }

        private void OnDisable()
        {
            if (!ready) return;
            System.Array.Copy(rest, position, rest.Length);
            System.Array.Copy(rest, previous, rest.Length);
            Draw();
        }
    }
}
