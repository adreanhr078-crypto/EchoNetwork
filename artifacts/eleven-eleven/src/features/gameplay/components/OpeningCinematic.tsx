import {
  useEffect,
  useMemo,
  useRef,
  type MutableRefObject,
} from 'react';
import {
  useFrame,
  useThree,
} from '@react-three/fiber';
import {
  MathUtils,
  Vector3,
  type Group,
} from 'three';

export type CinematicPhase = 'awakening' | 'monster-breach' | null;

export interface OpeningCinematicProps {
  targetRef: MutableRefObject<Group | null>;
  monsterRef?: MutableRefObject<Group | null>;
  active: boolean;
  phase?: CinematicPhase;
  paused: boolean;
  reducedMotion: boolean;
  onComplete: () => void;
  onAwakeningSubPhase?: (subPhase: 'wakeup' | 'standup' | 'idle') => void;
  onBreachProgress?: (progress: number) => void;
}

export function OpeningCinematic({
  targetRef,
  active,
  phase = 'awakening',
  paused,
  reducedMotion,
  onComplete,
  onBreachProgress,
  onAwakeningSubPhase,
}: OpeningCinematicProps) {
  const { camera } = useThree();
  const elapsedRef = useRef(0);
  const completedRef = useRef(false);

  useEffect(() => {
    if (active) {
      elapsedRef.current = 0;
      completedRef.current = false;
    }
  }, [active, phase]);

  // Awakening Camera Trajectory (Capsule at z=13.8, Echo spawn at z=10.8)
  // Stage 1: Looking from front of capsule INTO Echo inside it (from z=7.5, looking toward z=10.8)
  const awakeFaceCloseUp = useMemo(() => new Vector3(0, 1.45, 7.5), []);
  // Stage 2: 3/4 orbit side view showing capsule opening and Echo standing up
  const awakeOrbitSide = useMemo(() => new Vector3(2.5, 1.5, 9.5), []);
  // Stage 3: Behind Echo's shoulder, looking down the brightly lit corridor (-Z)
  const awakeThirdPerson = useMemo(() => new Vector3(0.4, 1.55, 13.8), []);

  // Monster Breach Camera Trajectory Vectors
  // Close-up on the violently shaking containment pod EX-000
  const monsterPodView = useMemo(() => new Vector3(12.6, 1.6, -6.8), []);
  const monsterShatterView = useMemo(() => new Vector3(9.2, 1.2, -7.0), []);
  const monsterCombatView = useMemo(() => new Vector3(10.5, 1.6, -4.5), []);

  const desired = useMemo(() => new Vector3(), []);
  const targetPosition = useMemo(() => new Vector3(), []);
  const lookTarget = useMemo(() => new Vector3(), []);

  useFrame((_, frameDelta) => {
    if (!active || paused || completedRef.current) return;

    if (phase === 'monster-breach') {
      const duration = reducedMotion ? 2.0 : 5.8;
      elapsedRef.current += Math.min(frameDelta, 0.05);
      const progress = MathUtils.clamp(elapsedRef.current / duration, 0, 1);
      onBreachProgress?.(progress);

      // Violent camera shake during monster strikes
      const shakeMagnitude = (progress > 0.15 && progress < 0.65)
        ? Math.sin(progress * 80.0) * 0.06
        : 0;

      if (progress < 0.45) {
        // Close-up on pod as claws smash against glass
        desired.lerpVectors(monsterPodView, monsterShatterView, progress / 0.45);
        lookTarget.set(11.0, 1.85, -8.5);
      } else if (progress < 0.75) {
        // Glass shatters! Camera jerks back with explosive impact
        desired.lerpVectors(monsterShatterView, monsterCombatView, (progress - 0.45) / 0.3);
        lookTarget.set(11.0, 1.6, -8.5);
      } else {
        // Whip back behind Echo facing the emerged monster
        if (targetRef.current) {
          targetRef.current.getWorldPosition(targetPosition);
          desired.set(targetPosition.x, targetPosition.y + 1.45, targetPosition.z + 2.2);
          lookTarget.set(11.0, 1.6, -8.5);
        }
      }

      desired.x += shakeMagnitude;
      desired.y += shakeMagnitude * 0.7;
      camera.position.copy(desired);
      camera.lookAt(lookTarget);

      if (progress >= 1) {
        completedRef.current = true;
        onComplete();
      }
      return;
    }

    // Default Phase: Awakening and Capsule Exit
    const target = targetRef.current;
    if (!target) return;

    const duration = reducedMotion ? 1.5 : 4.6;
    elapsedRef.current += Math.min(frameDelta, 0.05);
    const progress = MathUtils.clamp(elapsedRef.current / duration, 0, 1);

    target.getWorldPosition(targetPosition);

    if (reducedMotion) {
      onAwakeningSubPhase?.('standup');
      desired.lerpVectors(awakeFaceCloseUp, awakeThirdPerson, MathUtils.smoothstep(progress, 0, 1));
      lookTarget.copy(targetPosition);
    } else if (progress < 0.42) {
      onAwakeningSubPhase?.('wakeup');
      // Stage 1: Close-up through stasis glass as Echo's eyes open inside pod
      desired.lerpVectors(awakeFaceCloseUp, awakeOrbitSide, MathUtils.smootherstep(progress / 0.42, 0, 1));
      lookTarget.set(targetPosition.x, targetPosition.y + 0.95, targetPosition.z);
    } else if (progress < 0.82) {
      onAwakeningSubPhase?.('standup');
      // Stage 2: Pod opens! Camera glides around Echo stepping onto the dais
      desired.lerpVectors(
        awakeOrbitSide,
        awakeThirdPerson,
        MathUtils.smootherstep((progress - 0.42) / 0.4, 0, 1),
      );
      lookTarget.set(targetPosition.x, targetPosition.y + 0.75, targetPosition.z - 0.8);
    } else {
      onAwakeningSubPhase?.('idle');
      // Stage 3: Lock behind Echo's shoulder looking down the full corridor
      desired.set(
        targetPosition.x + 0.4,
        targetPosition.y + 1.5,
        targetPosition.z + 2.8,
      );
      lookTarget.set(targetPosition.x, targetPosition.y + 0.5, targetPosition.z - 16.0);
    }

    camera.position.copy(desired);
    camera.lookAt(lookTarget);

    if (progress >= 1) {
      completedRef.current = true;
      onComplete();
    }
  });

  return null;
}

export function OpeningCinematicOverlay({
  active,
  phase = 'awakening',
  reducedMotion,
}: {
  active: boolean;
  phase?: CinematicPhase;
  reducedMotion: boolean;
}) {
  if (!active) return null;

  return (
    <div
      className={[
        'opening-cinematic-overlay',
        phase === 'monster-breach' ? 'is-monster-breach' : '',
        reducedMotion ? 'is-reduced' : '',
      ].filter(Boolean).join(' ')}
      aria-live="polite"
    >
      <span className="opening-cinematic-overlay__blackout" />
      <div className="opening-cinematic-overlay__copy">
        {phase === 'monster-breach' ? (
          <>
            <small style={{ color: '#ff2255' }}>CRITICAL BREACH // SPECIMEN EX-000</small>
            <strong style={{ color: '#ff1144', textShadow: '0 0 16px rgba(255,17,68,0.8)' }}>
              BIO-CONTAINMENT COMPROMISED
            </strong>
            <span>انهيار حاجز العزل الحيوي… احذر!</span>
          </>
        ) : (
          <>
            <small>CONSCIOUSNESS LINK // 01</small>
            <strong>11:11</strong>
            <span>استعادة قناة الإدراك… تفريغ كبسولة التجميد</span>
          </>
        )}
      </div>
      <i className="opening-cinematic-overlay__scan" />
    </div>
  );
}
