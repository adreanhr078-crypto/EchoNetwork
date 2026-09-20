import { useEffect, useMemo, useRef } from 'react';
import { useAnimations, useGLTF } from '@react-three/drei';
import { useFrame } from '@react-three/fiber';
import {
  CanvasTexture,
  LoopOnce,
  MathUtils,
  type Group,
  type Sprite,
  type SpriteMaterial,
} from 'three';

export const WAKE_CAPSULE_MODEL_URL = '/assets/props/sector11-wake-capsule-v2.glb';

export interface WakeCapsuleModelProps {
  position?: [number, number, number];
  rotation?: [number, number, number];
  scale?: number;
  isOpen?: boolean;
}

const VAPOR_COUNT = 8;

function CapsuleColdVapor({ active }: { active: boolean }) {
  const spritesRef = useRef<(Sprite | null)[]>([]);
  const materialsRef = useRef<(SpriteMaterial | null)[]>([]);
  const elapsedRef = useRef(0);
  const wasActiveRef = useRef(false);
  const vaporTexture = useMemo(() => {
    const canvas = document.createElement('canvas');
    canvas.width = 64;
    canvas.height = 64;
    const context = canvas.getContext('2d');
    if (context) {
      const gradient = context.createRadialGradient(32, 32, 2, 32, 32, 31);
      gradient.addColorStop(0, 'rgba(210,250,255,0.9)');
      gradient.addColorStop(0.28, 'rgba(115,224,235,0.42)');
      gradient.addColorStop(1, 'rgba(30,120,135,0)');
      context.fillStyle = gradient;
      context.fillRect(0, 0, 64, 64);
    }
    return new CanvasTexture(canvas);
  }, []);

  useEffect(() => () => vaporTexture.dispose(), [vaporTexture]);

  useFrame((_, rawDelta) => {
    if (active && !wasActiveRef.current) elapsedRef.current = 0;
    wasActiveRef.current = active;
    elapsedRef.current += Math.min(rawDelta, 0.05);
    const elapsed = elapsedRef.current;
    const releaseEnvelope = active
      ? 1 - MathUtils.smoothstep(elapsed, 1.15, 2.8)
      : 0;

    spritesRef.current.forEach((sprite, index) => {
      const material = materialsRef.current[index];
      if (!sprite || !material) return;
      const cycle = (elapsed * (0.42 + index * 0.012) + index / VAPOR_COUNT) % 1;
      const angle = index * 2.39996;
      const radius = 0.34 + cycle * 0.42;
      sprite.position.set(
        Math.cos(angle) * radius,
        0.12 + cycle * 0.88,
        Math.sin(angle) * radius * 0.62,
      );
      const scale = 0.28 + cycle * 0.48;
      sprite.scale.set(scale, scale * 0.72, 1);
      material.opacity = Math.sin(cycle * Math.PI) * 0.2 * releaseEnvelope;
      sprite.visible = material.opacity > 0.002;
    });
  });

  return (
    <group name="capsule-cold-vapor">
      {Array.from({ length: VAPOR_COUNT }, (_, index) => (
        <sprite
          key={index}
          ref={(sprite) => { spritesRef.current[index] = sprite; }}
        >
          <spriteMaterial
            ref={(material) => { materialsRef.current[index] = material; }}
            map={vaporTexture}
            color="#9beaf2"
            transparent
            opacity={0}
            depthWrite={false}
            toneMapped={false}
          />
        </sprite>
      ))}
    </group>
  );
}

export function WakeCapsuleModel({
  position = [-2.68, 0.18, 1.33],
  rotation = [0, 0.35, 0],
  scale = 1.25,
  isOpen = true,
}: WakeCapsuleModelProps) {
  const groupRef = useRef<Group>(null);
  const { scene, animations } = useGLTF(WAKE_CAPSULE_MODEL_URL);
  const { actions } = useAnimations(animations, groupRef);

  useEffect(() => {
    const openAction = actions['CAPSULE_OPEN'];
    if (!openAction) return;

    if (isOpen) {
      openAction.setLoop(LoopOnce, 1);
      openAction.clampWhenFinished = true;
      openAction.play();
    } else {
      openAction.stop();
    }
  }, [actions, isOpen]);

  return (
    <group
      ref={groupRef}
      position={position}
      rotation={rotation}
      scale={scale}
      name="sector11-wake-capsule"
    >
      <primitive object={scene} />
      <CapsuleColdVapor active={isOpen} />
      {/* Interior cryo-fluid uplight */}
      <pointLight
        position={[0, 0.5, 0]}
        color="#00f0ff"
        intensity={0.72}
        distance={1.9}
        decay={2}
      />
    </group>
  );
}

useGLTF.preload(WAKE_CAPSULE_MODEL_URL);
