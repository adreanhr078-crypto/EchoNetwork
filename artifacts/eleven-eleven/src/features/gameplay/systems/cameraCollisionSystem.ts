import type { Vector3 } from '../types/gameplay.types';

export interface CameraRegionBounds {
  readonly minX: number;
  readonly maxX: number;
  readonly minZ: number;
  readonly maxZ: number;
  readonly minY: number;
  readonly maxY: number;
}

export function resolveCameraRegionBounds(
  target: Vector3,
  room: CameraRegionBounds,
): CameraRegionBounds {
  if (target.x <= 5) {
    return { ...room, maxX: Math.min(room.maxX, 4.7) };
  }

  if (target.z < -4) {
    return {
      ...room,
      minX: Math.max(room.minX, 5.2),
      maxZ: Math.min(room.maxZ, -4.3),
    };
  }
  if (target.z < 4) {
    return {
      ...room,
      minX: Math.max(room.minX, 5.2),
      minZ: Math.max(room.minZ, -3.7),
      maxZ: Math.min(room.maxZ, 3.7),
    };
  }
  return {
    ...room,
    minX: Math.max(room.minX, 5.2),
    minZ: Math.max(room.minZ, 4.3),
    maxZ: Math.min(room.maxZ, 10.7),
  };
}

export function resolveCameraArmScale(
  lookTarget: Vector3,
  arm: Vector3,
  bounds: CameraRegionBounds,
  minimumScale = 0.35,
): number {
  let scale = 1;
  const testX = lookTarget.x + arm.x;
  const testZ = lookTarget.z + arm.z;

  if (Math.abs(arm.x) > 0.001) {
    const boundary = testX < bounds.minX
      ? bounds.minX
      : testX > bounds.maxX
        ? bounds.maxX
        : null;
    if (boundary !== null) {
      const candidate = (boundary - lookTarget.x) / arm.x;
      if (candidate > 0) scale = Math.min(scale, candidate);
    }
  }
  if (Math.abs(arm.z) > 0.001) {
    const boundary = testZ < bounds.minZ
      ? bounds.minZ
      : testZ > bounds.maxZ
        ? bounds.maxZ
        : null;
    if (boundary !== null) {
      const candidate = (boundary - lookTarget.z) / arm.z;
      if (candidate > 0) scale = Math.min(scale, candidate);
    }
  }

  return Math.min(1, Math.max(minimumScale, scale));
}
