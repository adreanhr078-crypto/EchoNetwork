import type {
  Aabb,
  CollisionObstacle,
  PlayerMovementConfig,
  PlayerMovementInput,
  RoomBounds,
  Vector3,
} from '../types/gameplay.types';

export interface MovePlayerOptions {
  readonly position: Vector3;
  readonly input: PlayerMovementInput;
  readonly deltaSeconds: number;
  readonly facingYawRadians?: number;
  readonly roomBounds: RoomBounds;
  readonly obstacles: readonly CollisionObstacle[];
  readonly movement: PlayerMovementConfig;
}

type HorizontalAxis = 'x' | 'z';

const COLLISION_EPSILON = 1e-9;

function finiteOrZero(value: number): number {
  return Number.isFinite(value) ? value : 0;
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(Math.max(value, minimum), maximum);
}

function overlaps(
  minimumA: number,
  maximumA: number,
  minimumB: number,
  maximumB: number,
): boolean {
  return maximumA > minimumB + COLLISION_EPSILON
    && minimumA < maximumB - COLLISION_EPSILON;
}

function positionAabb(
  position: Vector3,
  halfExtents: Vector3,
): Aabb {
  return {
    min: {
      x: position.x - halfExtents.x,
      y: position.y - halfExtents.y,
      z: position.z - halfExtents.z,
    },
    max: {
      x: position.x + halfExtents.x,
      y: position.y + halfExtents.y,
      z: position.z + halfExtents.z,
    },
  };
}

function overlapsOnOtherAxes(
  position: Vector3,
  halfExtents: Vector3,
  obstacle: CollisionObstacle,
  movementAxis: HorizontalAxis,
): boolean {
  const player = positionAabb(position, halfExtents);
  const overlapsVertically = overlaps(
    player.min.y,
    player.max.y,
    obstacle.min.y,
    obstacle.max.y,
  );

  if (!overlapsVertically) return false;

  if (movementAxis === 'x') {
    return overlaps(
      player.min.z,
      player.max.z,
      obstacle.min.z,
      obstacle.max.z,
    );
  }

  return overlaps(
    player.min.x,
    player.max.x,
    obstacle.min.x,
    obstacle.max.x,
  );
}

function moveAlongAxis(
  position: Vector3,
  movementAxis: HorizontalAxis,
  distance: number,
  halfExtents: Vector3,
  roomBounds: RoomBounds,
  obstacles: readonly CollisionObstacle[],
): Vector3 {
  if (distance === 0) return position;

  const extent = halfExtents[movementAxis];
  const minimum = roomBounds.min[movementAxis] + extent;
  const maximum = roomBounds.max[movementAxis] - extent;
  const start = position[movementAxis];
  let target = clamp(start + distance, minimum, maximum);

  for (const obstacle of obstacles) {
    if (!overlapsOnOtherAxes(
      position,
      halfExtents,
      obstacle,
      movementAxis,
    )) {
      continue;
    }

    if (distance > 0) {
      const stoppingPoint = obstacle.min[movementAxis] - extent;
      if (start <= stoppingPoint + 0.05) {
        target = Math.min(target, stoppingPoint);
      } else if (start < obstacle.max[movementAxis] + extent) {
        // Player is penetrating: firmly clamp back outside the obstacle near face
        target = Math.min(target, stoppingPoint);
      }
    } else {
      const stoppingPoint = obstacle.max[movementAxis] + extent;
      if (start >= stoppingPoint - 0.05) {
        target = Math.max(target, stoppingPoint);
      } else if (start > obstacle.min[movementAxis] - extent) {
        // Player is penetrating: firmly clamp back outside the obstacle near face
        target = Math.max(target, stoppingPoint);
      }
    }
  }

  return {
    ...position,
    [movementAxis]: target,
  };
}

export function resolveObstaclePenetration(
  position: Vector3,
  halfExtents: Vector3,
  obstacles: readonly CollisionObstacle[],
  roomBounds: RoomBounds,
): Vector3 {
  let resolved = { ...position };

  for (let iteration = 0; iteration < 2; iteration++) {
    for (const obstacle of obstacles) {
      if (!aabbsIntersect(positionAabb(resolved, halfExtents), obstacle)) {
        continue;
      }

      const pushLeft = obstacle.min.x - halfExtents.x - resolved.x;
      const pushRight = obstacle.max.x + halfExtents.x - resolved.x;
      const pushBack = obstacle.min.z - halfExtents.z - resolved.z;
      const pushForward = obstacle.max.z + halfExtents.z - resolved.z;

      const minXPush = Math.abs(pushLeft) < Math.abs(pushRight) ? pushLeft : pushRight;
      const minZPush = Math.abs(pushBack) < Math.abs(pushForward) ? pushBack : pushForward;

      if (Math.abs(minXPush) < Math.abs(minZPush)) {
        resolved.x += minXPush;
      } else {
        resolved.z += minZPush;
      }
    }
  }

  return clampToRoomBounds(resolved, roomBounds, halfExtents);
}

export function createAabb(
  position: Vector3,
  halfExtents: Vector3,
): Aabb {
  return positionAabb(position, halfExtents);
}

export function aabbsIntersect(first: Aabb, second: Aabb): boolean {
  return overlaps(first.min.x, first.max.x, second.min.x, second.max.x)
    && overlaps(first.min.y, first.max.y, second.min.y, second.max.y)
    && overlaps(first.min.z, first.max.z, second.min.z, second.max.z);
}

export function collidesWithObstacle(
  position: Vector3,
  halfExtents: Vector3,
  obstacles: readonly CollisionObstacle[],
): boolean {
  const playerBounds = positionAabb(position, halfExtents);
  return obstacles.some((obstacle) => (
    aabbsIntersect(playerBounds, obstacle)
  ));
}

export function clampToRoomBounds(
  position: Vector3,
  roomBounds: RoomBounds,
  halfExtents: Vector3,
): Vector3 {
  return {
    x: clamp(
      position.x,
      roomBounds.min.x + halfExtents.x,
      roomBounds.max.x - halfExtents.x,
    ),
    y: clamp(
      position.y,
      roomBounds.min.y + halfExtents.y,
      roomBounds.max.y - halfExtents.y,
    ),
    z: clamp(
      position.z,
      roomBounds.min.z + halfExtents.z,
      roomBounds.max.z - halfExtents.z,
    ),
  };
}

export function movePlayer({
  position,
  input,
  deltaSeconds,
  facingYawRadians = 0,
  roomBounds,
  obstacles,
  movement,
}: MovePlayerOptions): Vector3 {
  const start = clampToRoomBounds(
    position,
    roomBounds,
    movement.halfExtents,
  );
  const safeDeltaSeconds = Math.max(0, finiteOrZero(deltaSeconds));

  const moveRight = Number(input.right) - Number(input.left);
  const moveForward = Number(input.forward) - Number(input.backward);
  const inputLength = Math.hypot(moveRight, moveForward);
  if (inputLength === 0 || safeDeltaSeconds === 0) return start;

  const normRight = moveRight / inputLength;
  const normForward = moveForward / inputLength;
  const yaw = finiteOrZero(facingYawRadians);

  // Genshin Impact 3rd-Person Camera-Relative World Direction:
  // Camera Forward in world XZ: (-sin(yaw), -cos(yaw))
  // Camera Right in world XZ:   ( cos(yaw), -sin(yaw))
  const worldX = normRight * Math.cos(yaw) - normForward * Math.sin(yaw);
  const worldZ = normRight * (-Math.sin(yaw)) - normForward * Math.cos(yaw);
  const speed = input.sprint
    ? movement.sprintSpeed
    : movement.walkSpeed;
  const distance = Math.max(0, finiteOrZero(speed)) * safeDeltaSeconds;

  const movedOnX = moveAlongAxis(
    start,
    'x',
    worldX * distance,
    movement.halfExtents,
    roomBounds,
    obstacles,
  );

  const movedOnZ = moveAlongAxis(
    movedOnX,
    'z',
    worldZ * distance,
    movement.halfExtents,
    roomBounds,
    obstacles,
  );

  return resolveObstaclePenetration(
    movedOnZ,
    movement.halfExtents,
    obstacles,
    roomBounds,
  );
}
