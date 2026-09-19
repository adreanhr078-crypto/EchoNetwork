import {
  forwardRef,
  useImperativeHandle,
  useRef,
  useState,
} from 'react';
import { useFrame } from '@react-three/fiber';
import { Billboard, Html, Text } from '@react-three/drei';
import {
  DoubleSide,
  Vector3,
} from 'three';

export interface CombatEffectsHandle {
  triggerHit: (impactPos: Vector3, damage: number, isCrit?: boolean) => void;
}

interface DamageNumberData {
  id: number;
  x: number;
  y: number;
  z: number;
  vx?: number;
  vy?: number;
  vz?: number;
  damage: number;
  isCrit: boolean;
  age: number; // 0 to 1
}

interface ImpactRingData {
  id: number;
  x: number;
  y: number;
  z: number;
  radius: number;
  opacity: number;
}

interface HitSparkData {
  id: number;
  x: number;
  y: number;
  z: number;
  vx: number;
  vy: number;
  vz: number;
  scale: number;
  color: string;
}

export const CombatEffects = forwardRef<CombatEffectsHandle>((_, ref) => {
  const [damageItems, setDamageItems] = useState<DamageNumberData[]>([]);
  const ringsRef = useRef<ImpactRingData[]>([]);
  const sparksRef = useRef<HitSparkData[]>([]);
  const nextIdRef = useRef(1);

  useImperativeHandle(ref, () => ({
    triggerHit: (impactPos: Vector3, damage: number, isCrit = false) => {
      const id = nextIdRef.current++;

      // 1. Floating Damage Number
      const angle = Math.random() * Math.PI * 2;
      const speed = 1.5 + Math.random() * 1.5;
      setDamageItems((prev) => [
        ...prev.slice(-10), // keep max 10 active
        {
          id,
          x: impactPos.x,
          y: impactPos.y + 0.4,
          z: impactPos.z,
          vx: Math.cos(angle) * speed * 0.5,
          vy: 3.5 + Math.random() * 2.0,
          vz: Math.sin(angle) * speed * 0.5,
          damage,
          isCrit,
          age: 0,
        },
      ]);

      // 2. Expanding Impact Shockwave Ring
      ringsRef.current.push({
        id,
        x: impactPos.x,
        y: impactPos.y,
        z: impactPos.z,
        radius: 0.1,
        opacity: 0.95,
      });

      // 3. Glowing Sparks Burst
      const sparkColors = isCrit ? ['#ff0055', '#ff3377', '#ffffff'] : ['#ff8800', '#ffcc00', '#ffffff'];
      for (let i = 0; i < 12; i++) {
        const angle = Math.random() * Math.PI * 2;
        const elevation = (Math.random() - 0.2) * Math.PI;
        const speed = 2.5 + Math.random() * 3.5;
        sparksRef.current.push({
          id: nextIdRef.current++,
          x: impactPos.x,
          y: impactPos.y,
          z: impactPos.z,
          vx: Math.cos(angle) * Math.cos(elevation) * speed,
          vy: Math.sin(elevation) * speed + 1.2,
          vz: Math.sin(angle) * Math.cos(elevation) * speed,
          scale: 0.045 + Math.random() * 0.035,
          color: sparkColors[i % sparkColors.length],
        });
      }
    },
  }));

  useFrame((_, delta) => {
    // Update Damage Items
    setDamageItems((prev) => {
      if (prev.length === 0) return prev;
      return prev
        .map((item) => ({
          ...item,
          x: item.x + (item.vx || 0) * delta,
          y: item.y + (item.vy || 0) * delta,
          z: item.z + (item.vz || 0) * delta,
          vy: (item.vy || 0) - 9.8 * delta, // gravity
          age: item.age + delta * 1.35,
        }))
        .filter((item) => item.age < 1.0);
    });

    // Update Impact Rings
    const rings = ringsRef.current;
    for (let i = rings.length - 1; i >= 0; i--) {
      const ring = rings[i];
      ring.radius += delta * 4.8;
      ring.opacity -= delta * 3.8;
      if (ring.opacity <= 0) {
        rings.splice(i, 1);
      }
    }

    // Update Hit Sparks
    const sparks = sparksRef.current;
    for (let i = sparks.length - 1; i >= 0; i--) {
      const spark = sparks[i];
      spark.x += spark.vx * delta;
      spark.y += spark.vy * delta;
      spark.z += spark.vz * delta;
      spark.vy -= 9.8 * delta; // gravity
      spark.scale = Math.max(0, spark.scale - delta * 0.12);
      if (spark.scale <= 0.005) {
        sparks.splice(i, 1);
      }
    }
  });

  return (
    <group name="combat-effects-layer">
      {/* 1. Floating 3D Damage Numbers (WebGL 3D Billboard SDF Text) */}
      {damageItems.map((item) => {
        const floatY = item.y;
        const opacity = Math.max(0, 1 - item.age * 1.15);
        const scale = (item.isCrit ? 1.4 : 1.1) - item.age * 0.3;

        return (
          <group key={item.id}>
            <Billboard
              position={[item.x, floatY, item.z]}
              follow={true}
              lockX={false}
              lockY={false}
              lockZ={false}
            >
              <Text
                fontSize={item.isCrit ? 0.46 : 0.34}
                color={item.isCrit ? '#ff0055' : '#ff9900'}
                outlineWidth={0.038}
                outlineColor="#000000"
                fillOpacity={opacity}
                outlineOpacity={opacity}
                scale={[scale, scale, scale]}
                anchorX="center"
                anchorY="middle"
              >
                {item.damage}{item.isCrit ? ' CRIT!' : ''}
              </Text>
            </Billboard>

            <Html
              position={[item.x, floatY, item.z]}
              center
              distanceFactor={5.5}
              zIndexRange={[100, 0]}
            >
              <div
                style={{
                  fontFamily: "'Space Grotesk', system-ui, sans-serif",
                  fontWeight: 900,
                  fontSize: item.isCrit ? '32px' : '24px',
                  color: item.isCrit ? '#ff0055' : '#ffaa00',
                  textShadow: item.isCrit
                    ? '0 0 16px #ff0055, 0 0 4px #ffffff, 0 2px 4px #000000'
                    : '0 0 10px #ff7700, 0 2px 4px #000000',
                  letterSpacing: '0.05em',
                  userSelect: 'none',
                  pointerEvents: 'none',
                  whiteSpace: 'nowrap',
                  opacity,
                  transform: `scale(${scale})`,
                  transition: 'opacity 0.05s ease-out',
                }}
              >
                {item.damage}
                {item.isCrit && (
                  <span
                    style={{
                      fontSize: '14px',
                      marginLeft: '4px',
                      color: '#ffffff',
                      background: '#ff0055',
                      padding: '2px 5px',
                      borderRadius: '3px',
                      verticalAlign: 'middle',
                    }}
                  >
                    CRIT
                  </span>
                )}
              </div>
            </Html>
          </group>
        );
      })}

      {/* 2. Expanding Impact Shockwave Rings */}
      {ringsRef.current.map((ring) => (
        <mesh
          key={ring.id}
          position={[ring.x, ring.y, ring.z]}
          rotation={[-Math.PI / 2, 0, 0]}
        >
          <ringGeometry args={[ring.radius, ring.radius + 0.06, 24]} />
          <meshBasicMaterial
            color="#ff0055"
            transparent
            opacity={ring.opacity}
            side={DoubleSide}
            depthWrite={false}
          />
        </mesh>
      ))}

      {/* 3. Glowing Sparks Particles */}
      {sparksRef.current.map((spark) => (
        <mesh key={spark.id} position={[spark.x, spark.y, spark.z]}>
          <sphereGeometry args={[spark.scale, 8, 8]} />
          <meshBasicMaterial
            color={spark.color}
            toneMapped={false}
            depthWrite={false}
          />
        </mesh>
      ))}
    </group>
  );
});

CombatEffects.displayName = 'CombatEffects';
