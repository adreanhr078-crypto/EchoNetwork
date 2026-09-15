import type {
  EchoAnimationState,
} from '../types/echoAnimation.types';

export interface ResolveEchoAnimationStateOptions {
  speed: number;
  sprinting: boolean;
  interactionActive: boolean;
  cinematicLocked: boolean;
  paused: boolean;
}

const WALK_THRESHOLD = 0.06;
const RUN_THRESHOLD = 2.25;

export function resolveEchoAnimationState({
  speed,
  sprinting,
  interactionActive,
  cinematicLocked,
  paused,
}: ResolveEchoAnimationStateOptions): EchoAnimationState {
  if (cinematicLocked || paused) return 'lockedByCinematic';
  if (interactionActive) return 'interact';

  const safeSpeed = Number.isFinite(speed) ? Math.max(0, speed) : 0;
  if (safeSpeed < WALK_THRESHOLD) return 'idle';
  if (sprinting || safeSpeed >= RUN_THRESHOLD) return 'run';
  return 'walk';
}

const CLIP_PATTERNS: Record<EchoAnimationState, readonly RegExp[]> = {
  idle: [/idle/i, /stand/i, /breath/i],
  walk: [/walk/i, /locomo/i],
  run: [/run/i, /sprint/i, /jog/i],
  interact: [/inspect/i, /interact/i, /reach/i],
  lockedByCinematic: [/wakeup/i, /wake/i, /standup/i, /idle/i, /stand/i, /breath/i],
};

/**
 * Resolves only names that actually exist in a supplied GLB. This keeps the
 * runtime independent of exporter-specific clip naming.
 */
export function findEchoAnimationClip(
  availableClipNames: readonly string[],
  state: EchoAnimationState,
): string | null {
  for (const pattern of CLIP_PATTERNS[state]) {
    const match = availableClipNames.find((name) => pattern.test(name));
    if (match) return match;
  }
  return state === 'idle' || state === 'lockedByCinematic'
    ? availableClipNames[0] ?? null
    : null;
}
