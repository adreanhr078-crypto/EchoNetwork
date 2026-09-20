import type { EchoAnimationState } from '../types/echoAnimation.types';
import type { AnimationClip, KeyframeTrack } from 'three';

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

function isHipPositionTrack(track: KeyframeTrack): boolean {
  return /(?:^|[./|])(?:mixamorig)?hips\.position$/i.test(track.name)
    && track.getValueSize() === 3;
}

/**
 * Repairs the current export's leaked crouch offset in IDLE and lateral
 * translation in STANDUP. This rig's root maps local Z to world up.
 * Other clips, rotations, and the original cached clips remain untouched.
 */
export function normalizeImportedHipTranslation(
  clips: readonly AnimationClip[],
  bindHipPosition: readonly [number, number, number],
): AnimationClip[] {
  return clips.map((sourceClip) => {
    const clip = sourceClip.clone();
    const clipName = clip.name.toUpperCase();
    if (!bindHipPosition.every(Number.isFinite)
      || !['IDLE', 'STANDUP'].includes(clipName)) {
      return clip;
    }

    const track = clip.tracks.find(isHipPositionTrack);
    if (!track || track.values.length < 3 || track.times.length === 0) {
      return clip;
    }

    const first = Array.from(track.values.slice(0, 3));
    const last = Array.from(track.values.slice(-3));
    const firstTime = track.times[0];
    const lastTime = track.times[track.times.length - 1];
    const timeSpan = lastTime - firstTime;

    for (let frame = 0; frame < track.times.length; frame += 1) {
      const valueIndex = frame * 3;
      const progress = timeSpan > 0
        ? (track.times[frame] - firstTime) / timeSpan
        : 1;
      const axes = clipName === 'IDLE' ? 3 : 2;
      for (let axis = 0; axis < axes; axis += 1) {
        const baseline = clipName === 'STANDUP'
          ? first[axis] + (last[axis] - first[axis]) * progress
          : first[axis];
        track.values[valueIndex + axis] += bindHipPosition[axis] - baseline;
      }
    }

    return clip;
  });
}

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

export interface FootstepProgress {
  readonly phase: number;
  readonly emittedSteps: number;
}

const WALK_STEP_DISTANCE = 1.03;
const SPRINT_STEP_DISTANCE = 1.46;
const WALK_CLIP_DURATION_SECONDS = 31 / 24;
const RUN_CLIP_DURATION_SECONDS = 19 / 24;

export function advanceFootstepPhase(
  phase: number,
  travelledDistance: number,
  sprinting: boolean,
): FootstepProgress {
  const safePhase = Number.isFinite(phase)
    ? Math.max(0, phase % 1)
    : 0;
  const safeDistance = Number.isFinite(travelledDistance)
    ? Math.max(0, travelledDistance)
    : 0;
  const distancePerStep = sprinting
    ? SPRINT_STEP_DISTANCE
    : WALK_STEP_DISTANCE;
  const totalPhase = safePhase + safeDistance / distancePerStep;
  const emittedSteps = Math.floor(totalPhase);

  return {
    phase: totalPhase - emittedSteps,
    emittedSteps,
  };
}

export function resolveLocomotionPlaybackScale(
  speed: number,
  state: 'walk' | 'run',
): number {
  const safeSpeed = Number.isFinite(speed) ? Math.max(0, speed) : 0;
  const stepDistance = state === 'run'
    ? SPRINT_STEP_DISTANCE
    : WALK_STEP_DISTANCE;
  const clipDuration = state === 'run'
    ? RUN_CLIP_DURATION_SECONDS
    : WALK_CLIP_DURATION_SECONDS;
  const nominalClipSpeed = (stepDistance * 2) / clipDuration;
  return Math.min(1.75, Math.max(0.65, safeSpeed / nominalClipSpeed));
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
