import {
  Suspense,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { Canvas, useThree } from '@react-three/fiber';
import { ACESFilmicToneMapping, Vector3, type Group } from 'three';
import { EffectComposer, Bloom, Vignette } from '@react-three/postprocessing';
import type {
  MotionTier,
  QualityTier,
} from '../../../ui/design-system';
import { OPENING_ROOM_CONFIG } from '../data/openingRoom.config';
import {
  OPENING_ROOM_INTERACTIONS,
} from '../data/openingRoom.interactions';
import { useGameplayAudio } from '../audio/useGameplayAudio';
import { useOpeningRoomProgress } from '../hooks/useOpeningRoomProgress';
import { usePlayerControls } from '../hooks/usePlayerControls';
import { EchoPlayer } from './EchoPlayer';
import { GameplayHUD } from './GameplayHUD';
import { InteractionCamera } from './InteractionCamera';
import {
  NarrativeOverlay,
  type NarrativeOverlayContent,
} from './NarrativeOverlay';
import { RoomLoader } from './RoomLoader';
import { OPENING_LAB_DEFINITION } from '../data/openingLabDefinition';
import {
  OpeningRoom,
  type OpeningRoomVisualEvent,
} from './OpeningRoom';
import { CinematicDirector } from '../../cinematics/components/CinematicDirector';
import { OPENING_CINEMATIC_SEQUENCE } from '../../cinematics/data/sequences';
import { OpeningMemoryBeat } from './OpeningMemoryBeat';
import {
  completeOpeningRoom,
} from '../../../infrastructure/player-progression/playerProgressionApi';
import {
  OPENING_ROOM_EVENT_SEQUENCE,
  type OpeningRoomEventId,
} from '../../../domain/opening/openingProgress';
import type { AuthoritativeStoryState } from '../../../domain/story/storyState';
import {
  ThirdPersonCamera,
  type ThirdPersonCameraConfig,
} from './ThirdPersonCamera';
import {
  CombatEffects,
  type CombatEffectsHandle,
} from './CombatEffects';
import {
  OpeningCinematic,
  OpeningCinematicOverlay,
} from './OpeningCinematic';


export const GLOBALS = { timeScale: 1.0 };
const OPENING_COMBAT_STUDY_ENABLED = false;

interface GameWorldProps {
  paused: boolean;
  quality: QualityTier;
  motion: MotionTier;
  onPause: () => void;
  onRoomComplete?: (storyState: AuthoritativeStoryState) => void;
}

const PUZZLE_STAGE_COPY = {
  locked: {
    objective: 'افحص الغرفة وابحث عن أثر عند 11:11',
    progress: 'الإشارة غير مكتملة',
  },
  clueFound: {
    objective: 'هناك أثر ثانٍ ما زال مخفيًا في الغرفة',
    progress: 'تم العثور على أول خيط',
  },
  memoryRecovered: {
    objective: 'دع الذاكرة تستقر',
    progress: 'شظية ذاكرة قيد الاستعادة',
  },
  solved: {
    objective: 'عد إلى باب الخروج',
    progress: 'اكتملت الإشارة · القفل ينتظر',
  },
  exitUnlocked: {
    objective: 'الباب مفتوح',
    progress: 'اكتملت الغرفة الافتتاحية',
  },
} as const;

function narrationForExecution(
  interactionId: string,
  outcome: string,
  message: string,
  memoryGranted: boolean,
): NarrativeOverlayContent {
  if (interactionId === 'opening-clock') {
    return {
      eyebrow: 'OBJECT // SYNCH POINT',
      title: 'الساعة المتوقفة',
      body: message,
      memoryFragment: memoryGranted
        ? 'لا أتذكر الوجه… فقط أنني لم أكن وحدي.'
        : undefined,
    };
  }
  if (interactionId === 'opening-photo') {
    return {
      eyebrow: memoryGranted
        ? 'MEMORY LINK // PARTIAL'
        : 'OBJECT // TORN RECORD',
      title: 'الصورة الممزقة',
      body: message,
      memoryFragment: memoryGranted
        ? 'لا أتذكر الوجه… فقط أنني لم أكن وحدي.'
        : undefined,
    };
  }
  if (outcome === 'locked') {
    return {
      eyebrow: 'EXIT // LOCKED',
      title: 'الباب لا يستجيب',
      body: message,
    };
  }
  return {
    eyebrow: 'EXIT // CHANNEL OPEN',
    title: 'استجاب القفل',
    body: message,
  };
}

function SceneDebugBridge({ cameraYawRef }: { cameraYawRef: { current: number } }) {
  const { scene, camera, gl } = useThree();
  useEffect(() => {
    if (typeof window !== 'undefined') {
      (window as any).__11_11_SCENE__ = {
        scene,
        camera,
        gl,
        captureScreenshot: () => {
          gl.render(scene, camera);
          return gl.domElement.toDataURL('image/png');
        },
        setCameraYaw: (radians: number) => {
          if (Number.isFinite(radians)) cameraYawRef.current = radians;
        },
      };
    }
  }, [scene, camera, gl, cameraYawRef]);
  return null;
}

export function GameWorld({
  paused,
  quality,
  motion,
  onPause,
  onRoomComplete,
}: GameWorldProps) {
  const playerRef = useRef<Group | null>(null);
  const cameraYawRef = useRef(0);
  const cameraTraumaRef = useRef(0);
  const combatEffectsRef = useRef<CombatEffectsHandle | null>(null);
  const [canvasReady, setCanvasReady] = useState(false);
  const [nearestInteractionId, setNearestInteractionId] = useState<
    string | null
  >(null);
  const [narrative, setNarrative] = useState<
    NarrativeOverlayContent | null
  >(null);
  const [activeInteractionId, setActiveInteractionId] = useState<
    string | null
  >(null);
  const [pendingMemoryBeat, setPendingMemoryBeat] = useState(false);
  const [memoryBeatActive, setMemoryBeatActive] = useState(false);
  const [roomCompletionStatus, setRoomCompletionStatus] = useState<
    'idle' | 'submitting' | 'completed' | 'error'
  >('idle');
  const [visualEvent, setVisualEvent] = useState<
    OpeningRoomVisualEvent | null
  >(null);
  const interactionNonceRef = useRef(0);
  const narrativeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(
    null,
  );
  const {
    flags,
    puzzle,
    enterRoom,
    executeInteraction,
    markControlsSeen,
    markCinematicSeen,
    completeRoomLocally,
    controlsSeen,
    cinematicSeen,
  } = useOpeningRoomProgress();
  const [cinematicActive, setCinematicActive] = useState(
    () => !cinematicSeen,
  );
  const [awakeningHandoffActive, setAwakeningHandoffActive] = useState(false);
  const [awakeningPhase, setAwakeningPhase] = useState<
    'wakeup' | 'standup' | 'idle' | null
  >(null);
  const [capsuleOpen, setCapsuleOpen] = useState(() => cinematicSeen);
  const { playCue } = useGameplayAudio();
  const showTutorial = !controlsSeen
    && !cinematicActive
    && !awakeningHandoffActive;

  useEffect(() => {
    enterRoom();
    playCue('ambient', { loop: true, volume: 0.28 });
    playCue('systemHum', { loop: true, volume: 0.18 });
  }, [enterRoom, playCue]);

  useEffect(() => () => {
    if (narrativeTimerRef.current) {
      clearTimeout(narrativeTimerRef.current);
    }
  }, []);

  const handleInteract = useCallback(() => {
    if (
      paused
      || cinematicActive
      || showTutorial
      || narrative
      || activeInteractionId
      || !nearestInteractionId
    ) {
      return;
    }
    const execution = executeInteraction(nearestInteractionId);
    if (!execution) return;

    if (execution.interaction.id === 'opening-clock') {
      playCue('clock', { volume: 0.45 });
    } else if (execution.interaction.id === 'opening-door') {
      playCue(
        execution.result.outcome === 'unlocked'
          ? 'doorOpen'
          : 'doorLocked',
        { volume: 0.5 },
      );
    } else if (execution.interaction.id === 'opening-katana-chest') {
      setPickedUpWeapon(true);
      playCue('slash', { volume: 0.8 });
    }
    if (
      execution.interaction.id === 'opening-door'
      && execution.result.outcome === 'unlocked'
    ) {
      setPendingMemoryBeat(true);
    }

    if (execution.memoryGranted) {
      playCue('memoryGlitch', { volume: 0.5 });
    }

    interactionNonceRef.current += 1;
    setActiveInteractionId(execution.interaction.id);
    setVisualEvent({
      nonce: interactionNonceRef.current,
      interactionId: execution.interaction.id,
      outcome: execution.result.outcome,
      memoryGranted: execution.memoryGranted,
    });
    const nextNarrative = narrationForExecution(
      execution.interaction.id,
      execution.result.outcome,
      execution.result.message,
      execution.memoryGranted,
    );
    if (narrativeTimerRef.current) {
      clearTimeout(narrativeTimerRef.current);
    }
    narrativeTimerRef.current = setTimeout(() => {
      narrativeTimerRef.current = null;
      setNarrative(nextNarrative);
    }, motion === 'reduced' ? 80 : 460);
  }, [
    executeInteraction,
    activeInteractionId,
    cinematicActive,
    narrative,
    nearestInteractionId,
    motion,
    paused,
    playCue,
    showTutorial,
  ]);

  const submitRoomCompletion = useCallback(async () => {
    if (roomCompletionStatus === 'submitting' || roomCompletionStatus === 'completed') return;
    setRoomCompletionStatus('submitting');
    try {
      const response = await completeOpeningRoom(
        OPENING_ROOM_EVENT_SEQUENCE as readonly OpeningRoomEventId[],
      );
      completeRoomLocally();
      setRoomCompletionStatus('completed');
      onRoomComplete?.(response.storyState);
    } catch {
      setRoomCompletionStatus('error');
    }
  }, [completeRoomLocally, onRoomComplete, roomCompletionStatus]);

  const inputEnabled = !paused
    && !cinematicActive
    && !awakeningHandoffActive
    && !showTutorial
    && !memoryBeatActive
    && roomCompletionStatus !== 'submitting'
    && roomCompletionStatus !== 'completed'
    && narrative === null
    && activeInteractionId === null;
  const cameraFollowEnabled = !paused
    && !cinematicActive
    && !awakeningHandoffActive
    && !memoryBeatActive
    && narrative === null
    && activeInteractionId === null;

  const [pickedUpWeapon, setPickedUpWeapon] = useState(false);
  const hasWeapon = OPENING_COMBAT_STUDY_ENABLED && pickedUpWeapon;
  const [combatAction, setCombatAction] = useState<{
    type: 'punch' | 'kick' | 'dodge' | 'slash';
    nonce: number;
  } | null>(null);
  const combatNonceRef = useRef(0);
  const hitStopTimerRef = useRef<NodeJS.Timeout | null>(null);
  const [breachProgress, setBreachProgress] = useState(0);
  const [monsterHp, setMonsterHp] = useState(1000);
  const [bossFightActive, setBossFightActive] = useState(false);
  const [lastHitNonce, setLastHitNonce] = useState(0);
  const [lastHitDamage, setLastHitDamage] = useState(0);
  const [playerPosition, setPlayerPosition] = useState<Vector3>(
    () => new Vector3(0, 0, 10.8),
  );
  const breachStartedRef = useRef(false);
  const breachShatterPlayedRef = useRef(false);
  const breachRoarPlayedRef = useRef(false);

  useEffect(() => () => {
    if (hitStopTimerRef.current) clearTimeout(hitStopTimerRef.current);
    if (typeof window !== 'undefined') (window as any).__11_11_TIME_SCALE = 1.0;
  }, []);

  // Proximity-based containment breach trigger & animation
  const handlePositionUpdate = useCallback((pos: Vector3) => {
    setPlayerPosition(pos.clone());
    // Deep containment vault entrance: x > 6.5 and z < -3.5, OR deep corridor quarantine z < -5.0
    if (OPENING_COMBAT_STUDY_ENABLED && !breachStartedRef.current && ((pos.x > 6.5 && pos.z < -3.5) || pos.z < -5.0)) {
      breachStartedRef.current = true;
      setBossFightActive(true);
    }
  }, []);

  useEffect(() => {
    if (!bossFightActive) return;
    let animId: number;
    const startTime = performance.now();
    const duration = 3600; // 3.6s dramatic breach sequence

    const tick = (now: number) => {
      const elapsed = now - startTime;
      const progress = Math.min(1, elapsed / duration);
      setBreachProgress(progress);

      if (progress >= 0.55 && !breachShatterPlayedRef.current) {
        breachShatterPlayedRef.current = true;
        playCue('glassShatter', { volume: 0.85 });
      }
      if (progress >= 0.70 && !breachRoarPlayedRef.current) {
        breachRoarPlayedRef.current = true;
        playCue('monsterRoar', { volume: 0.9 });
      }

      if (progress < 1) {
        animId = requestAnimationFrame(tick);
      }
    };
    animId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(animId);
  }, [bossFightActive, playCue]);

  const handlePunch = useCallback(() => {
    if (!inputEnabled) return;
    combatNonceRef.current += 1;
    setCombatAction({ type: 'punch', nonce: combatNonceRef.current });
    playCue('punch', { volume: 0.55 });
  }, [inputEnabled, playCue]);

  const handleKick = useCallback(() => {
    if (!inputEnabled) return;
    combatNonceRef.current += 1;
    setCombatAction({ type: 'kick', nonce: combatNonceRef.current });
    playCue('kick', { volume: 0.65 });
  }, [inputEnabled, playCue]);

  const handleDodge = useCallback(() => {
    if (!inputEnabled) return;
    combatNonceRef.current += 1;
    setCombatAction({ type: 'dodge', nonce: combatNonceRef.current });
    playCue('dodge', { volume: 0.45 });
  }, [inputEnabled, playCue]);

  const handleAttack = useCallback(() => {
    if (!inputEnabled) return;
    combatNonceRef.current += 1;
    if (hasWeapon) {
      setCombatAction({ type: 'slash', nonce: combatNonceRef.current });
      playCue('slash', { volume: 0.55 });
    } else {
      setCombatAction({ type: 'punch', nonce: combatNonceRef.current });
      playCue('punch', { volume: 0.55 });
    }
  }, [hasWeapon, inputEnabled, playCue]);

  const handleHitTarget = useCallback((damage: number, impactPos: Vector3, reach = 1.5, attackType = 'punch') => {
    if (!bossFightActive) return;
    const monsterX = 11.0;
    const monsterZ = -8.5;
    const monsterRadius = 0.85;

    const monsterDirX = monsterX - playerPosition.x;
    const monsterDirZ = monsterZ - playerPosition.z;
    const distToCenter = Math.hypot(monsterDirX, monsterDirZ);

    // Directional alignment: player must be facing within ~60 degrees of monster
    const playerYaw = playerRef.current?.rotation.y ?? 0;
    const forwardX = Math.sin(playerYaw);
    const forwardZ = Math.cos(playerYaw);
    const facingDot = (forwardX * monsterDirX + forwardZ * monsterDirZ) / Math.max(0.001, distToCenter);

    // Physical reach boundary check: strike tip must reach monster cylinder boundary
    const distToBoundary = distToCenter - monsterRadius;
    const inReach = distToBoundary <= reach;
    const isFacing = facingDot >= 0.45;

    if (inReach && isFacing) {
      // DIRECT PHYSICAL CONTACT HIT
      playCue('hitImpact', { volume: 0.8 });
      cameraTraumaRef.current = Math.min(1.0, cameraTraumaRef.current + 0.6);
      setLastHitNonce((prev) => prev + 1);
      setLastHitDamage(damage);
      setMonsterHp((prev) => Math.max(0, prev - damage));
      const isCrit = damage >= 125;
      combatEffectsRef.current?.triggerHit(impactPos, damage, isCrit);

      // Hit Stop (Time Freeze)
      if (typeof window !== 'undefined') {
        if (hitStopTimerRef.current) clearTimeout(hitStopTimerRef.current);
        (window as any).__11_11_TIME_SCALE = 0.05;
        hitStopTimerRef.current = setTimeout(() => {
          (window as any).__11_11_TIME_SCALE = 1.0;
          hitStopTimerRef.current = null;
        }, isCrit ? 60 : 40);
      }
    } else {
      // WHIFF / AIR SWING (Physical miss: zero damage, monster unaffected)
      playCue('whoosh', { volume: 0.4 });
    }
  }, [bossFightActive, playCue, playerPosition.x, playerPosition.z]);

  const handleMonsterAttack = useCallback((damage: number) => {
    if (playerRef.current?.userData.isInvulnerable) {
      // PERFECT DODGE
      playCue('dodge', { volume: 0.9 });
      if (typeof window !== 'undefined') {
        if (hitStopTimerRef.current) clearTimeout(hitStopTimerRef.current);
        (window as any).__11_11_TIME_SCALE = 0.2;
        hitStopTimerRef.current = setTimeout(() => {
          (window as any).__11_11_TIME_SCALE = 1.0;
          hitStopTimerRef.current = null;
        }, 500);
      }
      return;
    }
    playCue('hitImpact', { volume: 0.7 });
    cameraTraumaRef.current = Math.min(1.0, cameraTraumaRef.current + 0.85);
  }, [playCue]);

  const handleMonsterDefeated = useCallback(() => {
    // Victory sequence — cinematic moment like a Genshin boss kill
    playCue('monsterRoar', { volume: 0.8 });
    // Spike camera trauma for dramatic shake
    cameraTraumaRef.current = Math.min(1.0, cameraTraumaRef.current + 1.5);

    // Slow-motion after 0.8s
    const slowTimer = setTimeout(() => {
      GLOBALS.timeScale = 0.15;

      // After 2.5s of slow-mo, restore time and trigger room completion
      const restoreTimer = setTimeout(() => {
        GLOBALS.timeScale = 1.0;
        // Trigger memory beat / room completion path
        setMemoryBeatActive(true);
      }, 2500);

      return () => clearTimeout(restoreTimer);
    }, 800);

    return () => clearTimeout(slowTimer);
  }, [playCue, setMemoryBeatActive]);



  const controls = usePlayerControls({
    enabled: inputEnabled,
    pauseEnabled: !paused,
    onInteract: handleInteract,
    onPause,
    onAttack: OPENING_COMBAT_STUDY_ENABLED ? handleAttack : undefined,
    onPunch: OPENING_COMBAT_STUDY_ENABLED ? handlePunch : undefined,
    onKick: OPENING_COMBAT_STUDY_ENABLED ? handleKick : undefined,
    onDodge: OPENING_COMBAT_STUDY_ENABLED ? handleDodge : undefined,
  });

  if (typeof window !== 'undefined') {
    (window as any).__11_11_DEBUG__ = {
      playerPosition,
      bossFightActive,
      monsterHp,
      breachProgress,
      triggerBreach: () => {
        breachStartedRef.current = true;
        setBossFightActive(true);
      },
      attackMonster: (damage = 100) => {
        handleHitTarget(damage, new Vector3(11.0, 0, -8.5));
      },
      setPlayerPos: (x: number, y: number, z: number) => {
        setPlayerPosition(new Vector3(x, y, z));
      },
    };
  }

  const interactionPrompt = useMemo(() => {
    const interaction = OPENING_ROOM_INTERACTIONS.find(
      ({ id }) => id === nearestInteractionId,
    );
    return interaction?.prompt.replace(/^E\s*—\s*/, '') ?? null;
  }, [nearestInteractionId]);

  const interactionTarget = useMemo(() => {
    const targetId = activeInteractionId ?? nearestInteractionId;
    return OPENING_ROOM_INTERACTIONS.find(({ id }) => id === targetId)
      ?.position ?? null;
  }, [activeInteractionId, nearestInteractionId]);

  const cameraConfig = useMemo<ThirdPersonCameraConfig>(() => {
    const padding = OPENING_ROOM_CONFIG.camera.collisionPadding;
    return {
      distance: 3.2,
      height: 0.78,
      // Player origin is the 0.88 m collision centre; +0.42 m frames Echo's chest.
      lookHeight: 0.42,
      followSmoothing: 22,
      pointerSensitivity: 0.0022,
      minPitch: -0.45,
      maxPitch: 0.55,
      bounds: {
        minX: OPENING_ROOM_CONFIG.bounds.min.x + padding,
        maxX: OPENING_ROOM_CONFIG.bounds.max.x - padding,
        minZ: OPENING_ROOM_CONFIG.bounds.min.z + padding,
        maxZ: OPENING_ROOM_CONFIG.bounds.max.z - padding,
        minY: 0.4,
        maxY: OPENING_ROOM_CONFIG.dimensions.height - 0.5,
      },
    };
  }, []);


  const stageCopy = PUZZLE_STAGE_COPY[puzzle.stage];
  const dpr: [number, number] = quality === 'high'
    ? [1, 2]
    : quality === 'mobile'
      ? [0.75, 1]
      : [1, 1.5];

  return (
    <div
      className="gameplay-screen"
      data-canvas-ready={canvasReady}
      data-puzzle-stage={puzzle.stage}
      data-cinematic-active={cinematicActive || awakeningHandoffActive}
      data-active-interaction={activeInteractionId ?? undefined}
    >
      {!canvasReady && (
        <div className="gameplay-loading" role="status">
          <span>CONNECTING TO OPENING ROOM</span>
          <i />
          <small>11:11</small>
        </div>
      )}

      <Canvas
        className="gameplay-canvas"
        shadows={quality !== 'mobile'}
        dpr={dpr}
        camera={{
          fov: 52,
          near: 0.08,
          far: 42,
          position: [0, 2.9, 3.1],
        }}
        gl={{
          antialias: quality !== 'mobile',
          powerPreference: 'high-performance',
          preserveDrawingBuffer: false,
          toneMapping: ACESFilmicToneMapping,
          toneMappingExposure: 0.98,
        }}
        onCreated={() => setCanvasReady(true)}
        aria-label="الغرفة الافتتاحية ثلاثية الأبعاد"
      >
        <color attach="background" args={['#010407']} />
        <fog
          attach="fog"
          args={[
            '#01070a',
            quality === 'mobile' ? 8.0 : 7.0,
            quality === 'mobile' ? 22 : 28,
          ]}
        />
        <Suspense fallback={null}>
          <SceneDebugBridge cameraYawRef={cameraYawRef} />
          <RoomLoader
            definition={OPENING_LAB_DEFINITION}
            flags={flags}
            quality={quality}
            focusedInteractionId={
              inputEnabled ? nearestInteractionId : activeInteractionId
            }
            visualEvent={visualEvent}
            hasWeapon={hasWeapon}
            onPickupWeapon={() => {
              setPickedUpWeapon(true);
              playCue('slash', { volume: 0.8 });
            }}
            breachProgress={breachProgress}
            isAgitated={bossFightActive}
            playerPos={playerPosition}
            onMonsterHpChange={(hp) => setMonsterHp(hp)}
            onMonsterAttack={handleMonsterAttack}
            onMonsterDefeated={handleMonsterDefeated}
            lastHitNonce={lastHitNonce}
            lastHitDamage={lastHitDamage}
            capsuleOpen={capsuleOpen}
          />
          <EchoPlayer
            playerRef={playerRef}
            inputRef={controls.inputRef}
            cameraYawRef={cameraYawRef}
            flags={flags}
            enabled={inputEnabled}
            paused={paused}
            cinematicLocked={cinematicActive || awakeningHandoffActive}
            cinematicPhase={awakeningPhase}
            activeInteractionId={activeInteractionId}
            interactionTarget={interactionTarget}
            hasWeapon={hasWeapon}
            combatAction={combatAction}
            onPositionUpdate={handlePositionUpdate}
            onHitTarget={handleHitTarget}
            onNearestInteractionChange={setNearestInteractionId}
            onFootstep={() => playCue('footstep', { volume: 0.18 })}
          />
          <CombatEffects ref={combatEffectsRef} />
          {quality !== 'mobile' && (
            <EffectComposer multisampling={quality === 'high' ? 4 : 0}>
              <Bloom
                intensity={1.4}
                luminanceThreshold={0.55}
                luminanceSmoothing={0.85}
                mipmapBlur
              />
              <Vignette offset={0.28} darkness={0.65} />
            </EffectComposer>
          )}
          <ThirdPersonCamera
            targetRef={playerRef}
            yawRef={cameraYawRef}
            traumaRef={cameraTraumaRef}
            enabled={cameraFollowEnabled}
            config={cameraConfig}
          />
          <InteractionCamera
            playerRef={playerRef}
            target={interactionTarget}
            active={activeInteractionId !== null}
            paused={paused}
          />
          <OpeningCinematic
            targetRef={playerRef}
            active={awakeningHandoffActive}
            paused={paused}
            reducedMotion={motion === 'reduced'}
            onAwakeningSubPhase={setAwakeningPhase}
            onComplete={() => {
              setAwakeningPhase('idle');
              setAwakeningHandoffActive(false);
            }}
          />
        </Suspense>
      </Canvas>

      <CinematicDirector
        sequence={cinematicActive ? OPENING_CINEMATIC_SEQUENCE : null}
        reducedMotion={motion === 'reduced'}
        onComplete={() => {
          markCinematicSeen();
          setCinematicActive(false);
          setCapsuleOpen(true);
          if (motion === 'reduced') {
            setAwakeningPhase('idle');
            setAwakeningHandoffActive(false);
          } else {
            setAwakeningHandoffActive(true);
          }
          playCue('capsuleRelease', { volume: 0.52 });
        }}
        onSkip={() => {
          markCinematicSeen();
          setCinematicActive(false);
          setCapsuleOpen(true);
          setAwakeningPhase('idle');
        }}
      />

      <OpeningCinematicOverlay
        active={awakeningHandoffActive}
        reducedMotion={motion === 'reduced'}
      />

      {memoryBeatActive && roomCompletionStatus === 'idle' && (
        <OpeningMemoryBeat
          reducedMotion={motion === 'reduced'}
          onComplete={() => {
            setMemoryBeatActive(false);
            void submitRoomCompletion();
          }}
        />
      )}
      {roomCompletionStatus === 'submitting' && (
        <div className="opening-room-receipt-pending" role="status">
          <span>ROOM RECEIPT // VERIFYING</span>
          <small>ثبت مسار الغرفة وحزمة الذاكرة…</small>
        </div>
      )}
      {roomCompletionStatus === 'error' && (
        <div className="opening-room-receipt-error" role="alert">
          <strong>تعذر تثبيت اجتياز الغرفة</strong>
          <span>لم يُفتح أي محتوى محليًا. أعد المحاولة لتثبيت الإيصال.</span>
          <button type="button" onClick={() => void submitRoomCompletion()}>
            إعادة المحاولة
          </button>
        </div>
      )}

      <GameplayHUD
        prompt={inputEnabled ? interactionPrompt : null}
        objective={stageCopy.objective}
        puzzleProgress={stageCopy.progress}
        showTutorial={showTutorial}
        onDismissTutorial={markControlsSeen}
        onInteract={handleInteract}
        onPause={onPause}
        setTouchDirection={controls.setTouchDirection}
        onSprintToggle={controls.toggleSprint}
        onSprintHold={controls.setSprint}
        onJumpHold={controls.setJump}
        onAttack={OPENING_COMBAT_STUDY_ENABLED ? handleAttack : undefined}
        onPunch={OPENING_COMBAT_STUDY_ENABLED ? handlePunch : undefined}
        onKick={OPENING_COMBAT_STUDY_ENABLED ? handleKick : undefined}
        onDodge={OPENING_COMBAT_STUDY_ENABLED ? handleDodge : undefined}
        hasWeapon={hasWeapon}
        bossActive={OPENING_COMBAT_STUDY_ENABLED && bossFightActive}
        monsterHp={monsterHp}
        maxMonsterHp={1000}
      />

      <NarrativeOverlay
        content={narrative}
        onClose={() => {
          if (narrativeTimerRef.current) {
            clearTimeout(narrativeTimerRef.current);
            narrativeTimerRef.current = null;
          }
          setNarrative(null);
          setActiveInteractionId(null);
          if (pendingMemoryBeat) {
            setPendingMemoryBeat(false);
            setMemoryBeatActive(true);
          }
        }}
      />
    </div>
  );
}
