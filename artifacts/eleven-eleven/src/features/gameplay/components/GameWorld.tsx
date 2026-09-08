import {
  Suspense,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { Canvas } from '@react-three/fiber';
import type { Group } from 'three';
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

export function GameWorld({
  paused,
  quality,
  motion,
  onPause,
  onRoomComplete,
}: GameWorldProps) {
  const playerRef = useRef<Group | null>(null);
  const cameraYawRef = useRef(0);
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
  const { playCue } = useGameplayAudio();
  const showTutorial = !controlsSeen && !cinematicActive;

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

  const controls = usePlayerControls({
    enabled: !paused
      && !cinematicActive
      && !showTutorial
      && !memoryBeatActive
      && roomCompletionStatus !== 'submitting'
      && roomCompletionStatus !== 'completed'
      && narrative === null
      && activeInteractionId === null,
    pauseEnabled: !paused,
    onInteract: handleInteract,
    onPause,
  });

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
      distance: OPENING_ROOM_CONFIG.camera.positionOffset.z,
      height: OPENING_ROOM_CONFIG.camera.positionOffset.y,
      lookHeight: OPENING_ROOM_CONFIG.camera.targetOffset.y,
      followSmoothing: OPENING_ROOM_CONFIG.camera.followSharpness,
      pointerSensitivity: 0.003,
      minPitch: -0.18,
      maxPitch: 0.28,
      bounds: {
        minX: OPENING_ROOM_CONFIG.bounds.min.x + padding,
        maxX: OPENING_ROOM_CONFIG.bounds.max.x - padding,
        minZ: OPENING_ROOM_CONFIG.bounds.min.z + padding,
        maxZ: OPENING_ROOM_CONFIG.bounds.max.z - padding,
        minY: 0.9,
        maxY: OPENING_ROOM_CONFIG.dimensions.height - 0.18,
      },
    };
  }, []);

  const stageCopy = PUZZLE_STAGE_COPY[puzzle.stage];
  const inputEnabled = !paused
    && !cinematicActive
    && !showTutorial
    && !memoryBeatActive
    && roomCompletionStatus !== 'submitting'
    && roomCompletionStatus !== 'completed'
    && narrative === null
    && activeInteractionId === null;
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
      data-cinematic-active={cinematicActive}
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
          fov: 54,
          near: 0.08,
          far: 42,
          position: [0, 2.9, 3.1],
        }}
        gl={{
          antialias: quality !== 'mobile',
          powerPreference: 'high-performance',
        }}
        onCreated={() => setCanvasReady(true)}
        aria-label="الغرفة الافتتاحية ثلاثية الأبعاد"
      >
        <color attach="background" args={['#010407']} />
        <fog
          attach="fog"
          args={[
            '#01070a',
            quality === 'mobile' ? 6.5 : 5.4,
            quality === 'mobile' ? 14 : 12,
          ]}
        />
        <Suspense fallback={null}>
          <RoomLoader
            definition={OPENING_LAB_DEFINITION}
            flags={flags}
            quality={quality}
            focusedInteractionId={
              inputEnabled ? nearestInteractionId : activeInteractionId
            }
            visualEvent={visualEvent}
          />
          <EchoPlayer
            playerRef={playerRef}
            inputRef={controls.inputRef}
            cameraYawRef={cameraYawRef}
            flags={flags}
            enabled={inputEnabled}
            paused={paused}
            cinematicLocked={cinematicActive}
            activeInteractionId={activeInteractionId}
            interactionTarget={interactionTarget}
            onNearestInteractionChange={setNearestInteractionId}
            onFootstep={() => playCue('footstep', { volume: 0.18 })}
          />
          <ThirdPersonCamera
            targetRef={playerRef}
            yawRef={cameraYawRef}
            enabled={inputEnabled}
            config={cameraConfig}
          />
          <InteractionCamera
            playerRef={playerRef}
            target={interactionTarget}
            active={activeInteractionId !== null}
            paused={paused}
          />
        </Suspense>
      </Canvas>

      <CinematicDirector
        sequence={cinematicActive ? OPENING_CINEMATIC_SEQUENCE : null}
        reducedMotion={motion === 'reduced'}
        onComplete={() => {
          markCinematicSeen();
          setCinematicActive(false);
        }}
        onSkip={() => {
          markCinematicSeen();
          setCinematicActive(false);
        }}
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
