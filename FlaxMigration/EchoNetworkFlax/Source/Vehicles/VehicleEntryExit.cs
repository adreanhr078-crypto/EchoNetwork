using System;
using FlaxEngine;

namespace EchoNetwork.Vehicles
{
    /// <summary>
    /// Vehicle Entry and Exit System in Flax Engine.
    /// Manages mount/dismount interactions, seat socketing, and camera target redirection.
    /// </summary>
    public class VehicleEntryExit : Script
    {
        [Header("Seat & Mount")]
        public Transform SeatSocket;
        public Vector3 DismountOffset = new Vector3(-1.2f, 0f, 0f);
        public float InteractionRadius = 2.5f;

        [Header("Subsystems")]
        public VehicleController Vehicle;
        public Camera.ThirdPersonOrbitCamera MainCamera;

        public bool IsDriverMounted { get; private set; }

        private Player.EchoPlayer _mountedPlayer;

        public override void OnStart()
        {
            if (Vehicle == null)
                Vehicle = Actor.GetScript<VehicleController>();

            if (MainCamera == null)
            {
                var cam = Level.FindScript<Camera.ThirdPersonOrbitCamera>();
                if (cam != null)
                    MainCamera = cam;
            }
        }

        public override void OnUpdate()
        {
            if (!IsDriverMounted)
            {
                CheckForMountInput();
            }
            else
            {
                CheckForDismountInput();
            }
        }

        private void CheckForMountInput()
        {
            if (Input.GetAction("Interact"))
            {
                var player = Level.FindScript<Player.EchoPlayer>();
                if (player != null && !player.IsDead)
                {
                    float dist = Vector3.Distance(Actor.Position, player.Actor.Position);
                    if (dist <= InteractionRadius)
                    {
                        MountPlayer(player);
                    }
                }
            }
        }

        private void CheckForDismountInput()
        {
            if (Input.GetAction("Interact") && Vehicle != null && Vehicle.CurrentSpeed < 3.0f)
            {
                DismountPlayer();
            }
        }

        public void MountPlayer(Player.EchoPlayer player)
        {
            _mountedPlayer = player;
            IsDriverMounted = true;

            // Disable player locomotion and character controller
            if (player.Controller != null)
                player.Controller.IsActive = false;
            if (player.Locomotion != null)
                player.Locomotion.IsActive = false;

            // Snap player to seat
            player.Actor.Parent = Actor;
            player.Actor.LocalPosition = SeatSocket.Translation;
            player.Actor.LocalOrientation = SeatSocket.Orientation;

            // Enable vehicle control
            if (Vehicle != null)
                Vehicle.IsOccupied = true;

            // Redirect camera to vehicle
            if (MainCamera != null)
                MainCamera.Target = Actor;
        }

        public void DismountPlayer()
        {
            if (_mountedPlayer == null)
                return;

            IsDriverMounted = false;

            // Unparent player and place at dismount offset
            _mountedPlayer.Actor.Parent = null;
            _mountedPlayer.Actor.Position = Actor.Position + Actor.Transform.TransformDirection(DismountOffset);

            // Re-enable player locomotion and character controller
            if (_mountedPlayer.Controller != null)
                _mountedPlayer.Controller.IsActive = true;
            if (_mountedPlayer.Locomotion != null)
                _mountedPlayer.Locomotion.IsActive = true;

            // Disable vehicle control
            if (Vehicle != null)
                Vehicle.IsOccupied = false;

            // Redirect camera back to player
            if (MainCamera != null)
                MainCamera.Target = _mountedPlayer.Actor;

            _mountedPlayer = null;
        }
    }
}
