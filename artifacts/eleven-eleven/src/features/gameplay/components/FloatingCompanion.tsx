import { useRef, useMemo, useEffect } from 'react';
import { useFrame } from '@react-three/fiber';
import {
  Group,
  Mesh,
  PointLight,
  Vector3,
  Color,
} from 'three';
import {
  createInitialCompanionState,
  calculateCompanionTarget,
  stepCompanionPhysics,
  triggerCompanionEmotion,
  type FloatingCompanionEmotion,
  type FloatingCompanionConfig,
  DEFAULT_COMPANION_CONFIG,
} from '../domain/floatingCompanionState';

export interface FloatingCompanionProps {
  playerPosition: Vector3;
  playerYaw?: number;
  playerRef?: React.RefObject<Group | null>;
  focusedTarget?: { x: number; y: number; z: number } | null;
  isAlert?: boolean;
  reducedMotion?: boolean;
  emotionOverride?: FloatingCompanionEmotion | null;
  config?: FloatingCompanionConfig;
  onEmotionChange?: (emotion: FloatingCompanionEmotion) => void;
}

const EMOTION_COLORS: Record<FloatingCompanionEmotion, { core: string; emissive: string; light: string }> = {
  idle: { core: '#08121a', emissive: '#16b5d9', light: '#1cd6ff' },
  following: { core: '#08121a', emissive: '#16b5d9', light: '#1cd6ff' },
  observing: { core: '#08121a', emissive: '#24e0ff', light: '#42e8ff' },
  scanning: { core: '#0b1624', emissive: '#3bf0d0', light: '#4dffdc' },
  alert: { core: '#1a080c', emissive: '#ff2d55', light: '#ff3b60' },
  confused: { core: '#140e1a', emissive: '#d162f5', light: '#e07aff' },
  distressed: { core: '#1c0808', emissive: '#ff2233', light: '#ff4455' },
  celebrating: { core: '#0c1a16', emissive: '#36f0a0', light: '#4df5aa' },
};

export function FloatingCompanion({
  playerPosition,
  playerYaw = 0,
  playerRef,
  focusedTarget,
  isAlert = false,
  reducedMotion = false,
  emotionOverride,
  config = DEFAULT_COMPANION_CONFIG,
  onEmotionChange,
}: FloatingCompanionProps) {
  const rootGroupRef = useRef<Group | null>(null);
  const coreMeshRef = useRef<Mesh | null>(null);
  const outerRingRef = useRef<Mesh | null>(null);
  const innerRingRef = useRef<Mesh | null>(null);
  const lightRef = useRef<PointLight | null>(null);

  const stateRef = useRef(createInitialCompanionState(playerPosition));
  const timeRef = useRef(0);
  const prevEmotionRef = useRef<FloatingCompanionEmotion>('idle');

  // React to external alert state
  useEffect(() => {
    if (isAlert) {
      triggerCompanionEmotion(stateRef.current, 'alert', 4.0);
    }
  }, [isAlert]);

  // React to targeted interactables
  useEffect(() => {
    if (focusedTarget) {
      triggerCompanionEmotion(
        stateRef.current,
        'observing',
        2.5,
        new Vector3(focusedTarget.x, focusedTarget.y, focusedTarget.z),
      );
    }
  }, [focusedTarget]);

  // React to explicit emotion overrides
  useEffect(() => {
    if (emotionOverride) {
      triggerCompanionEmotion(stateRef.current, emotionOverride, 3.0);
    }
  }, [emotionOverride]);

  const targetVec = useMemo(() => new Vector3(), []);
  const currentColor = useMemo(() => new Color(), []);
  const targetColor = useMemo(() => new Color(), []);

  useFrame((_, delta) => {
    const root = rootGroupRef.current;
    if (!root) return;

    timeRef.current += delta;
    const state = stateRef.current;
    const effectiveYaw = playerRef?.current ? playerRef.current.rotation.y : playerYaw;

    // Calculate ideal shoulder target
    const calculatedTarget = calculateCompanionTarget(
      playerPosition,
      effectiveYaw,
      config,
      timeRef.current,
      reducedMotion,
    );
    targetVec.copy(calculatedTarget);

    // Step physics
    stepCompanionPhysics(state, targetVec, delta, config, reducedMotion);

    // Apply position and orientation to 3D object
    root.position.copy(state.currentPosition);
    root.rotation.set(state.pitch, state.yaw, state.roll, 'YXZ');

    // Idle rotation for orbital rings
    if (!reducedMotion) {
      if (outerRingRef.current) {
        outerRingRef.current.rotation.x += delta * 1.8;
        outerRingRef.current.rotation.y += delta * 1.2;
      }
      if (innerRingRef.current) {
        innerRingRef.current.rotation.y -= delta * 2.2;
        innerRingRef.current.rotation.z += delta * 1.5;
      }
    }

    // Color and light modulation based on emotion
    const palette = EMOTION_COLORS[state.emotion];
    targetColor.set(palette.light);
    currentColor.lerp(targetColor, Math.min(1.0, delta * 6.0));

    if (lightRef.current) {
      lightRef.current.color.copy(currentColor);
      // Subtle light pulse
      const pulse = reducedMotion ? 1.0 : 1.0 + Math.sin(timeRef.current * 4.0) * 0.15;
      lightRef.current.intensity = (state.emotion === 'alert' ? 1.8 : 0.9) * pulse;
    }

    if (state.emotion !== prevEmotionRef.current) {
      prevEmotionRef.current = state.emotion;
      onEmotionChange?.(state.emotion);
    }
  });

  return (
    <group ref={rootGroupRef} name="floating-companion">
      {/* Central Core: Obsidian faceted octahedron with cyan emissive core */}
      <mesh ref={coreMeshRef} castShadow>
        <octahedronGeometry args={[0.09, 0]} />
        <meshStandardMaterial
          color="#060c12"
          roughness={0.15}
          metalness={0.85}
          emissive={EMOTION_COLORS.idle.emissive}
          emissiveIntensity={0.8}
        />
      </mesh>

      {/* Inner Gyroscopic Ring: Pale Ivory / Polished Titanium */}
      <mesh ref={innerRingRef}>
        <torusGeometry args={[0.135, 0.009, 8, 24]} />
        <meshStandardMaterial
          color="#e8f4f8"
          roughness={0.25}
          metalness={0.9}
        />
      </mesh>

      {/* Outer Orbital Ring: Dark Obsidian with Cyan Emissive Trim */}
      <mesh ref={outerRingRef}>
        <torusGeometry args={[0.175, 0.007, 8, 28]} />
        <meshStandardMaterial
          color="#0d1b24"
          roughness={0.3}
          metalness={0.7}
          emissive="#128ba8"
          emissiveIntensity={0.5}
        />
      </mesh>

      {/* Point Light: Emits atmospheric radiance illuminating Echo and environment */}
      <pointLight
        ref={lightRef}
        distance={3.5}
        intensity={0.9}
        decay={2}
      />
    </group>
  );
}
