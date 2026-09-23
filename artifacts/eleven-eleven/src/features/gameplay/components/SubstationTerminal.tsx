import React, { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import type { Group, Mesh } from 'three';

export interface SubstationTerminalProps {
  position?: [number, number, number];
  rotation?: [number, number, number];
  isOverridden?: boolean;
  focused?: boolean;
}

export const SubstationTerminal: React.FC<SubstationTerminalProps> = ({
  position = [8.5, 0, 6.8],
  rotation = [0, -Math.PI / 4, 0],
  isOverridden = false,
  focused = false,
}) => {
  const beaconRef = useRef<Mesh>(null);
  const groupRef = useRef<Group>(null);

  useFrame((state) => {
    if (beaconRef.current) {
      const t = state.clock.getElapsedTime();
      const intensity = isOverridden
        ? 1.0 + Math.sin(t * 4) * 0.3
        : 0.6 + Math.sin(t * 8) * 0.4;
      (beaconRef.current.material as any).emissiveIntensity = intensity;
    }
  });

  return (
    <group ref={groupRef} position={position} rotation={rotation} name="substation-terminal">
      {/* Heavy Base Pedestal */}
      <mesh position={[0, 0.45, 0]} castShadow receiveShadow>
        <boxGeometry args={[1.2, 0.9, 0.8]} />
        <meshStandardMaterial
          color="#0c151c"
          metalness={0.85}
          roughness={0.35}
        />
      </mesh>

      {/* Hazard Base Border */}
      <mesh position={[0, 0.05, 0]}>
        <boxGeometry args={[1.3, 0.1, 0.9]} />
        <meshStandardMaterial
          color="#2a2408"
          metalness={0.5}
          roughness={0.6}
        />
      </mesh>

      {/* Slanted Interactive Control Deck */}
      <mesh position={[0, 1.05, 0.05]} rotation={[-Math.PI / 6, 0, 0]} castShadow>
        <boxGeometry args={[1.05, 0.4, 0.5]} />
        <meshStandardMaterial
          color="#14212b"
          metalness={0.8}
          roughness={0.25}
        />
      </mesh>

      {/* Holographic Power Routing Display */}
      <mesh position={[0, 1.15, 0.15]} rotation={[-Math.PI / 6, 0, 0]}>
        <planeGeometry args={[0.85, 0.3]} />
        <meshBasicMaterial
          color={isOverridden ? '#00f0ff' : '#ff4455'}
          wireframe={false}
          transparent
          opacity={0.85}
        />
      </mesh>

      {/* Top Warning/Status Beacon */}
      <mesh ref={beaconRef} position={[0, 1.45, -0.1]}>
        <cylinderGeometry args={[0.06, 0.06, 0.15, 12]} />
        <meshStandardMaterial
          color={isOverridden ? '#00f0ff' : '#ffaa00'}
          emissive={isOverridden ? '#00f0ff' : '#ff6600'}
          emissiveIntensity={1.2}
        />
      </mesh>

      {/* Interactive Selection Highlight Ring */}
      {focused && (
        <mesh position={[0, 0.02, 0]} rotation={[-Math.PI / 2, 0, 0]}>
          <ringGeometry args={[0.9, 1.05, 32]} />
          <meshBasicMaterial
            color={isOverridden ? '#00f0ff' : '#ffaa00'}
            transparent
            opacity={0.7}
          />
        </mesh>
      )}

      {/* Terminal Ambient/Status Point Light */}
      <pointLight
        position={[0, 1.3, 0.2]}
        color={isOverridden ? '#00f0ff' : '#ff7700'}
        intensity={isOverridden ? 1.4 : 0.8}
        distance={3.5}
      />
    </group>
  );
};
