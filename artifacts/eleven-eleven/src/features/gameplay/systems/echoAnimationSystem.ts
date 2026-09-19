import type { EchoAnimationState } from '../types/echoAnimation.types';

export interface ResolveEchoAnimationStateOptions {
  speed: number;
  sprinting: boolean;
  interactionActive: boolean;
  cinematicLocked: boolean;
  paused: boolean;
  cinematicPhase?: 'wakeup' | 'standup' | 'idle' | null;
  attackState?: 'punch1' | 'punch2' | 'kick' | 'slash' | 'dodge' | null;
}

const WALK_THRESHOLD = 0.06;
const RUN_THRESHOLD = 2.25;

export function resolveEchoAnimationState({
  speed,
  sprinting,
  interactionActive,
  cinematicLocked,
  paused,
  cinematicPhase,
  attackState,
}: ResolveEchoAnimationStateOptions): EchoAnimationState {
  if (cinematicLocked || paused) {
    if (cinematicPhase === 'wakeup') return 'wakeup';
    if (cinematicPhase === 'standup') return 'standup';
    return 'lockedByCinematic';
  }
  if (attackState) return attackState;
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
  interact: [/look_around/i, /inspect/i, /interact/i, /reach/i],
  wakeup: [/wakeup/i, /wake/i, /idle/i, /stand/i],
  standup: [/standup/i, /stand_up/i, /arise/i, /idle/i, /stand/i],
  lockedByCinematic: [/idle/i, /stand/i, /breath/i],
  punch1: [/punch_jab/i, /punch1/i, /jab/i, /punch/i],
  punch2: [/punch_cross/i, /punch2/i, /cross/i],
  kick: [/kick_roundhouse/i, /kick/i, /roundhouse/i],
  slash: [/katana_slash/i, /slash/i, /sword/i],
  dodge: [/dodge_roll/i, /dodge/i, /roll/i],
};

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
