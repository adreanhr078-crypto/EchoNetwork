import type { Vector3 } from '../types/gameplay.types';

// One spatial contract for rendered evidence, focus lights and interaction range.
// Door anchor is the reachable control panel, not the center of the tall vault.
export const OPENING_ROOM_ANCHORS = {
  clock: { x: 3.8, y: 1.85, z: 2 },
  photo: { x: 6.8, y: 1.15, z: 6.5 },
  door: { x: 0, y: 1.3, z: -13.85 },
} as const;

export function anchorTuple(point: Vector3): [number, number, number] {
  return [point.x, point.y, point.z];
}
