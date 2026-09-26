using System;
using System.Collections.Generic;
using FlaxEngine;

namespace EchoNetwork.World
{
    /// <summary>
    /// Master Open-World Streaming Manager for Echo Network in Flax Engine.
    /// Evaluates player traversal coordinates across Japanese city districts,
    /// triggers non-blocking asynchronous scene loads, and manages memory budgets.
    /// </summary>
    public class WorldStreamingManager : Script
    {
        [Header("Target & Tuning")]
        public Actor PlayerActor;
        public float EvaluationInterval = 0.5f;
        public int MaxConcurrentAsyncLoads = 2;

        [Header("Registered Districts")]
        public List<DistrictChunk> Districts = new List<DistrictChunk>();

        private float _evalTimer = 0f;

        public override void OnStart()
        {
            if (PlayerActor == null)
            {
                var playerScript = Level.FindScript<Player.EchoPlayer>();
                if (playerScript != null)
                    PlayerActor = playerScript.Actor;
            }

            // Auto-gather all district chunks in world
            Districts.AddRange(Level.FindScripts<DistrictChunk>());
        }

        public override void OnUpdate()
        {
            if (PlayerActor == null)
                return;

            _evalTimer += Time.DeltaTime;
            if (_evalTimer >= EvaluationInterval)
            {
                _evalTimer = 0f;
                EvaluateDistrictStreaming();
            }
        }

        private void EvaluateDistrictStreaming()
        {
            Vector3 playerPos = PlayerActor.Position;
            for (int i = 0; i < Districts.Count; i++)
            {
                if (Districts[i] != null)
                {
                    Districts[i].CheckStreaming(playerPos);
                }
            }
        }
    }
}
