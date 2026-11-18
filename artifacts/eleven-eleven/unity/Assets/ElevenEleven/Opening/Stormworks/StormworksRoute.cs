using UnityEngine;
using UnityEngine.UI;

namespace ElevenEleven.Opening
{
    public sealed class StormworksRoute : MonoBehaviour
    {
        internal const int BeyondPressure = 1;
        internal const int RelayRestored = 2;
        internal const int LabRead = 3;
        internal const int SecurityPassed = 4;
        internal const int SpecimenLogged = 5;
        internal const int SpecimenPassed = 6;
        internal const int ArchiveDecoded = 7;
        internal const int ArchivePassed = 8;
        internal const int ReactorPassed = 9;
        internal const int QuarantineOverridden = 10;
        internal const int QuarantinePassed = 11;
        internal const int MirrorInspected = 12;
        internal const int SurveillanceOverridden = 13;
        internal const int SurveillanceOpen = 14;
        internal const int SurveillancePassed = 15;
        public const float PressureStart = 25f;
        internal const float RevealLine = 33.7f;
        private static readonly int Clock = Shader.PropertyToID("_EchoSurfaceClock");
        private static readonly int Contact = Shader.PropertyToID("_EchoSurfaceContact");
        private static readonly int AirLoad = Shader.PropertyToID("_EchoAirLoad");
        private static readonly int RelayCharge = Shader.PropertyToID("_EchoRelayCharge");
        private static readonly int Emission = Shader.PropertyToID("_EmissionColor");
        private static readonly Color Cyan = new Color(0.08f, 0.85f, 0.77f);
        private static readonly Color Amber = new Color(1f, 0.28f, 0.06f);

        [SerializeField] private Transform valve;
        [SerializeField] private Transform wheel;
        [SerializeField] private Transform labDoor;
        [SerializeField] private Transform relay;
        [SerializeField] private Transform labLog;
        [SerializeField] private Renderer[] pressureSignals;
        [SerializeField] private Text pressureDisplay;
        [SerializeField] private AudioSource machinery;
        [SerializeField] private AudioSource drip;
        [SerializeField] private Transform vista;
        [SerializeField] private Transform vistaFocus;
        [SerializeField] private StationSecurityWing security;
        [SerializeField] private StationSpecimenWing specimen;
        [SerializeField] private StationArchiveWing archive;
        [SerializeField] private StationReactorWing reactor;
        [SerializeField] private StationQuarantineWing quarantine;
        [SerializeField] private StationSurveillanceWing surveillance;
        [SerializeField] private ArchiveVignettes vignettes;

        private readonly Room01PressureTrial pressure = new Room01PressureTrial();
        private MaterialPropertyBlock signalProperties;
        private Vector3 labDoorClosed;
        private Quaternion wheelRest;
        private float elapsed;
        private float reveal;
        private bool revealed;
        private bool? lastSafe;
        private Vector4 contact = new Vector4(0f, 0f, -10f, 0f);
        private string pressureCopy;
        internal int Stage { get; private set; }
        internal int MemoryFragments => archive.Fragments;
        internal int PoweredBreakers => reactor.Breakers;
        internal bool InReveal => reveal > 0f;
        private bool SawReflection => Stage == MirrorInspected || Stage >= SurveillanceOpen;
        private bool LiftedLockdown => Stage >= SurveillanceOverridden;
        internal bool GameplayHeld => InReveal || vignettes.Active;
        internal Transform Vista => vista;
        internal Transform VistaFocus => vistaFocus;
        internal float RevealWeight => Mathf.SmoothStep(0f, 1f,
            Mathf.Clamp01(Mathf.Min((3.2f - reveal) / 0.75f, reveal / 0.95f)));
        internal Vector3 ReturnPoint => Stage switch
        {
            ArchiveDecoded => archive.Checkpoint,
            SurveillancePassed => surveillance.Exit,
            SurveillanceOpen => surveillance.DaisAnchor,
            SurveillanceOverridden => surveillance.DaisAnchor,
            MirrorInspected => surveillance.MirrorAnchor,
            QuarantinePassed => surveillance.Arrival,
            QuarantineOverridden => quarantine.Catwalk,
            ReactorPassed => reactor.Landing,
            ArchivePassed => PoweredBreakers > 0 ? reactor.EntryPoint : archive.Landing,
            SpecimenLogged => specimen.Checkpoint,
            SpecimenPassed => specimen.ExitCheckpoint,
            _ => Recovery(Stage),
        };

        private void Awake()
        {
            signalProperties = new MaterialPropertyBlock();
            labDoorClosed = labDoor.localPosition;
            wheelRest = wheel.localRotation;
            UpdateSignal(false);
        }

        private void OnDisable()
        {
            Shader.SetGlobalFloat(Clock, 0f);
            Shader.SetGlobalFloat(AirLoad, 0f);
            Shader.SetGlobalFloat(RelayCharge, 0f);
            Shader.SetGlobalVector(Contact, Vector4.zero);
            machinery.Stop();
            drip.Stop();
        }

        internal static Vector3 Recovery(int stage) => stage switch
        {
            SecurityPassed => StationSecurityWing.ExitRecovery,
            LabRead => new Vector3(13.4f, 0.05f, 66.7f),
            RelayRestored => new Vector3(-10f, 0.05f, 65f),
            _ => new Vector3(0f, 0.05f, 28.3f),
        };

        internal void Restore(int stage, int archiveFragments, int reactorBreakers)
        {
            Stage = stage;
            revealed = stage >= RelayRestored;
            if (Stage >= RelayRestored) SetLabDoor(true, 1f);
            security.Restore(Stage >= LabRead, Stage >= SecurityPassed);
            specimen.Restore(Stage >= SecurityPassed, Stage >= SpecimenLogged, Stage >= SpecimenPassed);
            archive.Restore(archiveFragments, Stage >= SpecimenPassed, Stage >= ArchiveDecoded);
            reactor.Restore(reactorBreakers, Stage >= ArchivePassed);
            quarantine.Present(Stage >= QuarantineOverridden, 1f);
            surveillance.Present(SawReflection, LiftedLockdown, 1f);
        }

        internal string Objective(Vector3 position) => Stage switch
        {
            SurveillancePassed => EntryCopy.Arabic ? "‏ﺺﺤﻔﻟﺍ ﺡﺎﻨﺟ ﻰﻟﺇ ﺖﻠﺻﻭ" : "You reached the examination wing.",
            >= QuarantinePassed => surveillance.Objective(SawReflection, LiftedLockdown),
            >= ReactorPassed => quarantine.Objective(Stage >= QuarantineOverridden),
            ArchivePassed => reactor.Objective(position),
            ArchiveDecoded => archive.Objective(position, true),
            SpecimenPassed => archive.Objective(position, false),
            SpecimenLogged => specimen.Objective(position, true),
            SecurityPassed => specimen.Objective(position, false),
            LabRead => security.Objective(position),
            RelayRestored => (EntryCopy.Arabic ? ".ﻲﻗﺮﺸﻟﺍ ﺮﺒﺘﺨﻤﻟﺍ ﻞﺠﺳ ﺺﺤﻓﺍ .ﻞﻤﻌﻳ ﻞﺣﺮﻤﻟﺍ" : "Relay online. Inspect the east laboratory log."),
            BeyondPressure when position.z >= RevealLine =>
                (EntryCopy.Arabic ? ".ﺰﻔﻘﻟﺍ ﺕﺎﺼﻨﻣ ﻭﺃ ﺝﺭﺪﻟﺍ ﺮﺘﺧﺍ .ﻲﺑﺮﻐﻟﺍ ﻞﺣﺮﻤﻟﺍ ﻞﻐﺷ" : "Restore the west relay via the stairs or jump route."),
            BeyondPressure => (EntryCopy.Arabic ? ".ﺔﻓﺮﺸﻟﺍ ﻮﺤﻧ ﺀﻮﻀﻟﺍ ﻊﺒﺗﺍ" : "Follow the lights to the overlook."),
            _ when position.z < 20f => "The signal leads deeper into Sector 11.",
            _ => (EntryCopy.Arabic ? ".ﺲﻴﻔﻨﺘﻟﺍ ﻡﺎﻤﺻ ﺢﺘﻓﺍ ﻭﺃ ﻂﻐﻀﻟﺍ ﺽﺎﻔﺨﻧﺍ ﺪﻨﻋ ﺮﺒﻋﺍ" : "Cross at low pressure or vent with the valve."),
        };

        internal string Action(Vector3 position)
        {
            if (GameplayHeld) return "";
            if (Stage == ReactorPassed) return quarantine.Action(position, false);
            if (Stage >= QuarantinePassed && Stage < SurveillanceOpen)
                return surveillance.Action(position, SawReflection, LiftedLockdown);
            if (Stage >= QuarantineOverridden) return "";
            if (Stage == LabRead) return security.Action(position);
            if (Stage == ArchivePassed)
            {
                var reactorAction = reactor.Action(position);
                if (reactorAction.Length > 0) return reactorAction;
            }
            if (Stage >= SpecimenPassed)
            {
                var archiveAction = archive.Action(position, Stage >= ArchiveDecoded);
                if (archiveAction.Length > 0) return archiveAction;
            }
            if (Stage >= SecurityPassed) return specimen.Action(position, Stage >= SpecimenLogged);
            if (Stage == 0 && IsNear(valve, position, 1.6f) && pressure.VentRemaining <= 0)
                return (EntryCopy.Arabic ? "[E] ﻂﻐﻀﻟﺍ ﺲﻔﻧ" : "Vent pressure  [E]");
            if (Stage == BeyondPressure && IsNear(relay, position, 1.8f))
                return (EntryCopy.Arabic ? "[E] ﻞﺣﺮﻤﻟﺍ ﻞﻐﺷ" : "Restore relay  [E]");
            if (Stage == RelayRestored && IsNear(labLog, position, 1.7f))
                return (EntryCopy.Arabic ? "[E] ﺮﺒﺘﺨﻤﻟﺍ ﻞﺠﺳ ﺃﺮﻗﺍ" : "Read lab log  [E]");
            return "";
        }

        internal void Interact(Room01Player player)
        {
            var position = player.transform.position;
            if (Action(position).Length == 0) return;
            if (Stage == ReactorPassed && quarantine.CanOverride(position))
            {
                Stage = QuarantineOverridden;
                player.SaveRouteProgress(EntryCopy.Arabic ? "‏ﺮﺠﺤﻟﺍ ﻊﻓﺭ .ﺏﺎﺒﻟﺍ ﺢﺘﻓ" :
                    "Quarantine cleared. The north gate is opening.");
                return;
            }
            if (Stage >= QuarantinePassed && Stage < SurveillanceOpen)
            {
                if (!SawReflection && surveillance.CanInspect(position))
                {
                    Stage = LiftedLockdown ? SurveillanceOpen : MirrorInspected;
                    player.FaceRouteFocus(surveillance.ReflectionFocus);
                    player.SaveRouteProgress(EntryCopy.Arabic ? "‏ﺝﺎﺟﺰﻟﺍ ﺮﺒﻋ ﻪﻬﺟﻭ ﻮﻜﻳﺇ ﺪﻫﺎﺷ" :
                        "Echo studies a familiar face through the glass.");
                }
                else if (!LiftedLockdown && surveillance.CanOverride(position))
                {
                    Stage = SawReflection ? SurveillanceOpen : SurveillanceOverridden;
                    player.SaveRouteProgress(EntryCopy.Arabic ? "‏ﺢﺴﻤﻟﺍ ﻒﻗﻮﺗ" :
                        "The surveillance grid is offline.");
                }
                return;
            }
            if (Stage == LabRead)
            {
                security.Interact(position);
                return;
            }
            if (Stage == ArchivePassed && reactor.Interact(position))
            {
                var both = reactor.Breakers == StationReactorWing.Both;
                player.SaveRouteProgress(EntryCopy.Arabic ?
                    (both ? "‏ﺮﺴﺠﻟﺍ ﻊﻔﺗﺭﺍ" : "‏ﻊﻃﺎﻘﻟﺍ ﻞﻐﺘﺷﺍ") :
                    (both ? "Both breakers are online. The hydraulic bridge is rising." : "Breaker restored."));
                return;
            }
            if (Stage == SpecimenPassed)
            {
                if (archive.CanDecode(position))
                {
                    Stage = ArchiveDecoded;
                    player.SaveRouteProgress(EntryCopy.Arabic ? "‏ﺓﺮﻛﺍﺬﻟﺍ ﻞﺠﺳ ﻚﻓ ﻢﺗ" : "The archive record is decoded.");
                    return;
                }
                var recovered = archive.Collect(position);
                if (recovered.Length > 0)
                {
                    player.SaveRouteProgress(recovered);
                    vignettes.Show(archive.LastRecovered);
                    return;
                }
            }
            if (Stage >= SecurityPassed)
            {
                if (Stage == SecurityPassed && specimen.ReadTerminal(position))
                {
                    Stage = SpecimenLogged;
                    player.SaveRouteProgress(EntryCopy.Arabic
                        ? "‏ﺀﺍﻮﺘﺣﻻﺎﺑ ﺎﺠﻨﻴﻛ ﺮﻣﺃ .ﺓﺮﻛﺍﺬﻟﺍ ﺩﺎﻤﺧﺇ ﻞﺒﻗ ﻆﻘﻴﺘﺳﺍ EX-011"
                        : StationSpecimenWing.Record);
                }
                else player.ShowRouteNote(specimen.TankResult(position));
                return;
            }
            if (Stage == 0)
            {
                pressure.TryVent(true, false);
                return;
            }

            if (Stage == BeyondPressure)
            {
                Stage = RelayRestored;
                player.SaveRouteProgress((EntryCopy.Arabic ? ".ﻲﻗﺮﺸﻟﺍ ﺮﺒﺘﺨﻤﻟﺍ ﻰﻟﺇ ﺭﺎﻴﺘﻟﺍ ﺪﻴﻋﺃ" : "The east lab has power again."));
            }
            else
            {
                Stage = LabRead;
                player.SaveRouteProgress((EntryCopy.Arabic ? ".١١:١١ ﺎﻤﺋﺍﺩ ﺔﻋﺎﺴﻟﺍ ،ﺎﻨﻫ ﺭﺮﻜﺘﺗ ﺔﺑﺮﺠﺘﻟﺍ :ﻞﺠﺴﻟﺍ" : "LOG: The trial keeps repeating here. The clock always stops at 11:11."));
            }
        }

        internal void Tick(Room01Player player, float dt, bool modal, bool crossed)
        {
            var position = player.transform.position;
            var reduced = ChapterSceneLink.ReducedMotion;
            var motionTime = modal ? 0f : dt;
            vignettes.Advance(motionTime);
            if (!reduced) elapsed += motionTime;
            Shader.SetGlobalFloat(Clock, elapsed);
            Shader.SetGlobalVector(Contact, reduced ? Vector4.zero : contact);
            UpdateAudio(position, crossed, modal, dt);
            var approachingPressure = crossed && Stage == 0 && position.z >= 20f;
            if (approachingPressure)
            {
                var result = pressure.Advance(motionTime, position.z - PressureStart, modal);
                if (result == Room01PressureTrial.Crossing.Retry)
                    player.ReturnToSafePoint(new Vector3(0f, 0.05f, 23.4f),
                        (EntryCopy.Arabic ? ".ﺔﻨﻣﻵﺍ ﺔﻘﻄﻨﻤﻟﺍ ﻦﻣ ﻝﻭﺎﺣ .ﻂﻐﻀﻟﺍ ﻊﻓﺪﻧﺍ" : "Pressure surged. Retry from the safe bay."));
                if (result == Room01PressureTrial.Crossing.Completed)
                {
                    Stage = BeyondPressure;
                    player.SaveRouteProgress((EntryCopy.Arabic ? ".ﻂﻐﻀﻟﺍ ﻂﺧ ﺕﺮﺒﻋ" : "Pressure line crossed."));
                }
            }

            var safe = Stage > 0 || pressure.IsSafe;
            Shader.SetGlobalFloat(AirLoad, safe ? 0.18f : 1f);
            Shader.SetGlobalFloat(RelayCharge, Stage >= RelayRestored ? 1f : 0f);
            UpdateSignal(safe);
            UpdateReadout(approachingPressure && Stage == 0);
            wheel.localRotation = wheelRest * Quaternion.AngleAxis(reduced ? 0f :
                135f * Mathf.Clamp01((float)pressure.VentRemaining), Vector3.forward);
            SetLabDoor(Stage >= RelayRestored, reduced ? 1f : 1f - Mathf.Exp(-5f * motionTime));
            security.Tick(player, motionTime, Stage >= LabRead, Stage >= SecurityPassed, modal);
            if (Stage == LabRead && !modal && security.Passed(player.transform.position))
            {
                Stage = SecurityPassed;
                player.SaveRouteProgress(EntryCopy.Arabic ? "‏ﻦﻣﻷﺍ ﺡﺎﻨﺟ ﺕﺮﺒﻋ" : "Security wing crossed.");
            }
            specimen.Tick(player, Stage >= SecurityPassed, Stage >= SpecimenLogged, Stage >= SpecimenPassed, motionTime, modal);
            if (Stage == SpecimenLogged && !modal && specimen.Crossed(player.transform.position))
            {
                Stage = SpecimenPassed;
                player.SaveRouteProgress(EntryCopy.Arabic ? "‏ﺕﺎﻨﻴﻌﻟﺍ ﺡﺎﻨﺟ ﺕﺮﺒﻋ" : "Specimen wing crossed.");
            }

            archive.Tick(motionTime, Stage >= SpecimenPassed, Stage >= ArchiveDecoded);
            if (Stage == ArchiveDecoded && !modal && archive.Crossed(player.transform.position))
            {
                Stage = ArchivePassed;
                player.SaveRouteProgress(EntryCopy.Arabic ? "‏ﻒﻴﺷﺭﻷﺍ ﺕﺮﺒﻋ" : "Archive crossed.");
            }

            reactor.Tick(player, Stage >= ArchivePassed, motionTime);
            if (Stage == ArchivePassed && !modal && reactor.Passed(player.transform.position))
            {
                Stage = ReactorPassed;
                player.SaveRouteProgress(EntryCopy.Arabic ? "‏ﻞﻋﺎﻔﻤﻟﺍ ﺕﺮﺒﻋ" : "Reactor crossed.");
            }

            quarantine.Tick(player.transform.position, Stage >= QuarantineOverridden, modal, motionTime);
            if (Stage == QuarantineOverridden && !modal)
            {
                var feet = player.transform.position;
                var entrance = surveillance.Arrival;
                if (Mathf.Abs(feet.x - entrance.x) < 1.03f && Mathf.Abs(feet.y - entrance.y) < 0.42f &&
                    feet.z > entrance.z - 0.92f && feet.z < entrance.z + 0.9f)
                {
                    Stage = QuarantinePassed;
                    player.SaveRouteProgress(EntryCopy.Arabic ? "‏ﺔﺒﻗﺍﺮﻤﻟﺍ ﺡﺎﻨﺟ ﺖﻠﺧﺩ" : "Surveillance wing reached.");
                }
            }

            if (Stage >= QuarantinePassed)
                surveillance.Tick(player, SawReflection, LiftedLockdown, motionTime, modal);
            if (Stage == SurveillanceOpen && !modal && surveillance.Crossed(player.transform.position))
            {
                Stage = SurveillancePassed;
                player.SaveRouteProgress(EntryCopy.Arabic ? "‏ﺺﺤﻔﻟﺍ ﺡﺎﻨﺟ ﺖﻠﺻﻭ" : "Examination wing reached.");
            }

            if (InReveal) reveal = Mathf.Max(0f, reveal - motionTime);
            else if (!revealed && Stage >= BeyondPressure && position.z >= RevealLine)
            {
                revealed = true;
                if (!reduced && !modal) reveal = 3.2f;
            }
        }

        internal void EndReveal()
        {
            reveal = 0f;
            vignettes.End();
        }

        internal void Land(Vector3 position, float power)
        {
            contact = new Vector4(position.x, position.z, elapsed, Mathf.Clamp01(power));
        }

        private void UpdateReadout(bool visible)
        {
            if (pressureDisplay.gameObject.activeSelf != visible) pressureDisplay.gameObject.SetActive(visible);
            if (!visible) return;
            var phase = pressure.Elapsed % (Room01PressureTrial.HighSeconds + Room01PressureTrial.LowSeconds);
            var seconds = pressure.IsSafe ? Room01PressureTrial.HighSeconds + Room01PressureTrial.LowSeconds - phase
                : Room01PressureTrial.HighSeconds - phase;
            var copy = pressure.VentRemaining > 0
                ? (EntryCopy.Arabic ? "ﺲﻴﻔﻨﺗ" : "VENTED") + $"  {pressure.VentRemaining:0.0}"
                : (pressure.IsSafe ? (EntryCopy.Arabic ? "ﺾﻔﺨﻨﻣ ﻂﻐﺿ" : "LOW PRESSURE")
                    : (EntryCopy.Arabic ? "ﻊﻔﺗﺮﻣ ﻂﻐﺿ" : "HIGH PRESSURE")) + $"  {seconds:0.0}";
            if (copy == pressureCopy) return;
            pressureCopy = copy;
            pressureDisplay.text = copy;
            pressureDisplay.color = pressure.IsSafe ? new Color(0.56f, 1f, 0.88f) : new Color(1f, 0.74f, 0.53f);
        }

        private void UpdateSignal(bool safe)
        {
            if (lastSafe == safe) return;
            lastSafe = safe;
            signalProperties.SetColor(Emission, (safe ? Cyan : Amber) * 2.2f);
            foreach (var signal in pressureSignals) signal.SetPropertyBlock(signalProperties);
        }

        private void SetLabDoor(bool open, float blend)
        {
            var target = labDoorClosed + (open ? Vector3.up * 4.4f : Vector3.zero);
            labDoor.localPosition = Vector3.Lerp(labDoor.localPosition, target, blend);
        }

        private void UpdateAudio(Vector3 position, bool crossed, bool modal, float dt)
        {
            var muted = ChapterSceneLink.Muted;
            var blend = 1f - Mathf.Exp(-5f * dt);
            SetAudio(drip, muted, modal, 0.32f, blend);
            var nearPressure = crossed && Stage == 0 && position.z < 29f;
            var volume = nearPressure ? (pressure.IsSafe ? 0.15f : 0.60f) :
                Mathf.Lerp(0.18f, 0.34f, Mathf.InverseLerp(30f, 56f, position.z));
            SetAudio(machinery, muted, modal, volume, blend);
        }

        private static void SetAudio(AudioSource source, bool muted, bool paused, float volume, float blend)
        {
            source.mute = muted;
            if (paused)
            {
                source.Pause();
                return;
            }
            source.UnPause();
            if (!source.isPlaying && source.clip != null) source.Play();
            source.volume = Mathf.Lerp(source.volume, volume, blend);
        }

        private static bool IsNear(Transform item, Vector3 position, float radius)
        {
            var delta = item.position - position;
            return Mathf.Abs(delta.y) < 1.35f && new Vector2(delta.x, delta.z).sqrMagnitude <= radius * radius;
        }
    }
}

