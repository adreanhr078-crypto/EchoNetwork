using System;
using FlaxEngine;

namespace EchoNetwork.World
{
    /// <summary>
    /// Seamless Enterable Interior Manager in Flax Engine.
    /// Eliminates loading screens when walking into Japanese shops, ramen bars, clinics,
    /// and apartments by managing portal triggers, exterior occlusion, and interior light sets.
    /// </summary>
    public class EnterableInteriorManager : Script
    {
        [Header("Interior Identification")]
        public string InteriorID = "Kasumi_Ramen_Bar";
        public Collider DoorwayTrigger;

        [Header("Lighting & Environment")]
        public Actor InteriorLightingRoot;
        public Actor ExteriorOcclusionBlocker;
        public AudioSource AmbientInteriorAudio;

        public bool IsPlayerInside { get; private set; }

        public override void OnStart()
        {
            if (DoorwayTrigger == null)
                DoorwayTrigger = Actor.As<Collider>();

            if (DoorwayTrigger != null)
            {
                DoorwayTrigger.IsTrigger = true;
            }

            // Start with interior lighting disabled or dimmed if player outside
            SetInteriorActive(false);
        }

        public override void OnTriggerEnter(Collider collider)
        {
            if (collider.Actor != null && collider.Actor.GetScript<Player.EchoPlayer>() != null)
            {
                OnPlayerEnteredInterior();
            }
        }

        public override void OnTriggerExit(Collider collider)
        {
            if (collider.Actor != null && collider.Actor.GetScript<Player.EchoPlayer>() != null)
            {
                OnPlayerExitedInterior();
            }
        }

        private void OnPlayerEnteredInterior()
        {
            IsPlayerInside = true;
            SetInteriorActive(true);
        }

        private void OnPlayerExitedInterior()
        {
            IsPlayerInside = false;
            SetInteriorActive(false);
        }

        private void SetInteriorActive(bool active)
        {
            if (InteriorLightingRoot != null)
                InteriorLightingRoot.IsActive = active;

            if (ExteriorOcclusionBlocker != null)
                ExteriorOcclusionBlocker.IsActive = active;

            if (AmbientInteriorAudio != null)
            {
                if (active)
                    AmbientInteriorAudio.Play();
                else
                    AmbientInteriorAudio.Stop();
            }
        }
    }
}
