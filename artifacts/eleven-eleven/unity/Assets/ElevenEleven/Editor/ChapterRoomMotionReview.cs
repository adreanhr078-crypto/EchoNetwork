using System;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEngine;

namespace ElevenEleven.Editor
{
    internal static class ChapterRoomMotionReview
    {
        private static Zone[] zones;
        private static GameObject ward;
        private static bool wardWasActive;
        private static bool priorReducedMotion;
        private static float start;
        private static int nextFrame;
        private static int phase;
        private static int samples;

        private sealed class Zone
        {
            internal readonly RoomEnvironmentMotion Motion;
            internal readonly Transform Observer;
            internal readonly Transform[] Targets;
            internal readonly ParticleSystem Air;
            internal readonly LineRenderer Arc;
            internal Pose[] Home;
            internal Pose[] Still;
            internal bool[] Sampled;

            internal Zone(RoomEnvironmentMotion motion, Room01Player player)
            {
                Motion = motion;
                using var data = new SerializedObject(motion);
                Observer = (Transform)data.FindProperty("observer").objectReferenceValue;
                Require(Observer == player.transform, motion.name + " is bound to the live player");
                var pieces = data.FindProperty("pieces");
                Targets = Enumerable.Range(0, pieces.arraySize)
                    .Select(index => (Transform)pieces.GetArrayElementAtIndex(index).FindPropertyRelative("target").objectReferenceValue)
                    .ToArray();
                Require(Targets.Length >= 15 && Targets.All(target => target) &&
                        Targets.Distinct().Count() == Targets.Length, motion.name + " has 15 or more independent targets");
                Air = (ParticleSystem)data.FindProperty("atmosphere").objectReferenceValue;
                Arc = (LineRenderer)data.FindProperty("arc").objectReferenceValue;
                Require(Air, motion.name + " has a live air emitter");
            }

            internal void ObserveFrom(Transform at)
            {
                using var data = new SerializedObject(Motion);
                data.FindProperty("observer").objectReferenceValue = at;
                data.ApplyModifiedPropertiesWithoutUndo();
            }

            internal Pose[] Read() => Targets.Select(target => new Pose(target.localPosition, target.localRotation)).ToArray();

            internal bool Parked() => Read().Zip(Home, Moved).All(moved => !moved) && !Air.isPlaying && (!Arc || !Arc.enabled);
        }

        internal static bool Step(Room01Player player)
        {
            if (phase == 6) return true;
            if (Time.frameCount < nextFrame) return false;
            try
            {
                var station = GameObject.Find("Echo Station");
                switch (phase)
                {
                    case 0:
                        Require(station, "Room fixture loaded the playable station");
                        ward = station.transform.Find("Hospital transfer/Awakening ward").gameObject;
                        wardWasActive = ward.activeSelf;
                        ward.SetActive(true);
                        priorReducedMotion = ChapterSceneLink.ReducedMotion;
                        ChapterSceneLink.ReducedMotion = true;
                        zones = station.GetComponentsInChildren<RoomEnvironmentMotion>(true).Select(motion => new Zone(motion, player)).ToArray();
                        Require(zones.Length == 16, "All 16 authored zones are present");
                        foreach (var zone in zones)
                        {
                            Require(zone.Motion.isActiveAndEnabled, zone.Motion.name + " has an active controller");
                            zone.ObserveFrom(zone.Motion.transform);
                        }
                        break;
                    case 1:
                        foreach (var zone in zones)
                        {
                            zone.Home = zone.Read();
                            zone.Sampled = new bool[zone.Targets.Length];
                        }
                        samples = 0;
                        ChapterSceneLink.ReducedMotion = false;
                        start = Time.time;
                        break;
                    case 2:
                        foreach (var zone in zones)
                        {
                            zone.Still = zone.Read();
                            for (var i = 0; i < zone.Sampled.Length; i++)
                                zone.Sampled[i] |= Moved(zone.Home[i], zone.Still[i]);
                        }
                        if (++samples < 8 || Time.time - start < .8f) return false;
                        foreach (var zone in zones)
                        {
                            Require(zone.Sampled.All(moved => moved) && zone.Air.isPlaying, zone.Motion.name + " animates every target");
                            Debug.Log($"ECHO_ROOM_MOTION_CHECK {zone.Motion.name} animated={zone.Targets.Length}");
                        }
                        Time.timeScale = 0f;
                        break;
                    case 3:
                        foreach (var zone in zones)
                            Require(zone.Read().Zip(zone.Still, Moved).All(moved => !moved), zone.Motion.name + " stops at pause");
                        ChapterSceneLink.ReducedMotion = true;
                        Time.timeScale = 1f;
                        break;
                    case 4:
                        foreach (var zone in zones)
                        {
                            Require(zone.Parked(), zone.Motion.name + " parks with Reduced Motion");
                        }
                        // Reverse the vicinity test without changing the location of the real player.
                        var distant = new GameObject("Room art distant observer").transform;
                        distant.position = new Vector3(10000, 10000, 10000);
                        foreach (var zone in zones) zone.ObserveFrom(distant);
                        ChapterSceneLink.ReducedMotion = false;
                        break;
                    case 5:
                        foreach (var zone in zones)
                        {
                            Require(zone.Parked(), zone.Motion.name + " parks outside its authored radius");
                            zone.ObserveFrom(zone.Observer);
                        }
                        ward.SetActive(wardWasActive);
                        CaptureSignalChamber(Camera.main);
                        ChapterSceneLink.ReducedMotion = priorReducedMotion;
                        Debug.Log($"ECHO_ROOM_MOTION_PLAY_PASS zones={zones.Length} moving_elements={zones.Sum(zone => zone.Targets.Length)} pause=true reduced_motion=true culling=true");
                        phase = 6;
                        return true;
                }
                phase++;
                nextFrame = Time.frameCount + 3;
            }
            catch
            {
                Time.timeScale = 1f;
                ChapterSceneLink.ReducedMotion = priorReducedMotion;
                throw;
            }
            return false;
        }

        private static void CaptureSignalChamber(Camera camera)
        {
            var original = new Pose(camera.transform.position, camera.transform.rotation);
            try
            {
                Capture(new Vector3(1.15f, 1.76f, -6.2f), new Vector3(.32f, 2.56f, 11.1f), "31-Signal-Entry");
                Capture(new Vector3(-.46f, 1.82f, 15.2f), new Vector3(-6.0f, 2.9f, 5.1f), "32-Signal-Reverse");
                Capture(new Vector3(-5.25f, 2.17f, 3.3f), new Vector3(-10.58f, 3.28f, 8.4f), "33-Signal-West-Viewport");
                Capture(new Vector3(6.68f, 2.03f, .7f), new Vector3(10.60f, 3.35f, 3.75f), "34-Signal-Tripo-Viewport");
            }
            finally
            {
                camera.transform.SetPositionAndRotation(original.position, original.rotation);
            }

            void Capture(Vector3 from, Vector3 target, string name)
            {
                camera.transform.SetPositionAndRotation(from, Quaternion.LookRotation(target - from));
                StormworksSmoke.Capture(camera, name);
            }
        }

        private static bool Moved(Pose a, Pose b) =>
            (a.position - b.position).sqrMagnitude > 0.0000005f || Quaternion.Angle(a.rotation, b.rotation) > .08f;

        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException(message);
        }

    }
}
