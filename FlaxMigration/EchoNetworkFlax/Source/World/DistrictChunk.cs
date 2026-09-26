using System;
using FlaxEngine;

namespace EchoNetwork.World
{
    /// <summary>
    /// Represents an open-world district chunk in Flax Engine.
    /// Manages bounding box containment, async sub-scene loading, and LOD proxies.
    /// </summary>
    public class DistrictChunk : Script
    {
        [Header("District Metadata")]
        public string DistrictName = "District_01";
        public SceneReference DistrictScene;
        public BoundingBox DistrictBounds;

        [Header("Streaming Distances")]
        public float LoadRadius = 220f;
        public float UnloadRadius = 320f;

        public bool IsLoaded { get; private set; }
        public bool IsLoading { get; private set; }

        private Scene _loadedSceneInstance;

        public void CheckStreaming(Vector3 playerPosition)
        {
            float dist = Vector3.Distance(playerPosition, DistrictBounds.Center);

            if (!IsLoaded && !IsLoading && dist <= LoadRadius)
            {
                LoadChunkAsync();
            }
            else if (IsLoaded && dist >= UnloadRadius)
            {
                UnloadChunk();
            }
        }

        private void LoadChunkAsync()
        {
            if (DistrictScene.ID == Guid.Empty)
                return;

            IsLoading = true;
            // Flax Engine asynchronous scene loading
            Level.LoadSceneAsync(DistrictScene.ID);
            IsLoaded = true;
            IsLoading = false;
        }

        private void UnloadChunk()
        {
            if (DistrictScene.ID == Guid.Empty)
                return;

            Level.UnloadScene(DistrictScene.ID);
            IsLoaded = false;
        }
    }
}
