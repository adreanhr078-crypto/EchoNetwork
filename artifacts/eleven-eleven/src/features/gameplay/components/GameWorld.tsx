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
import { FloatingCompanion } from './FloatingCompanion';
import { GhostTrail } from './GhostTrail';
import { SubstationMinigame } from './SubstationMinigame';
import { EchoInternalMonologue, type MonologueEntry } from './EchoInternalMonologue';
import { getActiveSectorTask, type SectorCombatState } from '../domain/sectorStoryTasks';

export const GLOBALS = { timeScale: 1.0 };

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
  const { playCue, setBulletTimeAudio, setAdaptiveMusic } = useGameplayAudio();
  const [substationModalOpen, setSubstationModalOpen] = useState(false);
  const [substationOverridden, setSubstationOverridden] = useState(false);
  const [monologue, setMonologue] = useState<MonologueEntry | null>(null);
  const showTutorial = !controlsSeen
    && !cinematicActive
    && !awakeningHandoffActive;

  useEffect(() => {
    enterRoom();
    playCue('ambient', { loop: true, volume: 0.28 });
    playCue('systemHum', { loop: true, volume: 0.18 });
    setAdaptiveMusic('ambient');
  }, [enterRoom, playCue, setAdaptiveMusic]);

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
    ) {
      return;
    }

    // Substation terminal interaction check (Stage 11.4: requires memory recovered)
    const distToSubstation = playerPosition.distanceTo(new Vector3(9.5, 0, 2.0));
    if (distToSubstation < 1.8 && flags.openingMemoryRecovered && !substationOverridden) {
      setSubstationModalOpen(true);
      playCue('circuitClick', { volume: 0.6 });
      return;
    }

    if (!nearestInteractionId) {
      return;
    }
    const execution = executeInteraction(nearestInteractionId);
    if (!execution) return;

    if (execution.interaction.id === 'opening-clock') {
      playCue('clock', { volume: 0.45 });
      setMonologue({
        id: 'clock',
        textAr: '11:11… الساعة متجمدة. هل هذا توقيت انهيار المحطة المركزية، أم لحظة انفصالي عن الواقع؟',
        textEn: '11:11... The clock is frozen. Is this when the core collapsed, or when I broke away from reality?',
        speaker: 'ECHO // الأثر الزمني',
      });
    } else if (execution.interaction.id === 'opening-photo') {
      setMonologue({
        id: 'photo',
        textAr: '«عندما تشعر بالخوف، عُدّ حتى أحد عشر.» يوكي… هل كنتِ هنا معي؟ لا أتذكر وجهكِ، لكن صوتكِ ما زال يتردد.',
        textEn: '"When afraid, count to eleven." Yuki... Were you here with me? I cannot see your face, but your voice echoes.',
        speaker: 'ECHO // شظايا الذاكرة',
      });
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
  const [bossFightActive, setBossFightActive] = useState(false);
  const isCombatActive = bossFightActive;
  const hasWeapon = pickedUpWeapon;
  const [combatAction, setCombatAction] = useState<{
    type: 'punch' | 'kick' | 'dodge' | 'slash';
    nonce: number;
  } | null>(null);
  const combatNonceRef = useRef(0);
  const hitStopTimerRef = useRef<NodeJS.Timeout | null>(null);
  const [breachProgress, setBreachProgress] = useState(0);
  const [monsterHp, setMonsterHp] = useState(1000);
  const [lastHitNonce, setLastHitNonce] = useState(0);
  const [lastHitDamage, setLastHitDamage] = useState(0);
  const [perfectDodgeSurgeActive, setPerfectDodgeSurgeActive] = useState(false);
  const [pulseCooldown, setPulseCooldown] = useState(0);
  const [stunNonce, setStunNonce] = useState(0);
  const [stunBannerText, setStunBannerText] = useState<string | null>(null);
  const [playerPosition, setPlayerPosition] = useState<Vector3>(
    () => new Vector3(0, 0, 10.8),
  );
  // ── Monster Phase 2 & Stagger state ──────────────────────────
  const [monsterPhase, setMonsterPhase] = useState<1 | 2>(1);
  const [monsterStaggered, setMonsterStaggered] = useState(false);
  const [slamWarning, setSlamWarning] = useState(false);
  // ── Player HP, Stamina & Combo system ─────────────────────────
  const MAX_PLAYER_HP = 200;
  const MAX_PLAYER_STAMINA = 100;
  const [playerHp, setPlayerHp] = useState(MAX_PLAYER_HP);
  const [playerStamina, setPlayerStamina] = useState(MAX_PLAYER_STAMINA);
  const [comboCount, setComboCount] = useState(0);
  const [comboMultiplier, setComboMultiplier] = useState(1);
  const [damageVignette, setDamageVignette] = useState(false);
  const playerHpRef = useRef(MAX_PLAYER_HP);
  const comboTimerRef = useRef<NodeJS.Timeout | null>(null);
  const staminaRecoveryRef = useRef<NodeJS.Timeout | null>(null);
  const hpRecoveryRef = useRef<NodeJS.Timeout | null>(null);
  const breachStartedRef = useRef(false);
  const breachShatterPlayedRef = useRef(false);
  const breachRoarPlayedRef = useRef(false);

  useEffect(() => () => {
    if (hitStopTimerRef.current) clearTimeout(hitStopTimerRef.current);
    if (comboTimerRef.current) clearTimeout(comboTimerRef.current);
    if (staminaRecoveryRef.current) clearInterval(staminaRecoveryRef.current);
    if (hpRecoveryRef.current) clearInterval(hpRecoveryRef.current);
    if (typeof window !== 'undefined') (window as any).__11_11_TIME_SCALE = 1.0;
  }, []);

  // ── Slow HP regen out of combat (1 HP / 2s) ─────────────────
  useEffect(() => {
    if (bossFightActive) return;
    const id = setInterval(() => {
      setPlayerHp((prev) => {
        const next = Math.min(MAX_PLAYER_HP, prev + 1);
        playerHpRef.current = next;
        return next;
      });
    }, 2000);
    hpRecoveryRef.current = id;
    return () => clearInterval(id);
  }, [bossFightActive]);

  // Cooldown countdown for Companion Resonance Pulse
  useEffect(() => {
    if (pulseCooldown <= 0) return;
    const interval = setInterval(() => {
      setPulseCooldown((prev) => Math.max(0, prev - 0.2));
    }, 200);
    return () => clearInterval(interval);
  }, [pulseCooldown]);

  // Proximity-based containment breach trigger & animation
  const handlePositionUpdate = useCallback((pos: Vector3) => {
    setPlayerPosition(pos.clone());
    // Deep containment vault entrance: x > 6.5 and z < -3.5, OR deep corridor quarantine z < -5.0
    if (!breachStartedRef.current && ((pos.x > 6.5 && pos.z < -3.5) || pos.z < -5.0)) {
      breachStartedRef.current = true;
      setBossFightActive(true);
      setAdaptiveMusic('combat');
      setMonologue({
        id: 'breach-started',
        textAr: 'هذا ليس إنساناً… جسد مشوه وألياف عصبية متقدة. النجاة تعتمد على تفادي ضرباته والرد في اللحظة الحاسمة!',
        textEn: 'This is not human... A mutated frame and pulsing neural sinew. Survival demands dodging and striking in the split second!',
        speaker: 'ECHO // غريزة البقاء',
      });
    }
  }, [setAdaptiveMusic]);

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
    if (playerStamina < 15) {
      playCue('whoosh', { volume: 0.25 });
      return;
    }
    setPlayerStamina((prev) => Math.max(0, prev - 20));
    combatNonceRef.current += 1;
    setCombatAction({ type: 'dodge', nonce: combatNonceRef.current });
    playCue('dodge', { volume: 0.45 });
  }, [inputEnabled, playerStamina, playCue]);

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

    const facingX = -Math.sin(playerRef.current?.rotation.y ?? 0);
    const facingZ = -Math.cos(playerRef.current?.rotation.y ?? 0);
    const dot = distToCenter > 0.01 ? (facingX * monsterDirX + facingZ * monsterDirZ) / distToCenter : 1;

    const inReach = distToCenter <= (reach + monsterRadius);
    const inDirection = dot > 0.35;

    if (inReach && inDirection) {
      setLastHitNonce((prev) => prev + 1);
      let effectiveDamage = damage;
      const isSurge = perfectDodgeSurgeActive;

      // ── Combo accumulation ────────────────────────────────────
      setComboCount((prev) => {
        const next = prev + 1;
        const newMult = next >= 10 ? 3 : next >= 5 ? 2 : 1;
        setComboMultiplier(newMult);

        // Combo milestone monologues
        if (next === 5) {
          setMonologue({ id: 'combo5', textAr: 'خمس ضربات متتالية — الإيقاع في يدي!', textEn: '5-hit combo — rhythm is mine!', speaker: 'ECHO // تدفق القتال' });
        } else if (next === 10) {
          setMonologue({ id: 'combo10', textAr: 'عشر ضربات! طاقة قتالية قصوى — الآن!', textEn: '10-hit chain! Maximum combat flow — NOW!', speaker: 'ECHO // ذروة الرنين' });
        }

        // Reset combo break timer (2.5s window)
        if (comboTimerRef.current) clearTimeout(comboTimerRef.current);
        comboTimerRef.current = setTimeout(() => {
          setComboCount(0);
          setComboMultiplier(1);
        }, 2500);

        return next;
      });

      // Apply combo multiplier to damage
      if (!isSurge) {
        effectiveDamage = Math.round(damage * comboMultiplier);
      }

      // Consume 3x Perfect Dodge Surge
      if (isSurge) {
        effectiveDamage = Math.round(damage * 3.0);
        setPerfectDodgeSurgeActive(false);
        playCue('resonanceBurst', { volume: 1.0 });
      }

      // Drain stamina on attack
      setPlayerStamina((prev) => Math.max(0, prev - (attackType === 'slash' ? 12 : 6)));

      setLastHitDamage(effectiveDamage);
      setMonsterHp((prev) => Math.max(0, prev - effectiveDamage));
      const isCrit = effectiveDamage >= 125 || isSurge;
      combatEffectsRef.current?.triggerHit(impactPos, effectiveDamage, isCrit);

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
      // WHIFF / AIR SWING
      playCue('whoosh', { volume: 0.4 });
    }
  }, [bossFightActive, comboMultiplier, perfectDodgeSurgeActive, playCue, playerPosition.x, playerPosition.z]);

  const handleMonsterAttack = useCallback((damage: number) => {
    if (playerRef.current?.userData.isInvulnerable) {
      // PERFECT DODGE
      setPerfectDodgeSurgeActive(true);
      playCue('dodge', { volume: 1.0 });
      playCue('resonanceBurst', { volume: 0.95 });
      cameraTraumaRef.current = Math.min(1.0, cameraTraumaRef.current + 0.5);

      if (playerRef.current) {
        combatEffectsRef.current?.triggerResonanceWave(playerRef.current.position, 'dodge_surge');
      }

      // 1.2s Bullet-Time Dilation & Audio Filter
      if (typeof window !== 'undefined') {
        if (hitStopTimerRef.current) clearTimeout(hitStopTimerRef.current);
        (window as any).__11_11_TIME_SCALE = 0.2;
        setBulletTimeAudio(true);
        hitStopTimerRef.current = setTimeout(() => {
          (window as any).__11_11_TIME_SCALE = 1.0;
          setBulletTimeAudio(false);
          hitStopTimerRef.current = null;
        }, 1200);
      }

      setMonologue({
        id: 'perfect-dodge',
        textAr: 'تباطأ الزمن… مسار ضربته مكشوف تماماً! هجومي القادم سيحمل طاقة مضاعفة!',
        textEn: 'Time slowed down... The strike vector is wide open! My counter-surge will hit with 3x force!',
        speaker: 'ECHO // انعكاس الرنين',
      });
      return;
    }

    // ── Apply real damage ──────────────────────────────────────
    playCue('hitImpact', { volume: 0.7 });
    cameraTraumaRef.current = Math.min(1.0, cameraTraumaRef.current + 0.85);

    // Break combo on hit
    setComboCount(0);
    setComboMultiplier(1);
    if (comboTimerRef.current) { clearTimeout(comboTimerRef.current); comboTimerRef.current = null; }

    setPlayerHp((prev) => {
      const next = Math.max(0, prev - damage);
      playerHpRef.current = next;

      // Damage vignette flash
      setDamageVignette(true);
      setTimeout(() => setDamageVignette(false), 550);

      // Low HP monologue
      if (next <= 60 && prev > 60) {
        setMonologue({
          id: 'low-hp',
          textAr: 'جسدي يتداعى… يجب أن أتفادى ضرباته وأضرب بدقة أكبر!',
          textEn: 'My body is failing... I must dodge precisely and strike with more focus!',
          speaker: 'ECHO // حافة البقاء',
        });
      }

      // Death / KO
      if (next <= 0) {
        playCue('glassShatter', { volume: 0.9 });
        setAdaptiveMusic('ambient');
        cameraTraumaRef.current = 1.0;
        setMonologue({
          id: 'player-ko',
          textAr: 'سقطت… لكن الإشارة لن تنطفئ. العودة إلى نقطة التحكم.',
          textEn: 'I fell... But the signal will not die. Returning to checkpoint.',
          speaker: 'ECHO // انهيار الوعي',
        });
        // Reset HP after 2.5s (checkpoint respawn)
        setTimeout(() => {
          setPlayerHp(MAX_PLAYER_HP);
          playerHpRef.current = MAX_PLAYER_HP;
          setPlayerStamina(MAX_PLAYER_STAMINA);
        }, 2500);
      }
      return next;
    });

    // Stamina drain on hit
    setPlayerStamina((prev) => Math.max(0, prev - 18));
  }, [playCue, setBulletTimeAudio, setAdaptiveMusic]);

  const handleMonsterDefeated = useCallback(() => {
    // Victory sequence — cinematic moment like a Genshin boss kill
    playCue('monsterRoar', { volume: 0.8 });
    setAdaptiveMusic('victory');
    setMonologue({
      id: 'monster-defeated',
      textAr: 'سقط الكيان… يداي ترتجفان، لكن طريقي نحو بوابة القطاع 03 أصبح مفتوحاً بالكامل.',
      textEn: 'The entity collapsed... My hands are shaking, but the path to Sector 03 decompression is clear.',
      speaker: 'ECHO // خلاص الحجر',
    });
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
  }, [playCue, setAdaptiveMusic, setMemoryBeatActive]);

  // ── Phase 2 enrage callback ───────────────────────────────────
  const handleMonsterPhaseChange = useCallback((phase: 1 | 2) => {
    setMonsterPhase(phase);
    if (phase === 2) {
      playCue('bossEnrage', { volume: 1.0 });
      setAdaptiveMusic('combat');
      cameraTraumaRef.current = Math.min(1.0, cameraTraumaRef.current + 0.9);
      setMonologue({
        id: 'boss-phase2',
        textAr: 'تحوّل EX-000 إلى مرحلته الثانية! الطاقة الحيوية الحرجة أطلقت الهجمات الأرضية والموجات الصدمية. احذر!',
        textEn: 'EX-000 entered Phase II! Critical vitals unleashed ground slams and shockwaves. Extreme caution!',
        speaker: 'ECHO // خطر حرج',
      });
    }
  }, [playCue, setAdaptiveMusic]);

  // ── Shockwave expansion callback ─────────────────────────────
  const handleShockwave = useCallback((_pos: Vector3, _radius: number) => {
    playCue('shockwavePass', { volume: 0.85 });
    playCue('groundSlam', { volume: 0.75 });
    cameraTraumaRef.current = Math.min(1.0, cameraTraumaRef.current + 0.65);
  }, [playCue]);

  // ── Kinetic stagger callback ──────────────────────────────────
  const handleStaggerChange = useCallback((isStaggered: boolean) => {
    setMonsterStaggered(isStaggered);
    if (isStaggered) {
      playCue('watcherAlert', { volume: 0.8 });
      setMonologue({
        id: 'stagger-window',
        textAr: 'نافذة العداد الحركية مفتوحة! الضرر مضاعف خلال 3.5 ثانية — اضرب الآن!',
        textEn: 'Kinetic counter window open! Damage doubled for 3.5s — strike now!',
        speaker: 'ECHO // غريزة القتال',
      });
    }
  }, [playCue]);

  // ── Ground slam telegraph windup callback ──────────────────────
  const handleSlamWindup = useCallback((isWindup: boolean) => {
    setSlamWarning(isWindup);
    if (isWindup) {
      playCue('watcherAlert', { volume: 0.95 });
      cameraTraumaRef.current = Math.min(1.0, cameraTraumaRef.current + 0.35);
    }
  }, [playCue]);

  const handleSubstationSuccess = useCallback(() => {
    setSubstationModalOpen(false);
    setSubstationOverridden(true);
    setAdaptiveMusic('tension');
    playCue('powerSurge', { volume: 0.9 });
    setMonologue({
      id: 'substation-rerouted',
      textAr: 'تحويل الطاقة إلى البوابة سيزعزع استقرار أقفال العزل… أشعر باهتزازات غريبة في الممر الغربي.',
      textEn: 'Auxiliary power routed to blast gate... Stasis locks are destabilizing. Something is moving in the western vault.',
      speaker: 'ECHO // المونولوج الداخلي',
    });
  }, [playCue, setAdaptiveMusic]);

  const handleResonancePulse = useCallback(() => {
    if (pulseCooldown > 0 || !inputEnabled) return;
    setPulseCooldown(8.0);
    playCue('sonarPulse', { volume: 0.95 });
    cameraTraumaRef.current = Math.min(1.0, cameraTraumaRef.current + 0.35);

    if (playerRef.current) {
      combatEffectsRef.current?.triggerResonanceWave(playerRef.current.position, 'pulse');
    }

    const monsterX = 11.0;
    const monsterZ = -8.5;
    const dist = Math.hypot(monsterX - playerPosition.x, monsterZ - playerPosition.z);
    if (bossFightActive && monsterHp > 0 && dist <= 14.0) {
      setStunNonce((prev) => prev + 1);
      setStunBannerText('تم شل حركة الكيان بموجة الرنين الفوق-صوتية (2.0s)');
      setTimeout(() => {
        setStunBannerText(null);
      }, 2500);
    }
  }, [bossFightActive, inputEnabled, monsterHp, playCue, playerPosition.x, playerPosition.z, pulseCooldown]);

  const controls = usePlayerControls({
    enabled: inputEnabled,
    pauseEnabled: !paused,
    onInteract: handleInteract,
    onPause,
    onAttack: isCombatActive ? handleAttack : undefined,
    onPunch: isCombatActive ? handlePunch : undefined,
    onKick: isCombatActive ? handleKick : undefined,
    onDodge: isCombatActive ? handleDodge : undefined,
    onResonancePulse: handleResonancePulse,
  });

  // ── Stamina system (drain when sprinting, recover when resting) ──
  useEffect(() => {
    const id = setInterval(() => {
      const isMoving = Boolean(
        controls.inputRef.current?.forward ||
        controls.inputRef.current?.backward ||
        controls.inputRef.current?.left ||
        controls.inputRef.current?.right
      );
      const isSprinting = Boolean(controls.inputRef.current?.sprint && isMoving);

      if (isSprinting) {
        setPlayerStamina((prev) => {
          const next = Math.max(0, prev - 1.5);
          if (next <= 0) {
            controls.setSprint(false);
          }
          return next;
        });
      } else {
        setPlayerStamina((prev) => Math.min(MAX_PLAYER_STAMINA, prev + 1.2));
      }
    }, 100);
    staminaRecoveryRef.current = id;
    return () => clearInterval(id);
  }, [controls]);

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
    const distToSubstation = playerPosition.distanceTo(new Vector3(9.5, 0, 2.0));
    if (distToSubstation < 1.8 && flags.openingMemoryRecovered && !substationOverridden) {
      return 'تشغيل محطة تحويل الطاقة (Substation)';
    }
    const interaction = OPENING_ROOM_INTERACTIONS.find(
      ({ id }) => id === nearestInteractionId,
    );
    return interaction?.prompt.replace(/^E\s*—\s*/, '') ?? null;
  }, [flags.openingMemoryRecovered, nearestInteractionId, playerPosition, substationOverridden]);

  const interactionTarget = useMemo(() => {
    const distToSubstation = playerPosition.distanceTo(new Vector3(9.5, 0, 2.0));
    if (distToSubstation < 1.8 && flags.openingMemoryRecovered && !substationOverridden) {
      return { x: 9.5, y: 1.2, z: 2.0 };
    }
    const targetId = activeInteractionId ?? nearestInteractionId;
    return OPENING_ROOM_INTERACTIONS.find(({ id }) => id === targetId)
      ?.position ?? null;
  }, [activeInteractionId, flags.openingMemoryRecovered, nearestInteractionId, playerPosition, substationOverridden]);

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

  const combatState: SectorCombatState = useMemo(() => ({
    breachTriggered: breachStartedRef.current,
    bossActive: bossFightActive && monsterHp > 0,
    monsterHp,
    maxMonsterHp: 1000,
    monsterDefeated: monsterHp <= 0 && breachStartedRef.current,
    substationOverridden,
  }), [bossFightActive, monsterHp, substationOverridden]);

  const activeSectorTask = useMemo(() => {
    return getActiveSectorTask(flags, combatState);
  }, [flags, combatState]);

  const stageCopy = useMemo(() => ({
    objective: activeSectorTask.objectiveAr,
    progress: `${activeSectorTask.stageCode} // ${activeSectorTask.titleAr}`,
  }), [activeSectorTask]);
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
            onPhaseChange={handleMonsterPhaseChange}
            onShockwave={handleShockwave}
            onStaggerChange={handleStaggerChange}
            onSlamWindup={handleSlamWindup}
            lastHitNonce={lastHitNonce}
            lastHitDamage={lastHitDamage}
            stunNonce={stunNonce}
            stunDuration={2.0}
            combatStudyEnabled={true}
            capsuleOpen={capsuleOpen}
            substationOverridden={substationOverridden}
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
          <GhostTrail
            active={Boolean(combatAction?.type === 'dodge' || playerRef.current?.userData.isInvulnerable || controls.inputRef.current.sprint)}
            playerRef={playerRef}
            surgeActive={perfectDodgeSurgeActive}
          />
          {capsuleOpen && (
            <FloatingCompanion
              playerPosition={playerPosition}
              playerRef={playerRef}
              focusedTarget={interactionTarget}
              isAlert={bossFightActive && monsterHp > 0}
              reducedMotion={motion === 'reduced'}
              emotionOverride={
                puzzle.stage === 'exitUnlocked'
                  ? 'celebrating'
                  : bossFightActive && monsterHp > 0
                    ? 'alert'
                    : activeInteractionId
                      ? 'scanning'
                      : null
              }
            />
          )}
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
          setMonologue({
            id: 'echo-awakening',
            textAr: 'أين أنا؟ نبضات قلبي بطيئة كأنني نمت لعقود… لا أحد هنا سوى أجهزة القياس المتجمدة.',
            textEn: 'Where am I? My heartbeat is slow, as if I slept for decades... No one here but frozen telemetry.',
            speaker: 'ECHO // الوعي المستعاد',
          });
        }}
        onSkip={() => {
          markCinematicSeen();
          setCinematicActive(false);
          setCapsuleOpen(true);
          setAwakeningPhase('idle');
          setMonologue({
            id: 'echo-awakening',
            textAr: 'أين أنا؟ نبضات قلبي بطيئة كأنني نمت لعقود… لا أحد هنا سوى أجهزة القياس المتجمدة.',
            textEn: 'Where am I? My heartbeat is slow, as if I slept for decades... No one here but frozen telemetry.',
            speaker: 'ECHO // الوعي المستعاد',
          });
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

      {/* Damage Vignette — blood-red flash on hit */}
      {damageVignette && (
        <div
          aria-hidden="true"
          style={{
            position: 'fixed',
            inset: 0,
            pointerEvents: 'none',
            zIndex: 60,
            background: 'radial-gradient(ellipse at center, transparent 38%, rgba(200,0,30,0.55) 100%)',
            animation: 'damageVignetteFlash 0.55s ease-out forwards',
          }}
        />
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
        onAttack={isCombatActive ? handleAttack : undefined}
        onPunch={isCombatActive ? handlePunch : undefined}
        onKick={isCombatActive ? handleKick : undefined}
        onDodge={isCombatActive ? handleDodge : undefined}
        onResonancePulse={handleResonancePulse}
        pulseCooldown={pulseCooldown}
        perfectDodgeSurgeActive={perfectDodgeSurgeActive}
        stunBannerText={stunBannerText}
        hasWeapon={hasWeapon}
        bossActive={isCombatActive && monsterHp > 0}
        monsterHp={monsterHp}
        maxMonsterHp={1000}
        isSprinting={controls.inputRef.current?.sprint ?? false}
        playerHp={playerHp}
        maxPlayerHp={MAX_PLAYER_HP}
        playerStamina={playerStamina}
        maxPlayerStamina={MAX_PLAYER_STAMINA}
        comboCount={comboCount}
        comboMultiplier={comboMultiplier}
        echoEmotion={
          monsterHp <= 0 && isCombatActive ? 'triumph'
          : perfectDodgeSurgeActive ? 'surge'
          : playerHp <= 60 && isCombatActive ? 'hurt'
          : isCombatActive ? 'combat'
          : 'calm'
        }
        monsterPhase={monsterPhase}
        monsterStaggered={monsterStaggered}
        slamWarning={slamWarning}
        reducedMotion={motion === 'reduced'}
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

      <SubstationMinigame
        isOpen={substationModalOpen}
        onClose={() => setSubstationModalOpen(false)}
        onSuccess={handleSubstationSuccess}
        reducedMotion={motion === 'reduced'}
      />

      <EchoInternalMonologue
        monologue={monologue}
        onDismiss={() => setMonologue(null)}
        reducedMotion={motion === 'reduced'}
      />
    </div>
  );
}
