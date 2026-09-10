import {
  useRef,
  type MutableRefObject,
} from 'react';
import { useFrame } from '@react-three/fiber';
import {
  MathUtils,
  Vector3,
  type Group,
} from 'three';
import { OPENING_ROOM_CONFIG } from '../data/openingRoom.config';
import type {
  OpeningRoomNarrativeFlags,
} from '../systems/puzzleSystem';
import { movePlayer } from '../systems/playerMovementSystem';
import { useInteraction } from '../hooks/useInteraction';
import type {
  PlayerControlsSnapshot,
} from '../hooks/usePlayerControls';
import { EchoAvatar } from './EchoAvatar';
import {
  INITIAL_ECHO_VISUAL_STATE,
} from '../types/echoAnimation.types';
import {
  resolveEchoAnimationState,
} from '../systems/echoAnimationSystem';
import type {
  Vector3 as GameplayVector3,
} from '../types/gameplay.types';

interface EchoPlayerProps {
  playerRef: MutableRefObject<Group | null>;
  inputRef: MutableRefObject<PlayerControlsSnapshot>;
  cameraYawRef: MutableRefObject<number>;
  flags: OpeningRoomNarrativeFlags;
  enabled: boolean;
  paused: boolean;
  cinematicLocked: boolean;
  activeInteractionId: string | null;
  interactionTarget: GameplayVector3 | null;
  onNearestInteractionChange: (interactionId: string | null) => void;
  onFootstep: () => void;
}

export function EchoPlayer({
  playerRef,
  inputRef,
  cameraYawRef,
  flags,
  enabled,
  paused,
  cinematicLocked,
  activeInteractionId,
  interactionTarget,
  onNearestInteractionChange,
  onFootstep,
}: EchoPlayerProps) {
  const visualStateRef = useRef({ ...INITIAL_ECHO_VISUAL_STATE });
  const footstepElapsedRef = useRef(0);
  const lastPositionRef = useRef(new Vector3());
  const initializedPositionRef = useRef(false);

  const velocityYRef = useRef(0);

  useInteraction({
    playerRef,
    context: { flags },
    enabled,
    onNearestChange: onNearestInteractionChange,
  });

  useFrame((_, frameDelta) => {
    const player = playerRef.current;
    if (!player) return;

    if (!initializedPositionRef.current) {
      lastPositionRef.current.copy(player.position);
      initializedPositionRef.current = true;
    }

    if (!enabled) {
      const visual = visualStateRef.current;
      visual.speed = MathUtils.damp(visual.speed, 0, 12, frameDelta);
      visual.speedNormalized = MathUtils.damp(
        visual.speedNormalized,
        0,
        10,
        frameDelta,
      );
      visual.sprinting = false;
      visual.frozen = paused;
      visual.state = resolveEchoAnimationState({
        speed: visual.speed,
        sprinting: false,
        interactionActive: activeInteractionId !== null,
        cinematicLocked,
        paused,
      });
      if (interactionTarget) {
        const targetYaw = Math.atan2(
          interactionTarget.x - player.position.x,
          interactionTarget.z - player.position.z,
        );
        const relativeYaw = MathUtils.euclideanModulo(
          targetYaw - player.rotation.y + Math.PI,
          Math.PI * 2,
        ) - Math.PI;
        visual.lookYaw = MathUtils.clamp(relativeYaw, -0.72, 0.72);
      } else {
        visual.lookYaw = MathUtils.damp(
          visual.lookYaw,
          0,
          7,
          frameDelta,
        );
      }
      footstepElapsedRef.current = 0;
      return;
    }

    const delta = Math.min(frameDelta, 0.05);
    const current = player.position;
    const next = movePlayer({
      position: {
        x: current.x,
        y: current.y,
        z: current.z,
      },
      input: inputRef.current,
      deltaSeconds: delta,
      facingYawRadians: cameraYawRef.current,
      roomBounds: OPENING_ROOM_CONFIG.bounds,
      obstacles: OPENING_ROOM_CONFIG.obstacles,
      movement: OPENING_ROOM_CONFIG.movement,
    });

    const floorY = OPENING_ROOM_CONFIG.bounds.min.y + OPENING_ROOM_CONFIG.movement.halfExtents.y;
    const ceilingY = OPENING_ROOM_CONFIG.bounds.max.y - OPENING_ROOM_CONFIG.movement.halfExtents.y;
    const isGrounded = current.y <= floorY + 0.001;
    if (isGrounded && inputRef.current.jump) {
      velocityYRef.current = 4.5;
    }
    
    velocityYRef.current -= 12.0 * delta; // specific gravity
    let nextY = current.y + velocityYRef.current * delta;

    if (nextY <= floorY) {
      nextY = floorY;
      velocityYRef.current = 0;
    }
    if (nextY >= ceilingY) {
      nextY = ceilingY;
      velocityYRef.current = Math.min(velocityYRef.current, 0);
    }

    const deltaX = next.x - current.x;
    const deltaZ = next.z - current.z;
    const isMoving = Math.abs(deltaX) + Math.abs(deltaZ) > 0.00001;
    const isJumpingOrFalling = Math.abs(nextY - current.y) > 0.00001;

    const speed = Math.hypot(deltaX, deltaZ) / Math.max(delta, 0.0001);
    const visual = visualStateRef.current;
    visual.speed = MathUtils.damp(visual.speed, speed, 14, delta);
    visual.speedNormalized = MathUtils.damp(
      visual.speedNormalized,
      MathUtils.clamp(
        speed / OPENING_ROOM_CONFIG.movement.sprintSpeed,
        0,
        1,
      ),
      10,
      delta,
    );
    visual.sprinting = Boolean(inputRef.current.sprint && isMoving);
    visual.frozen = false;
    visual.state = resolveEchoAnimationState({
      speed: visual.speed,
      sprinting: visual.sprinting,
      interactionActive: false,
      cinematicLocked: false,
      paused: false,
    });
    visual.lookYaw = MathUtils.damp(visual.lookYaw, 0, 6, delta);

    if (isMoving || isJumpingOrFalling) {
      player.position.set(next.x, nextY, next.z);
    }

    if (isMoving) {
      const desiredRotation = Math.atan2(deltaX, deltaZ);
      const turnDelta = MathUtils.euclideanModulo(
        desiredRotation - player.rotation.y + Math.PI,
        Math.PI * 2,
      ) - Math.PI;
      visual.turnLean = MathUtils.damp(
        visual.turnLean,
        MathUtils.clamp(turnDelta, -1, 1),
        10,
        delta,
      );
      player.rotation.y = MathUtils.damp(
        player.rotation.y,
        player.rotation.y + turnDelta,
        13,
        delta,
      );

      footstepElapsedRef.current += delta;
      const cadence = inputRef.current.sprint ? 0.28 : 0.43;
      if (footstepElapsedRef.current >= cadence) {
        footstepElapsedRef.current = 0;
        onFootstep();
      }
    } else {
      visual.turnLean = MathUtils.damp(visual.turnLean, 0, 9, delta);
      footstepElapsedRef.current = 0;
    }
    lastPositionRef.current.copy(player.position);
  });

  const spawn = OPENING_ROOM_CONFIG.spawnPosition;
  const playerCenterHeight = OPENING_ROOM_CONFIG.movement.halfExtents.y;

  return (
    <group
      ref={playerRef}
      position={[spawn.x, spawn.y, spawn.z]}
      name="echo-player"
    >
      <group position={[0, -playerCenterHeight, 0]}>
        <EchoAvatar visualStateRef={visualStateRef} />
      </group>
    </group>
  );
}
