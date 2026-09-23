import { useRef, type MutableRefObject } from 'react';
import { useFrame } from '@react-three/fiber';
import {
  AdditiveBlending,
  Color,
  Vector3,
  type Group,
  type Mesh,
  type MeshBasicMaterial,
} from 'three';

const POOL_SIZE = 6;

interface GhostSlot {
  position: Vector3;
  rotationY: number;
  opacity: number;
  color: Color;
}

interface GhostTrailProps {
  active: boolean;
  playerRef: MutableRefObject<Group | null>;
  color?: string;
  surgeActive?: boolean;
}

export function GhostTrail({
  active,
  playerRef,
  color = '#00f0ff',
  surgeActive = false,
}: GhostTrailProps) {
  const groupRefs = useRef<(Group | null)[]>([]);
  const torsoMatRefs = useRef<(MeshBasicMaterial | null)[]>([]);
  const headMatRefs = useRef<(MeshBasicMaterial | null)[]>([]);

  const poolRef = useRef<GhostSlot[] | null>(null);
  if (!poolRef.current) {
    poolRef.current = Array.from({ length: POOL_SIZE }, () => ({
      position: new Vector3(),
      rotationY: 0,
      opacity: 0,
      color: new Color(color),
    }));
  }

  const poolIndexRef = useRef(0);
  const lastSpawnTimeRef = useRef(0);
  const surgeColorRef = useRef(new Color('#ffaa00'));
  const normalColorRef = useRef(new Color(color));

  useFrame(({ clock }, rawDelta) => {
    const delta = Math.min(rawDelta, 0.05);
    const time = clock.getElapsedTime();
    const player = playerRef.current;
    const pool = poolRef.current;
    if (!pool) return;

    // Spawn new ghost stamp every 55ms while dashing/dodging
    if (active && player && time - lastSpawnTimeRef.current > 0.055) {
      lastSpawnTimeRef.current = time;
      const slot = pool[poolIndexRef.current];
      slot.position.copy(player.position);
      slot.rotationY = player.rotation.y;
      slot.opacity = surgeActive ? 0.85 : 0.65;
      slot.color.copy(surgeActive ? surgeColorRef.current : normalColorRef.current);

      poolIndexRef.current = (poolIndexRef.current + 1) % POOL_SIZE;
    }

    // Update and fade active ghosts in the pool directly via Three.js objects (0 React re-renders)
    for (let i = 0; i < POOL_SIZE; i++) {
      const slot = pool[i];
      const grp = groupRefs.current[i];
      const torsoMat = torsoMatRefs.current[i];
      const headMat = headMatRefs.current[i];

      if (slot.opacity > 0) {
        slot.opacity = Math.max(0, slot.opacity - delta * 2.8);

        if (grp && torsoMat && headMat) {
          if (slot.opacity > 0.01) {
            grp.visible = true;
            grp.position.set(slot.position.x, slot.position.y + 0.88, slot.position.z);
            grp.rotation.y = slot.rotationY;

            torsoMat.color.copy(slot.color);
            headMat.color.copy(slot.color);
            torsoMat.opacity = slot.opacity * 0.7;
            headMat.opacity = slot.opacity * 0.85;
          } else {
            grp.visible = false;
          }
        }
      } else if (grp && grp.visible) {
        grp.visible = false;
      }
    }
  });

  return (
    <group name="echo-ghost-trails">
      {Array.from({ length: POOL_SIZE }).map((_, index) => (
        <group
          key={index}
          ref={(el) => {
            groupRefs.current[index] = el;
          }}
          visible={false}
        >
          {/* Torso Silhouette */}
          <mesh position={[0, 0.22, 0]}>
            <capsuleGeometry args={[0.22, 0.72, 4, 8]} />
            <meshBasicMaterial
              ref={(el) => {
                torsoMatRefs.current[index] = el;
              }}
              color={color}
              transparent
              opacity={0.5}
              blending={AdditiveBlending}
              depthWrite={false}
              toneMapped={false}
            />
          </mesh>
          {/* Head Silhouette */}
          <mesh position={[0, 0.75, 0]}>
            <sphereGeometry args={[0.16, 8, 8]} />
            <meshBasicMaterial
              ref={(el) => {
                headMatRefs.current[index] = el;
              }}
              color={color}
              transparent
              opacity={0.6}
              blending={AdditiveBlending}
              depthWrite={false}
              toneMapped={false}
            />
          </mesh>
        </group>
      ))}
    </group>
  );
}
