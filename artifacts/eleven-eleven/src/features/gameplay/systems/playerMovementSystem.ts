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

export interface HorizontalVelocity {
  readonly x: number;
  readonly z: number;
}

export interface IntegrateHorizontalVelocityOptions {
  readonly velocity: HorizontalVelocity;
  readonly input: PlayerMovementInput;
  readonly deltaSeconds: number;
  readonly facingYawRadians?: number;
  readonly movement: PlayerMovementConfig;
  readonly acceleration?: number;
  readonly deceleration?: number;
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

  if (safeDeltaSeconds === 0) return start;
  const velocity = integrateHorizontalVelocity({
    velocity: { x: 0, z: 0 },
    input,
    deltaSeconds: 1,
    facingYawRadians,
    movement,
    acceleration: Number.POSITIVE_INFINITY,
    deceleration: Number.POSITIVE_INFINITY,
  });
  return movePlayerByVelocity({
    position: start,
    velocity,
    deltaSeconds: safeDeltaSeconds,
    roomBounds,
    obstacles,
    movement,
  });
}

export function integrateHorizontalVelocity({
  velocity,
  input,
  deltaSeconds,
  facingYawRadians = 0,
  movement,
  acceleration = 18,
  deceleration = 24,
}: IntegrateHorizontalVelocityOptions): HorizontalVelocity {
  const delta = Math.max(0, finiteOrZero(deltaSeconds));
  const moveRight = Number(input.right) - Number(input.left);
  const moveForward = Number(input.forward) - Number(input.backward);
  const inputLength = Math.hypot(moveRight, moveForward);
  const hasInput = inputLength > 0;
  const normRight = hasInput ? moveRight / inputLength : 0;
  const normForward = hasInput ? moveForward / inputLength : 0;
  const yaw = finiteOrZero(facingYawRadians);
  const speed = Math.max(0, finiteOrZero(
    input.sprint ? movement.sprintSpeed : movement.walkSpeed,
  ));
  const targetX = hasInput
    ? (normRight * Math.cos(yaw) - normForward * Math.sin(yaw)) * speed
    : 0;
  const targetZ = hasInput
    ? (normRight * -Math.sin(yaw) - normForward * Math.cos(yaw)) * speed
    : 0;
  const sharpness = hasInput ? acceleration : deceleration;
  const alpha = Number.isFinite(sharpness)
    ? 1 - Math.exp(-Math.max(0, sharpness) * delta)
    : 1;

  return {
    x: finiteOrZero(velocity.x) + (targetX - finiteOrZero(velocity.x)) * alpha,
    z: finiteOrZero(velocity.z) + (targetZ - finiteOrZero(velocity.z)) * alpha,
  };
}

export function movePlayerByVelocity({
  position,
  velocity,
  deltaSeconds,
  roomBounds,
  obstacles,
  movement,
}: {
  readonly position: Vector3;
  readonly velocity: HorizontalVelocity;
  readonly deltaSeconds: number;
  readonly roomBounds: RoomBounds;
  readonly obstacles: readonly CollisionObstacle[];
  readonly movement: PlayerMovementConfig;
}): Vector3 {
  const start = clampToRoomBounds(position, roomBounds, movement.halfExtents);
  const delta = Math.max(0, finiteOrZero(deltaSeconds));

  const movedOnX = moveAlongAxis(
    start,
    'x',
    finiteOrZero(velocity.x) * delta,
    movement.halfExtents,
    roomBounds,
    obstacles,
  );

  const movedOnZ = moveAlongAxis(
    movedOnX,
    'z',
    finiteOrZero(velocity.z) * delta,
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
