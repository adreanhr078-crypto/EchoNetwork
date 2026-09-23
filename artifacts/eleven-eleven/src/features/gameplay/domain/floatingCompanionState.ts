import { Vector3, MathUtils } from 'three';

export type FloatingCompanionEmotion =
  | 'idle'
  | 'following'
  | 'observing'
  | 'scanning'
  | 'alert'
  | 'confused'
  | 'distressed'
  | 'celebrating';

export interface FloatingCompanionConfig {
  /** Offset from Echo's position [x (lateral), y (vertical), z (forward/back)] in player local space */
  shoulderOffset: Vector3;
  /** Hover oscillation amplitude in meters */
  hoverAmplitude: number;
  /** Hover oscillation frequency in Hz */
  hoverFrequency: number;
  /** Spring follow stiffness (smoothing rate) */
  followStiffness: number;
  /** Maximum distance before companion snaps / catches up rapidly */
  maxLeashDistance: number;
  /** Rotation tracking speed */
  rotationSpeed: number;
}

export const DEFAULT_COMPANION_CONFIG: FloatingCompanionConfig = {
  shoulderOffset: new Vector3(0.65, 1.35, -0.45),
  hoverAmplitude: 0.08,
  hoverFrequency: 1.2,
  followStiffness: 6.5,
  maxLeashDistance: 5.0,
  rotationSpeed: 8.0,
};

export interface FloatingCompanionState {
  currentPosition: Vector3;
  targetPosition: Vector3;
  velocity: Vector3;
  yaw: number;
  targetYaw: number;
  pitch: number;
  roll: number;
  emotion: FloatingCompanionEmotion;
  emotionTimer: number;
  isScanning: boolean;
  scanTarget: Vector3 | null;
  observedTarget: Vector3 | null;
}

export function createInitialCompanionState(spawnPosition: Vector3): FloatingCompanionState {
  return {
    currentPosition: spawnPosition.clone().add(DEFAULT_COMPANION_CONFIG.shoulderOffset),
    targetPosition: spawnPosition.clone().add(DEFAULT_COMPANION_CONFIG.shoulderOffset),
    velocity: new Vector3(0, 0, 0),
    yaw: 0,
    targetYaw: 0,
    pitch: 0,
    roll: 0,
    emotion: 'idle',
    emotionTimer: 0,
    isScanning: false,
    scanTarget: null,
    observedTarget: null,
  };
}

/**
 * Calculates the ideal world position for the companion based on player position and orientation.
 */
export function calculateCompanionTarget(
  playerPosition: Vector3,
  playerYaw: number,
  config: FloatingCompanionConfig = DEFAULT_COMPANION_CONFIG,
  timeSec = 0,
  reducedMotion = false,
): Vector3 {
  // Rotate shoulder offset by player's yaw
  const cos = Math.cos(playerYaw);
  const sin = Math.sin(playerYaw);
  const rotatedX = config.shoulderOffset.x * cos - config.shoulderOffset.z * sin;
  const rotatedZ = config.shoulderOffset.x * sin + config.shoulderOffset.z * cos;

  // Add hovering sinusoidal oscillation
  const hoverY = reducedMotion
    ? 0
    : Math.sin(timeSec * Math.PI * 2 * config.hoverFrequency) * config.hoverAmplitude;

  const target = new Vector3(
    playerPosition.x + rotatedX,
    playerPosition.y + config.shoulderOffset.y + hoverY,
    playerPosition.z + rotatedZ,
  );

  return target;
}

/**
 * Updates companion physics and orientation over a frame delta.
 */
export function stepCompanionPhysics(
  state: FloatingCompanionState,
  targetPos: Vector3,
  deltaSec: number,
  config: FloatingCompanionConfig = DEFAULT_COMPANION_CONFIG,
  reducedMotion = false,
): void {
  const dt = MathUtils.clamp(deltaSec, 0.001, 0.1);
  state.targetPosition.copy(targetPos);

  // Leash distance check: if player teleported or moved extremely fast, snap closer
  const dist = state.currentPosition.distanceTo(targetPos);
  if (dist > config.maxLeashDistance) {
    state.currentPosition.lerp(targetPos, 0.85);
  } else {
    // Smooth spring dampening follow
    const smoothing = reducedMotion ? config.followStiffness * 1.5 : config.followStiffness;
    const lerpFactor = 1 - Math.exp(-smoothing * dt);
    state.currentPosition.lerp(targetPos, lerpFactor);
  }

  // Calculate velocity for roll/pitch tilt
  const dx = (targetPos.x - state.currentPosition.x);
  const dz = (targetPos.z - state.currentPosition.z);

  // Orientation logic:
  if (state.observedTarget) {
    // Face the observed object
    const lookAngle = Math.atan2(
      state.observedTarget.x - state.currentPosition.x,
      state.observedTarget.z - state.currentPosition.z,
    );
    state.targetYaw = lookAngle;
  } else if (dist > 0.05) {
    // Face direction of flight
    state.targetYaw = Math.atan2(dx, dz);
  }

  // Smooth yaw rotation
  const yawDiff = MathUtils.euclideanModulo(state.targetYaw - state.yaw + Math.PI, Math.PI * 2) - Math.PI;
  state.yaw += yawDiff * Math.min(1.0, config.rotationSpeed * dt);

  // Banking tilt (roll/pitch) when moving
  if (!reducedMotion) {
    state.roll = MathUtils.clamp(-dx * 0.45, -0.35, 0.35);
    state.pitch = MathUtils.clamp(dz * 0.25, -0.25, 0.25);
  } else {
    state.roll = 0;
    state.pitch = 0;
  }

  // Decay emotion timer using real elapsed time
  if (state.emotionTimer > 0) {
    state.emotionTimer -= deltaSec;
    if (state.emotionTimer <= 0) {
      state.emotion = dist > 0.15 ? 'following' : 'idle';
      state.observedTarget = null;
      state.isScanning = false;
    }
  } else {
    state.emotion = dist > 0.15 ? 'following' : 'idle';
  }
}

/**
 * Triggers an emotional / contextual state on the companion.
 */
export function triggerCompanionEmotion(
  state: FloatingCompanionState,
  emotion: FloatingCompanionEmotion,
  durationSec = 3.0,
  targetLookAt: Vector3 | null = null,
): void {
  state.emotion = emotion;
  state.emotionTimer = durationSec;
  state.observedTarget = targetLookAt ? targetLookAt.clone() : null;
  state.isScanning = emotion === 'scanning';
}
