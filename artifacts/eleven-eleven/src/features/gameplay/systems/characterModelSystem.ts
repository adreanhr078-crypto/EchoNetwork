import type { Vector3 } from '../types/gameplay.types';

export interface CharacterModelBounds {
  readonly min: Vector3;
  readonly max: Vector3;
}

export interface CharacterModelFit {
  readonly scale: number;
  readonly offset: Vector3;
}

export function resolveCharacterModelFit(
  bounds: CharacterModelBounds,
  targetHeight: number,
): CharacterModelFit {
  const width = bounds.max.x - bounds.min.x;
  const height = bounds.max.y - bounds.min.y;
  const depth = bounds.max.z - bounds.min.z;
  const validBounds = [width, height, depth, targetHeight]
    .every((value) => Number.isFinite(value) && value > 0);

  if (!validBounds) {
    return { scale: 1, offset: { x: 0, y: 0, z: 0 } };
  }

  return {
    scale: targetHeight / height,
    offset: {
      x: -(bounds.min.x + bounds.max.x) / 2,
      y: -bounds.min.y,
      z: -(bounds.min.z + bounds.max.z) / 2,
    },
  };
}
