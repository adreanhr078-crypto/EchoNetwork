import { useEffect, useRef } from 'react';
import { useAnimations, useGLTF } from '@react-three/drei';
import { LoopOnce, type Group } from 'three';

export const WAKE_CAPSULE_MODEL_URL = '/assets/props/sector11-wake-capsule-v2.glb';

export interface WakeCapsuleModelProps {
  position?: [number, number, number];
  rotation?: [number, number, number];
  scale?: number;
  isOpen?: boolean;
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
