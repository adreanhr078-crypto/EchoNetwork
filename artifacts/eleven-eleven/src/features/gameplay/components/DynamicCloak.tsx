import { useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import {
  DoubleSide,
  MathUtils,
  PlaneGeometry,
  type Mesh,
  type MeshStandardMaterial,
} from 'three';
import type { EchoVisualStateRef } from '../types/echoAnimation.types';

interface DynamicCloakProps {
  visualStateRef: EchoVisualStateRef;
}

/**
 * Dynamic GPU/Spring Physics Cloak for Echo.
 * Solves the issue of coats sticking to thighs in static rigs by providing a
 * luxurious, billowing Obsidian cape with Signal Crimson silk underside that
 * reacts dynamically to player velocity, acceleration, turning, and combat maneuvers.
 */
export function DynamicCloak({ visualStateRef }: DynamicCloakProps) {
  const meshRef = useRef<Mesh>(null);
  const materialRef = useRef<MeshStandardMaterial>(null);

  // 4 columns x 8 vertical segments for smooth bending cloth simulation
  const segmentsY = 8;
  const segmentsX = 4;
  const geometry = useMemo(() => {
    const geo = new PlaneGeometry(0.68, 1.18, segmentsX, segmentsY);
    // Anchor top edge at origin (y=0), cape hangs downward to y=-1.18
    geo.translate(0, -0.59, 0);
    return geo;
  }, []);

  // Internal physics spring state for trailing cloth wave
  const waveTimeRef = useRef(0);
  const currentSwayZ = useRef(0);
  const currentSwayX = useRef(0);

  useFrame((_, delta) => {
    const mesh = meshRef.current;
    if (!mesh) return;

    const visual = visualStateRef.current;
    const speed = visual.speed || 0;
    const isSprinting = visual.sprinting;
    const isAttacking = visual.attackActive;
    const attackType = visual.attackType;
    const turnLean = visual.turnLean || 0;

    waveTimeRef.current += delta * (isSprinting ? 12 : speed > 0.1 ? 7 : 3);

    // Target backward lift based on movement speed & attack action
    let targetLiftZ = -0.12; // resting natural drape backward
    let targetFlareX = -turnLean * 0.28; // flare on turns

    if (speed > 0.1) {
      targetLiftZ = -0.22 - (speed / 5.2) * 0.45; // billow backward when moving
    }
    if (isAttacking) {
      if (attackType === 'kick') {
        targetLiftZ = -0.65;
        targetFlareX = 0.45;
      } else if (attackType === 'slash' || attackType === 'punch2') {
        targetLiftZ = -0.5;
        targetFlareX = -0.35;
      } else if (attackType === 'dodge') {
        targetLiftZ = -0.7;
      }
    }

    // Spring damping for smooth inertia
    currentSwayZ.current = MathUtils.damp(currentSwayZ.current, targetLiftZ, 8, delta);
    currentSwayX.current = MathUtils.damp(currentSwayX.current, targetFlareX, 10, delta);

    // Vertex displacement along the cape length
    const posAttr = geometry.attributes.position;
    const count = posAttr.count;

    for (let i = 0; i < count; i++) {
      const y = posAttr.getY(i);
      const normalizedY = -y / 1.18; // 0 at top, 1 at bottom

      // Top row (shoulders) remains anchored
      if (normalizedY < 0.05) {
        posAttr.setZ(i, 0);
        continue;
      }

      // Quadratic curve backward for realistic cloth drape + sine wind ripple
      const curveWeight = Math.pow(normalizedY, 1.6);
      const windRipple = Math.sin(waveTimeRef.current + normalizedY * 4.2) * 0.045 * (0.3 + speed * 0.2);
      const zOffset = currentSwayZ.current * curveWeight + windRipple;

      // Lateral flare on turns and spin
      const xOffset = currentSwayX.current * curveWeight;

      posAttr.setZ(i, zOffset);
      // Subtle spread at the bottom hem
      const origX = (i % (segmentsX + 1) - segmentsX / 2) * (0.68 / segmentsX);
      posAttr.setX(i, origX * (1.0 + normalizedY * 0.35) + xOffset);
    }

    posAttr.needsUpdate = true;
    geometry.computeVertexNormals();
  });

  return (
    <group position={[0, 1.42, -0.16]} rotation={[0.05, 0, 0]}>
      {/* Dynamic Billowing Cape Mesh */}
      <mesh ref={meshRef} geometry={geometry} castShadow>
        <meshStandardMaterial
          ref={materialRef}
          color="#06080d"
          emissive="#120408"
          emissiveIntensity={0.2}
          roughness={0.65}
          metalness={0.12}
          side={DoubleSide}
        />
      </mesh>

      {/* Shoulder Clasp Mounts / Gold-Obsidian Brooches */}
      {[-0.22, 0.22].map((x, idx) => (
        <group key={idx} position={[x, 0.02, 0.02]}>
          <mesh>
            <cylinderGeometry args={[0.032, 0.038, 0.025, 8]} />
            <meshStandardMaterial color="#c8963e" metalness={0.92} roughness={0.25} />
          </mesh>
          <mesh position={[0, 0, 0.016]}>
            <sphereGeometry args={[0.016, 8, 8]} />
            <meshBasicMaterial color="#ff0044" />
          </mesh>
        </group>
      ))}
    </group>
  );
}
