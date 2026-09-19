import {
  useEffect,
  useRef,
  type MutableRefObject,
} from 'react';
import { useFrame } from '@react-three/fiber';
import {
  MathUtils,
  Vector3,
  type Group,
  type Mesh,
} from 'three';
import { OPENING_ROOM_CONFIG } from '../data/openingRoom.config';
import type {
  OpeningRoomNarrativeFlags,
} from '../systems/puzzleSystem';
import {
  integrateHorizontalVelocity,
  movePlayerByVelocity,
} from '../systems/playerMovementSystem';
import { useInteraction } from '../hooks/useInteraction';
import type {
  PlayerControlsSnapshot,
} from '../hooks/usePlayerControls';
import { EchoAvatar } from './EchoAvatar';
import {
  INITIAL_ECHO_VISUAL_STATE,
} from '../types/echoAnimation.types';
import {
  advanceFootstepPhase,
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
  hasWeapon?: boolean;
  attackTrigger?: number;
  combatAction?: { type: 'punch' | 'kick' | 'dodge' | 'slash'; nonce: number } | null;
  onPositionUpdate?: (pos: Vector3) => void;
  onHitTarget?: (damage: number, impactPos: Vector3, reach?: number, attackType?: string) => void;
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
  hasWeapon = false,
  attackTrigger = 0,
  combatAction = null,
  onPositionUpdate,
  onHitTarget,
  onNearestInteractionChange,
  onFootstep,
}: EchoPlayerProps) {
  const visualStateRef = useRef({ ...INITIAL_ECHO_VISUAL_STATE });
  const footstepPhaseRef = useRef(0);

  const velocityYRef = useRef(0);
  const horizontalVelocityRef = useRef({ x: 0, z: 0 });
  const katanaGroupRef = useRef<Group>(null);
  const slashArcRef = useRef<Mesh>(null);
  const attackElapsedRef = useRef(1);
  const lastAttackTriggerRef = useRef(attackTrigger);
  const attackTypeRef = useRef<'punch1' | 'punch2' | 'kick' | 'slash' | 'dodge'>('punch1');
  const comboStepRef = useRef(0);
  const lastCombatNonceRef = useRef(-1);
  const hitAppliedRef = useRef(false);

  useEffect(() => {
    if (combatAction && combatAction.nonce !== lastCombatNonceRef.current) {
      lastCombatNonceRef.current = combatAction.nonce;
      hitAppliedRef.current = false;
      attackElapsedRef.current = 0;

      let chosenType: 'punch1' | 'punch2' | 'kick' | 'slash' | 'dodge' = 'punch1';
      if (combatAction.type === 'kick') {
        chosenType = 'kick';
      } else if (combatAction.type === 'dodge') {
        chosenType = 'dodge';
      } else if (hasWeapon || combatAction.type === 'slash') {
        chosenType = 'slash';
      } else {
        comboStepRef.current = (comboStepRef.current + 1) % 2;
        chosenType = comboStepRef.current === 1 ? 'punch1' : 'punch2';
      }
      attackTypeRef.current = chosenType;

      const visual = visualStateRef.current;
      visual.attackActive = true;
      visual.attackType = chosenType;
      visual.attackProgress = 0;
    }
  }, [combatAction, hasWeapon]);

  useEffect(() => {
    if (attackTrigger > 0 && attackTrigger !== lastAttackTriggerRef.current) {
      lastAttackTriggerRef.current = attackTrigger;
      hitAppliedRef.current = false;
      attackElapsedRef.current = 0;
      comboStepRef.current = (comboStepRef.current + 1) % 2;
      const chosenType = hasWeapon ? 'slash' : (comboStepRef.current === 1 ? 'punch1' : 'punch2');
      attackTypeRef.current = chosenType;
      const visual = visualStateRef.current;
      visual.attackActive = true;
      visual.attackType = chosenType;
      visual.attackProgress = 0;
    }
  }, [attackTrigger, hasWeapon]);

  useInteraction({
    playerRef,
    context: { flags },
    enabled,
    onNearestChange: onNearestInteractionChange,
  });

  useFrame((_, frameDelta) => {
    // @ts-ignore - GLOBALS imported or directly referenced
    const timeScale = (window as any).__11_11_TIME_SCALE ?? 1.0;
    const player = playerRef.current;
    if (!player) return;

    if (!enabled) {
      horizontalVelocityRef.current = { x: 0, z: 0 };
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
      footstepPhaseRef.current = 0;
      return;
    }

    const delta = Math.min(frameDelta, 0.05) * timeScale;
    const current = player.position;

    // Dampen directional input during melee strikes to prevent skating
    const isAttacking = visualStateRef.current.attackActive;
    const activeInput = { ...inputRef.current };
    if (isAttacking && attackTypeRef.current !== 'dodge') {
      activeInput.forward = false;
      activeInput.backward = false;
      activeInput.left = false;
      activeInput.right = false;
    }

    horizontalVelocityRef.current = integrateHorizontalVelocity({
      velocity: horizontalVelocityRef.current,
      input: activeInput,
      deltaSeconds: delta,
      facingYawRadians: cameraYawRef.current,
      movement: OPENING_ROOM_CONFIG.movement,
    });
    const intendedVelocity = horizontalVelocityRef.current;
    const next = movePlayerByVelocity({
      position: {
        x: current.x,
        y: current.y,
        z: current.z,
      },
      velocity: intendedVelocity,
      deltaSeconds: delta,
      roomBounds: OPENING_ROOM_CONFIG.bounds,
      obstacles: OPENING_ROOM_CONFIG.obstacles,
      movement: OPENING_ROOM_CONFIG.movement,
    });
    if (Math.abs(next.x - current.x - intendedVelocity.x * delta) > 0.001) {
      horizontalVelocityRef.current = { ...horizontalVelocityRef.current, x: 0 };
    }
    if (Math.abs(next.z - current.z - intendedVelocity.z * delta) > 0.001) {
      horizontalVelocityRef.current = { ...horizontalVelocityRef.current, z: 0 };
    }

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
      attackState: visual.attackActive ? visual.attackType : null,
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

      const footstepProgress = advanceFootstepPhase(
        footstepPhaseRef.current,
        Math.hypot(deltaX, deltaZ),
        visual.sprinting,
      );
      footstepPhaseRef.current = footstepProgress.phase;
      for (let step = 0; step < footstepProgress.emittedSteps; step += 1) {
        onFootstep();
      }
    } else {
      visual.turnLean = MathUtils.damp(visual.turnLean, 0, 9, delta);
      footstepPhaseRef.current = 0;
    }

    // Combat Attack & Dodge Execution (Genshin / NieR fast tactical martial arts)
    // Combat Attack & Dodge Execution (Genshin / NieR fast tactical martial arts)
    const currentAttack = attackTypeRef.current;
    // Exactly matches durations in combatAnimationClips.ts
    const duration =
      currentAttack === 'kick'
        ? 0.72
        : currentAttack === 'slash'
          ? 0.60
          : currentAttack === 'punch2'
            ? 0.55
            : currentAttack === 'dodge'
              ? 0.34
              : 0.45;

    if (attackElapsedRef.current < duration) {
      attackElapsedRef.current += delta;
      const progress = Math.min(attackElapsedRef.current / duration, 1);
      const visual = visualStateRef.current;
      visual.attackProgress = progress;

      const forwardX = Math.sin(player.rotation.y);
      const forwardZ = Math.cos(player.rotation.y);

      // Dodge: quick forward burst + I-Frames
      if (currentAttack === 'dodge') {
        const isIFrame = progress > 0.1 && progress < 0.8;
        player.userData.isInvulnerable = isIFrame;

        player.position.x += forwardX * 7.0 * delta;
        player.position.z += forwardZ * 7.0 * delta;
      } else {
        player.userData.isInvulnerable = false;

        // Combat Root Motion (Lunges forward into strike)
        if (progress > 0.12 && progress < 0.42) {
          const lungeSpeed = currentAttack === 'slash' ? 3.8 : currentAttack === 'kick' ? 3.0 : 1.8;
          player.position.x += forwardX * lungeSpeed * delta;
          player.position.z += forwardZ * lungeSpeed * delta;
        }
      }

      // Hitbox Application at peak of strike
      const hitWindow =
        currentAttack === 'kick'
          ? (progress >= 0.35 && progress <= 0.55)
          : currentAttack === 'slash'
            ? (progress >= 0.28 && progress <= 0.50)
            : (progress >= 0.22 && progress <= 0.45);

      if (hitWindow && !hitAppliedRef.current && currentAttack !== 'dodge') {
        hitAppliedRef.current = true;
        const forwardX = Math.sin(player.rotation.y);
        const forwardZ = Math.cos(player.rotation.y);
        const reach = currentAttack === 'slash' ? 2.5 : currentAttack === 'kick' ? 2.2 : currentAttack === 'punch2' ? 1.8 : 1.6;
        const impactPos = player.position.clone().add(new Vector3(forwardX * reach, 1.1, forwardZ * reach));
        const damage = currentAttack === 'slash' ? 175 : currentAttack === 'kick' ? 125 : currentAttack === 'punch2' ? 80 : 55;
        onHitTarget?.(damage, impactPos, reach, currentAttack);
      }

      // Katana Group Transform (if slashing with sword)
      if (hasWeapon && katanaGroupRef.current && currentAttack === 'slash') {
        if (progress < 0.35) {
          const slashT = progress / 0.35;
          katanaGroupRef.current.position.set(
            MathUtils.lerp(0.32, 0.52, slashT),
            MathUtils.lerp(0.58, 0.72, slashT),
            MathUtils.lerp(-0.05, 0.65, slashT),
          );
          katanaGroupRef.current.rotation.set(
            MathUtils.lerp(-0.2, 0.45, slashT),
            MathUtils.lerp(0.15, -1.35, slashT),
            MathUtils.lerp(-0.5, 1.45, slashT),
          );
        } else {
          const returnT = (progress - 0.35) / 0.65;
          katanaGroupRef.current.position.set(
            MathUtils.lerp(0.52, 0.32, returnT),
            MathUtils.lerp(0.72, 0.58, returnT),
            MathUtils.lerp(0.65, -0.05, returnT),
          );
          katanaGroupRef.current.rotation.set(
            MathUtils.lerp(0.45, -0.2, returnT),
            MathUtils.lerp(-1.35, 0.15, returnT),
            MathUtils.lerp(1.45, -0.5, returnT),
          );
        }
      }
      if (slashArcRef.current) {
        slashArcRef.current.visible = hasWeapon && currentAttack === 'slash' && progress < 0.38;
        const mat = slashArcRef.current.material as any;
        if (mat) mat.opacity = (1 - progress / 0.38) * 0.9;
      }
    } else {
      const visual = visualStateRef.current;
      visual.attackActive = false;
      visual.attackType = null;
      if (slashArcRef.current) slashArcRef.current.visible = false;
    }

    onPositionUpdate?.(player.position);
  });

  const spawn = OPENING_ROOM_CONFIG.spawnPosition;
  const playerCenterHeight = OPENING_ROOM_CONFIG.movement.halfExtents.y;

  return (
    <group
      ref={playerRef}
      position={[spawn.x, spawn.y, spawn.z]}
      rotation={[0, Math.PI, 0]}
      name="echo-player"
    >
      <group position={[0, -playerCenterHeight, 0]}>
        <EchoAvatar visualStateRef={visualStateRef} />
        {/* Equipped Tactical Cyber-Katana */}
        {hasWeapon && (
          <group
            ref={katanaGroupRef}
            position={[0.42, 0.92, -0.05]}
            rotation={[-0.2, 0.15, -0.5]}
            scale={1.22}
          >
            <mesh position={[0, -0.18, 0]}>
              <cylinderGeometry args={[0.02, 0.022, 0.22, 8]} />
              <meshStandardMaterial color="#080a0f" metalness={0.92} roughness={0.2} />
            </mesh>
            <mesh position={[0, -0.06, 0]}>
              <boxGeometry args={[0.08, 0.012, 0.04]} />
              <meshStandardMaterial color="#2a3a46" metalness={0.9} />
            </mesh>
            <mesh position={[0, 0.38, 0]} castShadow>
              <boxGeometry args={[0.014, 0.88, 0.038]} />
              <meshStandardMaterial
                color="#05080c"
                emissive="#00f0ff"
                emissiveIntensity={1.35}
                metalness={0.95}
                roughness={0.12}
              />
            </mesh>
            {/* Cyan Slash Energy Trail Arc */}
            <mesh
              ref={slashArcRef}
              visible={false}
              position={[0, 0.35, 0.2]}
              rotation={[0, 0, -Math.PI / 4]}
            >
              <ringGeometry args={[0.6, 0.9, 16, 1, 0, Math.PI * 0.8]} />
              <meshBasicMaterial
                color="#00f0ff"
                transparent
                opacity={0.8}
                side={2}
                toneMapped={false}
              />
            </mesh>
          </group>
        )}
      </group>
    </group>
  );
}
