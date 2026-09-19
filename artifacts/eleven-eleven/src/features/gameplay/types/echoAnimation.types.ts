import type { MutableRefObject } from 'react';

export type EchoAnimationState =
  | 'idle'
  | 'walk'
  | 'run'
  | 'interact'
  | 'lockedByCinematic'
  | 'wakeup'
  | 'standup'
  | 'punch1'
  | 'punch2'
  | 'kick'
  | 'slash'
  | 'dodge';

export interface EchoVisualState {
  state: EchoAnimationState;
  speed: number;
  speedNormalized: number;
  sprinting: boolean;
  frozen: boolean;
  lookYaw: number;
  turnLean: number;
  attackActive: boolean;
  attackType: 'punch1' | 'punch2' | 'kick' | 'slash' | 'dodge' | null;
  attackProgress: number;
}

export type EchoVisualStateRef = MutableRefObject<EchoVisualState>;

export const INITIAL_ECHO_VISUAL_STATE: EchoVisualState = {
  state: 'lockedByCinematic',
  speed: 0,
  speedNormalized: 0,
  sprinting: false,
  frozen: true,
  lookYaw: 0,
  turnLean: 0,
  attackActive: false,
  attackType: null,
  attackProgress: 0,
};
