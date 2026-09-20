import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import {
  MathUtils,
  type Group,
  type MeshBasicMaterial,
} from 'three';

interface InteractiveHighlightProps {
  active: boolean;
  color?: string;
  radius?: number;
  position?: [number, number, number];
  rotation?: [number, number, number];
}

/**
 * A deliberately restrained interaction cue. It is always mounted so focus
 * changes do not allocate Three resources during play.
 */
export function InteractiveHighlight({
  active,
  color = '#55e7ff',
  radius = 0.45,
  position = [0, 0, 0],
  rotation = [0, 0, 0],
}: InteractiveHighlightProps) {
  const groupRef = useRef<Group>(null);
  const outerMaterialRef = useRef<MeshBasicMaterial>(null);
  const innerMaterialRef = useRef<MeshBasicMaterial>(null);

  useFrame(({ clock }, delta) => {
    const group = groupRef.current;
    const outerMaterial = outerMaterialRef.current;
    const innerMaterial = innerMaterialRef.current;
    if (!group || !outerMaterial || !innerMaterial) return;

    const target = active ? 1 : 0;
    const pulse = 0.5 + Math.sin(clock.elapsedTime * 3.4) * 0.5;
    const opacity = MathUtils.damp(
      outerMaterial.opacity,
      target * (0.09 + pulse * 0.08),
      9,
      delta,
    );
    outerMaterial.opacity = opacity;
    innerMaterial.opacity = opacity * 0.34;
    group.scale.setScalar(0.97 + pulse * 0.045);
    group.rotation.z = Math.sin(clock.elapsedTime * 0.7) * 0.025;
    group.visible = opacity > 0.008;
  });

  return (
    <group
      ref={groupRef}
      position={position}
      rotation={rotation}
      name="interaction-highlight"
    >
      <mesh>
        <torusGeometry args={[radius, 0.009, 8, 40]} />
        <meshBasicMaterial
          ref={outerMaterialRef}
          color={color}
          transparent
          opacity={0}
          depthWrite={false}
          toneMapped={false}
        />
      </mesh>
      <mesh scale={0.78}>
        <ringGeometry args={[radius * 0.72, radius * 0.76, 40]} />
        <meshBasicMaterial
          ref={innerMaterialRef}
          color={color}
          transparent
          opacity={0}
          depthWrite={false}
          toneMapped={false}
        />
      </mesh>
    </group>
  );
}
