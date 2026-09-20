import {
  Suspense,
  useMemo,
  useRef,
  useState,
} from 'react';
import { useFrame } from '@react-three/fiber';
import {
  CatmullRomCurve3,
  DoubleSide,
  MathUtils,
  Vector3,
  type Group,
  type MeshBasicMaterial,
  type MeshStandardMaterial,
} from 'three';
import type { QualityTier } from '../../../ui/design-system';
import { OPENING_ROOM_CONFIG } from '../data/openingRoom.config';
import {
  OPENING_ROOM_PALETTE,
  OPENING_ROOM_VISUAL_QUALITY,
  type RoomVisualEvent,
} from '../data/openingRoom.visuals';
import type {
  OpeningRoomNarrativeFlags,
} from '../systems/puzzleSystem';
import { InteractiveHighlight } from './InteractiveHighlight';
import { MemoryGlitchEffect } from './MemoryGlitchEffect';
import { RoomAtmosphere } from './RoomAtmosphere';
import { RoomLighting } from './RoomLighting';
import { WakeCapsuleModel } from './WakeCapsuleModel';
import { StasisMonsterModel } from './StasisMonsterModel';
import { DigitalClock, TornPhoto } from './OpeningEvidenceProps';
import { OPENING_ROOM_ANCHORS, anchorTuple } from '../data/openingRoom.anchors';

export type OpeningRoomVisualEvent = RoomVisualEvent;

export interface OpeningRoomProps {
  flags: OpeningRoomNarrativeFlags;
  quality: QualityTier;
  focusedInteractionId?: string | null;
  visualEvent?: OpeningRoomVisualEvent | null;
  breachProgress?: number;
  isAgitated?: boolean;
  hasWeapon?: boolean;
  onPickupWeapon?: () => void;
  playerPos?: Vector3;
  onMonsterHpChange?: (currentHp: number, maxHp: number) => void;
  onMonsterAttack?: (damage: number) => void;
  onMonsterDefeated?: () => void;
  lastHitNonce?: number;
  lastHitDamage?: number;
  combatStudyEnabled?: boolean;
}

const KATANA_POSITION: [number, number, number] = [9.2, 0.9, -1.5];

const ROOM_CABLES = [
  {
    points: [
      [-4.3, 4.2, 14.5],
      [-3.0, 4.8, 10.0],
      [-1.5, 4.5, 5.0],
      [-2.0, 4.2, -5.0],
      [-1.5, 3.8, -13.0],
    ],
    color: '#0d222b',
    radius: 0.024,
  },
  {
    points: [
      [3.8, 4.5, 14.0],
      [4.2, 4.8, 8.0],
      [4.0, 4.2, 0.0],
      [3.5, 4.0, -12.0],
    ],
    color: '#1a1f28',
    radius: 0.02,
  },
  {
    points: [
      [4.5, 3.8, 7.0],
      [7.5, 4.2, 6.0],
      [10.5, 3.9, -2.0],
      [11.0, 3.5, -8.0],
    ],
    color: '#3d0a14',
    radius: 0.018,
  },
] as const;

function Cable({
  points,
  color,
  radius,
}: {
  points: readonly (readonly [number, number, number])[];
  color: string;
  radius: number;
}) {
  const curve = useMemo(() => new CatmullRomCurve3(
    points.map(([x, y, z]) => new Vector3(x, y, z)),
  ), [points]);

  return (
    <mesh>
      <tubeGeometry args={[curve, 32, radius, 6, false]} />
      <meshStandardMaterial
        color={color}
        metalness={0.65}
        roughness={0.45}
      />
    </mesh>
  );
}

// -------------------------------------------------------------
// SUSPENDED LIVING CYBERNETIC SPECIMEN (Inside Stasis Tubes)
// -------------------------------------------------------------
function StasisPodSpecimen({
  fluidColor,
  isCritical = false,
  seed = 0,
}: {
  fluidColor: string;
  isCritical?: boolean;
  seed?: number;
}) {
  const groupRef = useRef<Group>(null);
  const bubblesRef = useRef<Group>(null);

  useFrame(({ clock }) => {
    const time = clock.getElapsedTime() + seed * 2.3;
    if (groupRef.current) {
      // Bio-suspension gentle breathing and float
      groupRef.current.position.y = 1.35 + Math.sin(time * 1.5) * 0.04;
      groupRef.current.rotation.y = Math.sin(time * 0.7) * 0.12;
      groupRef.current.rotation.z = Math.cos(time * 1.1) * 0.04;
    }
    if (bubblesRef.current) {
      bubblesRef.current.children.forEach((b, i) => {
        b.position.y = ((clock.getElapsedTime() * (0.45 + i * 0.12) + i * 0.4) % 1.7) - 0.85;
      });
    }
  });

  return (
    <group ref={groupRef} position={[0, 1.35, 0]}>
      {/* Central Biomechanical Torso & Cybernetic Core */}
      <mesh castShadow>
        <capsuleGeometry args={[0.13, 0.42, 6, 12]} />
        <meshStandardMaterial
          color="#0e171e"
          roughness={0.55}
          metalness={0.4}
          emissive={fluidColor}
          emissiveIntensity={isCritical ? 0.4 : 0.15}
        />
      </mesh>
      {/* Luminescent Spine Column */}
      {[-0.16, -0.08, 0.0, 0.08, 0.16].map((y, idx) => (
        <mesh key={idx} position={[0, y, -0.11]}>
          <boxGeometry args={[0.06, 0.035, 0.04]} />
          <meshBasicMaterial color={isCritical ? '#ff1744' : fluidColor} toneMapped={false} />
        </mesh>
      ))}
      {/* Cybernetic Head & Neural Interface Visor */}
      <group position={[0, 0.38, 0]}>
        <mesh castShadow>
          <sphereGeometry args={[0.11, 12, 10]} />
          <meshStandardMaterial color="#121d26" roughness={0.6} metalness={0.3} />
        </mesh>
        {/* Optic / Neural Sensor Band */}
        <mesh position={[0, 0.02, 0.09]}>
          <boxGeometry args={[0.13, 0.03, 0.03]} />
          <meshBasicMaterial color={isCritical ? '#ff1744' : fluidColor} toneMapped={false} />
        </mesh>
        {/* Nitrogen Feeding Tube / Cable up to Pod Lid */}
        <mesh position={[0, 0.35, 0]}>
          <cylinderGeometry args={[0.016, 0.016, 0.52, 6]} />
          <meshStandardMaterial color="#080e14" metalness={0.8} />
        </mesh>
      </group>
      {/* Suspended Folded Limbs (Embryonic Float) */}
      {[-0.16, 0.16].map((x, i) => (
        <group key={i} position={[x, 0.1, 0]}>
          <mesh rotation={[0.45, 0, (i === 0 ? 1 : -1) * 0.35]}>
            <capsuleGeometry args={[0.042, 0.24, 4, 8]} />
            <meshStandardMaterial color="#101a22" roughness={0.65} />
          </mesh>
          <mesh position={[(i === 0 ? 0.05 : -0.05), -0.18, 0.05]} rotation={[-0.3, 0, (i === 0 ? -0.8 : 0.8)]}>
            <capsuleGeometry args={[0.035, 0.22, 4, 8]} />
            <meshStandardMaterial color="#0b1218" roughness={0.7} />
          </mesh>
        </group>
      ))}
      {/* Lower Limbs Suspended in Stasis */}
      {[-0.08, 0.08].map((x, i) => (
        <group key={i} position={[x, -0.28, 0]}>
          <mesh rotation={[0.4, 0, (i === 0 ? 0.12 : -0.12)]}>
            <capsuleGeometry args={[0.048, 0.28, 4, 8]} />
            <meshStandardMaterial color="#0f1922" roughness={0.65} />
          </mesh>
          <mesh position={[0, -0.28, 0.06]} rotation={[-0.45, 0, 0]}>
            <capsuleGeometry args={[0.04, 0.26, 4, 8]} />
            <meshStandardMaterial color="#0a1218" roughness={0.7} />
          </mesh>
        </group>
      ))}
      {/* Floating Micro Cryo-Bubbles */}
      <group ref={bubblesRef}>
        {[
          [-0.16, 0.14],
          [0.2, -0.12],
          [-0.08, -0.2],
          [0.14, 0.18],
        ].map(([bx, bz], bi) => (
          <mesh key={bi} position={[bx, 0, bz]}>
            <sphereGeometry args={[0.022, 6, 6]} />
            <meshBasicMaterial color="#ffffff" transparent opacity={0.65} toneMapped={false} />
          </mesh>
        ))}
      </group>
    </group>
  );
}

// -------------------------------------------------------------
// ULTRA HIGH-QUALITY STASIS CAPSULE (Advanced Shader & Geometry)
// -------------------------------------------------------------
function UltraStasisPod({

  position,
  rotation = [0, 0, 0],
  scale = 1.0,
  label,
  fluidColor = '#00f0ff',
  fluidIntensity = 2.4,
  isCritical = false,
  isShattered = false,
}: {
  position: [number, number, number];
  rotation?: [number, number, number];
  scale?: number;
  label: string;
  fluidColor?: string;
  fluidIntensity?: number;
  isCritical?: boolean;
  isShattered?: boolean;
}) {
  const glassRef = useRef<MeshStandardMaterial>(null);

  useFrame(({ clock }) => {
    if (glassRef.current && isCritical) {
      const time = clock.getElapsedTime();
      glassRef.current.emissiveIntensity = 0.25 + Math.sin(time * 6.0) * 0.2;
    }
  });

  return (
    <group position={position} rotation={rotation} scale={scale} name={`stasis-pod-${label}`}>
      {/* Heavy Cylindrical Base Platform */}
      <mesh position={[0, 0.2, 0]} castShadow receiveShadow>
        <cylinderGeometry args={[0.78, 0.88, 0.4, 16]} />
        <meshStandardMaterial color="#080e14" metalness={0.85} roughness={0.32} />
      </mesh>
      <mesh position={[0, 0.42, 0]}>
        <cylinderGeometry args={[0.72, 0.72, 0.06, 16]} />
        <meshStandardMaterial color="#142834" metalness={0.7} roughness={0.4} />
      </mesh>

      {/* Top Cap & Hydraulic Piston Mount */}
      <mesh position={[0, 2.7, 0]} castShadow>
        <cylinderGeometry args={[0.82, 0.76, 0.35, 16]} />
        <meshStandardMaterial color="#080e14" metalness={0.88} roughness={0.3} />
      </mesh>
      {/* Nitrogen Coolant Feed Pipes into ceiling */}
      <mesh position={[0, 3.2, 0]}>
        <cylinderGeometry args={[0.08, 0.08, 0.8, 8]} />
        <meshStandardMaterial color="#1a3340" metalness={0.75} roughness={0.3} />
      </mesh>

      {/* Structural Support Pillars */}
      {[-0.62, 0.62].map((x, i) => (
        <mesh key={i} position={[x, 1.45, -0.2]} castShadow>
          <cylinderGeometry args={[0.045, 0.045, 2.2, 8]} />
          <meshStandardMaterial color="#12202a" metalness={0.82} roughness={0.35} />
        </mesh>
      ))}

      {/* Transparent Cryo-Fluid Glass Cylinder */}
      {!isShattered ? (
        <mesh position={[0, 1.45, 0]}>
          <cylinderGeometry args={[0.62, 0.62, 2.15, 20, 1, true]} />
          <meshStandardMaterial
            ref={glassRef}
            color={fluidColor}
            emissive={isCritical ? '#ff1144' : fluidColor}
            emissiveIntensity={isCritical ? 0.35 : 0.12}
            roughness={0.15}
            metalness={0.2}
            transparent
            opacity={0.38}
            side={DoubleSide}
          />
        </mesh>
      ) : (
        /* Shattered Glass Shards & Ruptured Mesh */
        <group position={[0, 1.45, 0]}>
          {[-0.3, 0, 0.3].map((sx, idx) => (
            <mesh key={idx} position={[sx, -0.4, 0.2 + idx * 0.1]} rotation={[0.4, idx * 0.5, 0.2]}>
              <planeGeometry args={[0.3, 0.45]} />
              <meshStandardMaterial
                color={fluidColor}
                roughness={0.1}
                transparent
                opacity={0.4}
                side={DoubleSide}
              />
            </mesh>
          ))}
        </group>
      )}




      {/* Living Suspended Cybernetic Specimen inside Tube (for non-boss pods) */}
      {label !== 'SPECIMEN EX-000' && !isShattered && (
        <StasisPodSpecimen
          fluidColor={isCritical ? '#ff1144' : fluidColor}
          isCritical={isCritical}
          seed={parseInt(label.replace(/\D/g, '') || '1', 10)}
        />
      )}


      {/* Interior Stasis Lighting */}
      <pointLight
        position={[0, 1.35, 0]}
        color={isCritical ? '#ff1144' : fluidColor}
        intensity={isShattered ? 1.2 : fluidIntensity}
        distance={3.8}
        decay={2}
      />

      {/* Holographic Status Label */}
      <mesh position={[0, 2.52, 0.65]}>
        <planeGeometry args={[0.55, 0.14]} />
        <meshBasicMaterial
          color={isCritical ? '#ff1144' : '#00f0ff'}
          toneMapped={false}
        />
      </mesh>
    </group>
  );
}

// -------------------------------------------------------------
// END MONUMENT: 5-METER QUARANTINE BLAST VAULT DOOR (Z = -14.5)
// -------------------------------------------------------------
function QuarantineBlastVault({
  isBreached = false,
}: {
  isBreached?: boolean;
}) {
  const gearRef = useRef<Group>(null);

  useFrame(({ clock }) => {
    if (gearRef.current) {
      gearRef.current.rotation.z = Math.sin(clock.getElapsedTime() * 0.2) * 0.04;
    }
  });

  return (
    <group position={[0, 2.5, -14.35]} name="quarantine-blast-vault">
      {/* Massive Outer Vault Portal Frame */}
      <mesh receiveShadow>
        <boxGeometry args={[9.5, 5.8, 0.6]} />
        <meshStandardMaterial color="#05090e" metalness={0.92} roughness={0.3} />
      </mesh>

      {/* Circular Vault Recess */}
      <mesh position={[0, 0, 0.25]} rotation={[Math.PI / 2, 0, 0]}>
        <cylinderGeometry args={[2.5, 2.5, 0.3, 32]} />
        <meshStandardMaterial color="#080e15" metalness={0.85} roughness={0.4} />
      </mesh>

      {/* Interlocking Blast Teeth & Rotating Gear */}
      <group ref={gearRef} position={[0, 0, 0.38]}>
        <mesh>
          <torusGeometry args={[2.2, 0.18, 12, 32]} />
          <meshStandardMaterial color="#16222d" metalness={0.88} roughness={0.25} />
        </mesh>
        {[0, 45, 90, 135, 180, 225, 270, 315].map((deg) => {
          const rad = (deg * Math.PI) / 180;
          return (
            <mesh
              key={deg}
              position={[Math.cos(rad) * 1.75, Math.sin(rad) * 1.75, 0.05]}
              rotation={[0, 0, rad]}
            >
              <boxGeometry args={[0.5, 0.22, 0.18]} />
              <meshStandardMaterial color="#223344" metalness={0.9} roughness={0.28} />
            </mesh>
          );
        })}
      </group>

      {/* Heavy Hydraulic Locking Pistons */}
      {[-2.1, 2.1].map((px, i) => (
        <mesh key={i} position={[px, 0, 0.4]} rotation={[0, 0, Math.PI / 2]}>
          <cylinderGeometry args={[0.15, 0.15, 1.4, 12]} />
          <meshStandardMaterial color="#1f303c" metalness={0.85} roughness={0.3} />
        </mesh>
      ))}

      {/* High-Voltage Conduit Core & Warning Beacon */}
      <pointLight
        position={[0, 0, 0.8]}
        color={isBreached ? '#ff0033' : '#00e5ff'}
        intensity={2.8}
        distance={6.0}
        decay={2}
      />
      <mesh position={[0, 2.2, 0.42]}>
        <planeGeometry args={[2.2, 0.3]} />
        <meshBasicMaterial color="#ff2244" toneMapped={false} />
      </mesh>
    </group>
  );
}

// -------------------------------------------------------------
// WEAPON CRATE & TACTICAL CYBER-KATANA — Interactive animated chest
// -------------------------------------------------------------
function CyberKatanaPickup({
  hasWeapon,
  focused,
  onPickup,
}: {
  hasWeapon: boolean;
  focused: boolean;
  onPickup?: () => void;
}) {
  const lidRef = useRef<Group>(null);
  const bladeRef = useRef<Group>(null);
  const burstLightRef = useRef<any>(null);
  const [isOpen, setIsOpen] = useState(false);
  const openProgressRef = useRef(0);

  useFrame(({ clock }, delta) => {
    if (isOpen) {
      openProgressRef.current = Math.min(1, openProgressRef.current + delta * 1.4);
    }
    const t = openProgressRef.current;

    // Lid opens: rotates -90° around front-bottom edge
    if (lidRef.current) {
      lidRef.current.rotation.x = -t * Math.PI * 0.5;
    }

    // Katana floats up out of chest after lid is half-open
    if (bladeRef.current) {
      const bladeT = Math.max(0, (t - 0.4) / 0.6);
      const time = clock.getElapsedTime();
      bladeRef.current.position.y = bladeT * 0.55 + Math.sin(time * 2.2) * 0.025 * bladeT;
      bladeRef.current.rotation.y = time * 0.6 * bladeT;
      bladeRef.current.visible = t > 0.1;
    }

    // Burst light pulses on open
    if (burstLightRef.current) {
      const burstT = Math.max(0, (t - 0.4) / 0.6);
      burstLightRef.current.intensity = burstT > 0 ? (2.5 + Math.sin(clock.getElapsedTime() * 8) * 0.8) * burstT : 0;
    }
  });

  if (hasWeapon) return null;

  const handleOpen = (e: any) => {
    e.stopPropagation();
    if (!isOpen) {
      setIsOpen(true);
      // Delay actual weapon pickup until chest is fully open
      setTimeout(() => onPickup?.(), 900);
    }
  };

  return (
    <group
      position={KATANA_POSITION}
      name="cyber-katana-chest"
      onClick={handleOpen}
      onPointerOver={() => {
        if (typeof document !== 'undefined') document.body.style.cursor = 'pointer';
      }}
      onPointerOut={() => {
        if (typeof document !== 'undefined') document.body.style.cursor = 'default';
      }}
    >
      {/* === CHEST BODY === */}
      <mesh position={[0, -0.25, 0]} castShadow receiveShadow>
        <boxGeometry args={[1.1, 0.55, 0.65]} />
        <meshStandardMaterial color="#0c1218" metalness={0.88} roughness={0.35} />
      </mesh>
      {/* Chest trim strips */}
      {[-0.52, 0.52].map((x) => (
        <mesh key={x} position={[x, -0.25, 0]} castShadow>
          <boxGeometry args={[0.045, 0.57, 0.67]} />
          <meshStandardMaterial color="#1a2c3a" metalness={0.92} roughness={0.22} emissive="#003344" emissiveIntensity={0.4} />
        </mesh>
      ))}
      {/* Chest front panel — glowing cyan seam */}
      <mesh position={[0, -0.25, 0.325]}>
        <boxGeometry args={[1.08, 0.52, 0.01]} />
        <meshStandardMaterial color="#050d14" metalness={0.8} emissive="#00a0c0" emissiveIntensity={isOpen ? 1.8 : 0.6} />
      </mesh>

      {/* === LID (pivots from back edge) === */}
      <group ref={lidRef} position={[0, 0.04, -0.32]}>
        <mesh position={[0, 0.14, 0.32]} castShadow>
          <boxGeometry args={[1.1, 0.28, 0.65]} />
          <meshStandardMaterial color="#0e1a24" metalness={0.86} roughness={0.38} />
        </mesh>
        {/* Lid trim */}
        {[-0.52, 0.52].map((x) => (
          <mesh key={x} position={[x, 0.14, 0.32]}>
            <boxGeometry args={[0.045, 0.30, 0.67]} />
            <meshStandardMaterial color="#162535" metalness={0.9} roughness={0.28} emissive="#002233" emissiveIntensity={0.3} />
          </mesh>
        ))}
      </group>

      {/* === KATANA (hidden inside, floats up on open) === */}
      <group ref={bladeRef} position={[0, 0.02, 0]} visible={false}>
        {/* Handle */}
        <mesh position={[0, -0.22, 0]}>
          <cylinderGeometry args={[0.024, 0.026, 0.28, 8]} />
          <meshStandardMaterial color="#080a0f" metalness={0.9} roughness={0.2} />
        </mesh>
        {/* Guard */}
        <mesh position={[0, -0.07, 0]}>
          <boxGeometry args={[0.09, 0.015, 0.05]} />
          <meshStandardMaterial color="#2a3a46" metalness={0.92} roughness={0.2} />
        </mesh>
        {/* Blade */}
        <mesh position={[0, 0.42, 0]} castShadow>
          <boxGeometry args={[0.018, 1.0, 0.045]} />
          <meshStandardMaterial
            color="#05080c"
            emissive="#00f0ff"
            emissiveIntensity={1.8}
            metalness={0.95}
            roughness={0.08}
          />
        </mesh>
        {/* Katana glow light */}
        <pointLight ref={burstLightRef} color="#00f0ff" intensity={0} distance={3.0} decay={2} />
      </group>

      <InteractiveHighlight active={focused && !isOpen} radius={0.8} position={[0, 0.2, 0]} />
    </group>
  );
}


function HolographicConsole({ position, rotation }: { position: [number, number, number], rotation: [number, number, number] }) {
  return (
    <group position={position} rotation={rotation}>
      <mesh position={[0, 0, 0.05]} castShadow>
        <boxGeometry args={[1.2, 0.8, 0.1]} />
        <meshStandardMaterial color="#0a1520" metalness={0.9} roughness={0.3} />
      </mesh>
      <mesh position={[0, 0.1, 0.11]}>
        <planeGeometry args={[1.0, 0.5]} />
        <meshBasicMaterial color="#00f0ff" transparent opacity={0.6} toneMapped={false} />
      </mesh>
      <mesh position={[0, -0.2, 0.11]}>
        <planeGeometry args={[0.8, 0.05]} />
        <meshBasicMaterial color="#ff0055" transparent opacity={0.8} toneMapped={false} />
      </mesh>
    </group>
  );
}

function ServerRack({ position, rotation }: { position: [number, number, number], rotation: [number, number, number] }) {
  return (
    <group position={position} rotation={rotation} castShadow>
      <mesh position={[0, 1.2, 0]}>
        <boxGeometry args={[0.8, 2.4, 0.8]} />
        <meshStandardMaterial color="#05090e" metalness={0.9} roughness={0.2} />
      </mesh>
      {[0.4, 0.8, 1.2, 1.6, 2.0].map((y) => (
        <mesh key={y} position={[0, y, 0.41]}>
          <planeGeometry args={[0.6, 0.1]} />
          <meshBasicMaterial color="#00e5ff" toneMapped={false} />
        </mesh>
      ))}
    </group>
  );
}

function MedicalEquipment({ position, rotation }: { position: [number, number, number], rotation: [number, number, number] }) {
  return (
    <group position={position} rotation={rotation}>
      <mesh position={[0, 0.6, 0]}>
        <cylinderGeometry args={[0.4, 0.4, 1.2, 16]} />
        <meshStandardMaterial color="#b0c4de" metalness={0.8} roughness={0.2} />
      </mesh>
      <mesh position={[0, 1.4, 0]}>
        <sphereGeometry args={[0.3, 16, 16]} />
        <meshStandardMaterial color="#00f0ff" emissive="#00f0ff" emissiveIntensity={0.5} transparent opacity={0.8} />
      </mesh>
    </group>
  );
}

function WarningSigns({ position, rotation }: { position: [number, number, number], rotation: [number, number, number] }) {
  return (
    <mesh position={position} rotation={rotation}>
      <planeGeometry args={[1.5, 0.4]} />
      <meshBasicMaterial color="#ffaa00" toneMapped={false} />
      {/* Hazard stripes using a simple texture or geometry... We'll just use basic emissive for now */}
    </mesh>
  );
}

// -------------------------------------------------------------
// RESEARCH TERMINAL (Sub-Lab Alpha Interactive Lore Station)
// -------------------------------------------------------------
function ResearchTerminal({ position, rotation = [0, 0, 0], focused = false }: { position: [number, number, number]; rotation?: [number, number, number]; focused?: boolean }) {
  const screenRef = useRef<any>(null);

  useFrame(({ clock }) => {
    if (screenRef.current) {
      screenRef.current.emissiveIntensity = 1.4 + Math.sin(clock.getElapsedTime() * 3.5) * 0.3;
    }
  });

  return (
    <group position={position} rotation={rotation} name="sublab-terminal">
      {/* Terminal Pedestal Base */}
      <mesh position={[0, 0.45, 0]} castShadow receiveShadow>
        <cylinderGeometry args={[0.3, 0.42, 0.9, 8]} />
        <meshStandardMaterial color="#0b1218" metalness={0.85} roughness={0.3} />
      </mesh>
      {/* Keyboard Desk Console */}
      <mesh position={[0, 0.92, 0.12]} rotation={[-Math.PI / 8, 0, 0]} castShadow>
        <boxGeometry args={[0.85, 0.08, 0.45]} />
        <meshStandardMaterial color="#14222e" metalness={0.88} roughness={0.25} />
      </mesh>
      {/* Slanted Holographic Display Screen */}
      <group position={[0, 1.28, -0.04]} rotation={[-Math.PI / 10, 0, 0]}>
        <mesh castShadow>
          <boxGeometry args={[0.92, 0.58, 0.04]} />
          <meshStandardMaterial color="#080e14" metalness={0.9} roughness={0.2} />
        </mesh>
        <mesh position={[0, 0, 0.025]}>
          <planeGeometry args={[0.86, 0.52]} />
          <meshStandardMaterial
            ref={screenRef}
            color="#002b3d"
            emissive="#00e5ff"
            emissiveIntensity={1.4}
            roughness={0.1}
          />
        </mesh>
        <pointLight position={[0, 0, 0.35]} color="#00e5ff" intensity={2.2} distance={3.5} decay={2} />
      </group>
      <InteractiveHighlight active={focused} radius={0.7} position={[0, 1.0, 0]} />
    </group>
  );
}

// -------------------------------------------------------------
// DYNAMIC STEAM VENT (High-Pressure Cryo Release Puffs)
// -------------------------------------------------------------
function SteamVent({ position, rotation = [0, 0, 0] }: { position: [number, number, number]; rotation?: [number, number, number] }) {
  const puffRef = useRef<Group>(null);
  const puffMaterialRefs = useRef<(MeshBasicMaterial | null)[]>([]);

  useFrame(({ clock }) => {
    if (puffRef.current) {
      const time = clock.getElapsedTime();
      const cycle = (time % 3.5);
      const active = cycle < 1.2;
      puffRef.current.visible = active;
      if (active) {
        const t = cycle / 1.2;
        const expansion = 0.72 + t * 1.45;
        puffRef.current.scale.set(expansion, expansion, 0.8 + t * 1.8);
        puffRef.current.position.z = 0.18 + t * 0.5;
        puffRef.current.position.y = 0.05 + Math.sin(t * Math.PI) * 0.12;
        puffMaterialRefs.current.forEach((material, index) => {
          if (material) material.opacity = (1 - t) * (0.09 - index * 0.008);
        });
      }
    }
  });

  return (
    <group position={position} rotation={rotation}>
      {/* Wall Flange & Pipe Nozzle */}
      <mesh rotation={[Math.PI / 2, 0, 0]}>
        <cylinderGeometry args={[0.12, 0.14, 0.22, 12]} />
        <meshStandardMaterial color="#1a2530" metalness={0.9} roughness={0.3} />
      </mesh>
      <group ref={puffRef} position={[0, 0.05, 0.18]}>
        {Array.from({ length: 5 }, (_, index) => (
          <mesh
            key={index}
            position={[
              ((index % 2) - 0.5) * 0.12,
              (index % 3) * 0.055,
              index * 0.105,
            ]}
            scale={[1 + index * 0.08, 0.72 + index * 0.06, 1.25]}
          >
            <sphereGeometry args={[0.14, 10, 7]} />
            <meshBasicMaterial
              ref={(material) => { puffMaterialRefs.current[index] = material; }}
              color="#bfefff"
              transparent
              opacity={0.09 - index * 0.008}
              depthWrite={false}
            />
          </mesh>
        ))}
      </group>
    </group>
  );
}

// -------------------------------------------------------------
// SPARKING ELECTRICAL CONDUIT (Atmospheric Hazard Juice)
// -------------------------------------------------------------
function SparkingCable({ position }: { position: [number, number, number] }) {
  const lightRef = useRef<any>(null);

  useFrame(({ clock }) => {
    if (lightRef.current) {
      const time = clock.getElapsedTime();
      // Erratic electric spark bursts
      const spark = Math.sin(time * 28.0) > 0.88 && Math.sin(time * 4.5) > 0.3;
      lightRef.current.intensity = spark ? 6.5 : 0;
    }
  });

  return (
    <group position={position}>
      <mesh position={[0, 0, 0]}>
        <cylinderGeometry args={[0.02, 0.02, 0.8, 6]} />
        <meshStandardMaterial color="#080c10" metalness={0.8} />
      </mesh>
      <pointLight ref={lightRef} color="#70d6ff" intensity={0} distance={3.0} decay={2} />
    </group>
  );
}

function CeilingGrates() {
  return (
    <group position={[0, 6.1, 1.0]}>
      {[-12, -4, 4, 12].map((z) => (
        <group key={z} position={[0, -0.05, z]} rotation={[Math.PI / 2, 0, 0]}>
          <mesh>
            <planeGeometry args={[3.0, 2.0]} />
            <meshStandardMaterial color="#050a10" metalness={0.9} roughness={0.2} wireframe />
          </mesh>
          <pointLight position={[0, 0, -0.2]} color="#ffffff" intensity={1.5} distance={3.0} decay={2} />
        </group>
      ))}
    </group>
  );
}

const CORRIDOR_PANEL_Z = [-13, -9, -5, -1, 3, 7, 11, 15] as const;

function CorridorFloor() {
  return (
    <group name="main-corridor-floor">
      <mesh position={[0, -0.015, 1]} rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[10, 32]} />
        <meshStandardMaterial color="#071018" roughness={0.5} metalness={0.68} />
      </mesh>

      {CORRIDOR_PANEL_Z.map((z, index) => (
        <group key={z} position={[0, 0.002, z]} rotation={[-Math.PI / 2, 0, 0]}>
          {([-1, 1] as const).map((side) => (
            <mesh key={side} position={[side * 3.05, 0, 0]} receiveShadow>
              <planeGeometry args={[3.38, 3.72]} />
              <meshStandardMaterial
                color={index % 2 === 0 ? '#101d28' : '#0c1822'}
                roughness={index % 2 === 0 ? 0.34 : 0.44}
                metalness={0.72}
              />
            </mesh>
          ))}
          <mesh position={[0, 0, 0]} receiveShadow>
            <planeGeometry args={[2.22, 3.72]} />
            <meshStandardMaterial
              color={index % 2 === 0 ? '#142636' : '#102130'}
              roughness={0.38}
              metalness={0.64}
            />
          </mesh>
        </group>
      ))}

      {([-3.8, 3.8] as const).map((x) => (
        <group key={x} position={[x, 0.008, 1]} rotation={[-Math.PI / 2, 0, 0]}>
          <mesh position={[0, 0, -0.002]} receiveShadow>
            <planeGeometry args={[0.16, 32]} />
            <meshStandardMaterial color="#071018" roughness={0.24} metalness={0.9} />
          </mesh>
          <mesh position={[0, 0, 0.003]}>
            <planeGeometry args={[0.045, 31.7]} />
            <meshBasicMaterial color="#27d9ec" toneMapped={false} />
          </mesh>
        </group>
      ))}
    </group>
  );
}

// -------------------------------------------------------------
// MAIN ARCHITECTURE & NESTED SUB-CHAMBERS
// -------------------------------------------------------------

// MAIN ARCHITECTURE & NESTED SUB-CHAMBERS (WET MIRROR CYBER FLOOR)
function MainCorridorAndWings({ focusedInteractionId = null }: { focusedInteractionId?: string | null }) {
  return (
    <group name="opening-room-geometry">
      <CeilingGrates />

      {/* Interactive Research Terminal in Sub-Lab Alpha */}
      <ResearchTerminal
        position={[8.5, 0, 7.5]}
        rotation={[0, 0, 0]}
        focused={focusedInteractionId === 'sublab-terminal'}
      />

      {/* Atmospheric High-Pressure Steam Vents */}
      <SteamVent position={[-4.85, 2.2, 2.5]} rotation={[0, Math.PI / 2, 0]} />
      <SteamVent position={[4.85, 2.0, -1.5]} rotation={[0, -Math.PI / 2, 0]} />
      <SteamVent position={[13.4, 2.5, 5.5]} rotation={[0, -Math.PI / 2, 0]} />

      {/* Sparking Overhead Electrical Conduits */}
      <SparkingCable position={[-2.5, 5.8, -6.0]} />
      <SparkingCable position={[7.5, 5.8, 2.0]} />
      <SparkingCable position={[10.1, 5.8, -3.8]} />

      <CorridorFloor />

      {/* Floor Grating Strips & Conduit Lights along Main Corridor */}
      {[-12, -8, -4, 0, 4, 8, 12, 15].map((z) => (
        <group key={z} position={[0, 0.006, z]} rotation={[-Math.PI / 2, 0, 0]}>
          <mesh receiveShadow>
            <planeGeometry args={[7.8, 0.6]} />
            <meshStandardMaterial color="#1f3348" metalness={0.85} roughness={0.3} />
          </mesh>
          <mesh position={[-3.4, 0, 0.002]}>
            <planeGeometry args={[0.2, 0.55]} />
            <meshBasicMaterial color="#00f0ff" toneMapped={false} />
          </mesh>
          <mesh position={[3.4, 0, 0.002]}>
            <planeGeometry args={[0.2, 0.55]} />
            <meshBasicMaterial color="#00f0ff" toneMapped={false} />
          </mesh>
        </group>
      ))}

      {/* Corridor Wall Emissive Trim Strips & Details */}
      {[-10, -6, -2, 2, 6, 10, 14].map((z) => (
        <group key={z}>
          <HolographicConsole position={[-4.75, 1.5, z]} rotation={[0, Math.PI / 2, 0]} />
          <mesh position={[-4.8, 0.5, z]}>
            <planeGeometry args={[0.5, 0.1]} />
            <meshBasicMaterial color="#00f0ff" toneMapped={false} />
          </mesh>
        </group>
      ))}

      {/* 2. Main Corridor West Wall (x = -4.9) - Illuminated Anime Sci-Fi Panels */}
      <mesh position={[-4.9, 3.1, 1.0]} receiveShadow>
        <boxGeometry args={[0.2, 6.2, 32]} />
        <meshStandardMaterial color="#1e2c3c" roughness={0.3} metalness={0.7} />
      </mesh>
      {/* West Wall Illuminated Neon Strip */}
      <mesh position={[-4.78, 1.8, 1.0]}>
        <planeGeometry args={[0.08, 32]} />
        <meshBasicMaterial color="#00e5ff" toneMapped={false} />
      </mesh>

      {/* 3. Main Corridor North Wall (Behind Awakening Dais at z = 16.9) */}
      <mesh position={[0, 3.1, 16.9]} receiveShadow>
        <boxGeometry args={[10, 6.2, 0.2]} />
        <meshStandardMaterial color="#1a2636" roughness={0.4} metalness={0.6} />
      </mesh>
      {/* North Wall Sci-Fi Emissive Logo & Conduit Band */}
      <mesh position={[0, 3.2, 16.78]}>
        <planeGeometry args={[4.5, 0.2]} />
        <meshBasicMaterial color="#00f0ff" toneMapped={false} />
      </mesh>

      {/* 4. Main Corridor East Dividing Walls (Forming ENTRANCE 1 at z = 5.5 to 8.5) */}
      {/* Upper East Wall (z = 8.5 to 16.9) */}
      <mesh position={[4.9, 3.1, 12.7]} receiveShadow>
        <boxGeometry args={[0.2, 6.2, 8.4]} />
        <meshStandardMaterial color="#1e2c3c" roughness={0.3} metalness={0.7} />
      </mesh>
      {/* Lower East Wall (z = -14.5 to 5.5) */}
      <mesh position={[4.9, 3.1, -4.5]} receiveShadow>
        <boxGeometry args={[0.2, 6.2, 20.0]} />
        <meshStandardMaterial color="#1e2c3c" roughness={0.3} metalness={0.7} />
      </mesh>

      {/* ENTRANCE 1 PORTAL ARCHWAY (Sub-Lab Alpha at x = 4.9, z = 7.0) */}
      <group position={[4.9, 2.2, 7.0]}>
        <mesh position={[0, 1.8, 0]}>
          <boxGeometry args={[0.4, 0.6, 3.2]} />
          <meshStandardMaterial color="#101a22" metalness={0.85} roughness={0.3} />
        </mesh>
        <mesh position={[0, -0.6, -1.5]}>
          <boxGeometry args={[0.4, 3.6, 0.25]} />
          <meshStandardMaterial color="#101a22" metalness={0.85} roughness={0.3} />
        </mesh>
        <mesh position={[0, -0.6, 1.5]}>
          <boxGeometry args={[0.4, 3.6, 0.25]} />
          <meshStandardMaterial color="#101a22" metalness={0.85} roughness={0.3} />
        </mesh>
        {/* Entrance 1 Signboard */}
        <mesh position={[-0.22, 1.65, 0]} rotation={[0, -Math.PI / 2, 0]}>
          <planeGeometry args={[1.8, 0.25]} />
          <meshBasicMaterial color="#00e5ff" toneMapped={false} />
        </mesh>
      </group>

      {/* ------------------------------------------------------------- */}
      {/* SUB-LAB ALPHA: Neural Diagnostics (x: 4.9 to 13.5, z: 4.0 to 11.0) */}
      {/* ------------------------------------------------------------- */}
      <mesh position={[9.2, 0, 7.5]} rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[8.6, 7.0]} />
        <meshStandardMaterial
          color="#06121c"
          roughness={0.24}
          metalness={0.85}
        />
      </mesh>

      {/* Server Racks in Sub-Lab Alpha */}
      <ServerRack position={[12.5, 0, 9.5]} rotation={[0, -Math.PI / 2, 0]} />
      <ServerRack position={[12.5, 0, 8.0]} rotation={[0, -Math.PI / 2, 0]} />
      <ServerRack position={[12.5, 0, 6.5]} rotation={[0, -Math.PI / 2, 0]} />

      {/* Sub-Lab Alpha North Wall (z = 11.0) */}
      <mesh position={[9.2, 3.1, 11.0]} receiveShadow>
        <boxGeometry args={[8.6, 6.2, 0.2]} />
        <meshStandardMaterial color="#070c12" roughness={0.5} metalness={0.6} />
      </mesh>
      {/* Sub-Lab Alpha East Wall (x = 13.5, z = 4.0 to 11.0) */}
      <mesh position={[13.5, 3.1, 7.5]} receiveShadow>
        <boxGeometry args={[0.2, 6.2, 7.0]} />
        <meshStandardMaterial color="#070c12" roughness={0.5} metalness={0.6} />
      </mesh>

      {/* DIVIDER WALL: Alpha to Beta with ENTRANCE 2 at x = 7.5, z = 4.0 */}
      <mesh position={[5.7, 3.1, 4.0]} receiveShadow>
        <boxGeometry args={[1.6, 6.2, 0.2]} />
        <meshStandardMaterial color="#070c12" roughness={0.5} metalness={0.6} />
      </mesh>
      <mesh position={[11.0, 3.1, 4.0]} receiveShadow>
        <boxGeometry args={[5.0, 6.2, 0.2]} />
        <meshStandardMaterial color="#070c12" roughness={0.5} metalness={0.6} />
      </mesh>
      {/* ENTRANCE 2 BULKHEAD (x = 7.5, z = 4.0) */}
      <group position={[7.5, 2.2, 4.0]}>
        <mesh position={[0, 1.8, 0]}>
          <boxGeometry args={[2.0, 0.6, 0.35]} />
          <meshStandardMaterial color="#1a2010" metalness={0.8} roughness={0.35} />
        </mesh>
        {/* Hazard Yellow Warning Band */}
        <mesh position={[0, 1.65, 0.19]}>
          <planeGeometry args={[1.8, 0.22]} />
          <meshBasicMaterial color="#ffbb00" toneMapped={false} />
        </mesh>
      </group>

      {/* ------------------------------------------------------------- */}
      {/* SUB-CHAMBER BETA: Genetic Quarantine (x: 5.0 to 13.5, z: -4.0 to 4.0) */}
      {/* ------------------------------------------------------------- */}
      <mesh position={[9.2, 0, 0]} rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[8.6, 8.0]} />
        <meshStandardMaterial
          color="#061018"
          roughness={0.24}
          metalness={0.85}
        />
      </mesh>

      {/* Medical/Genetic Equipment in Sub-Chamber Beta */}
      <MedicalEquipment position={[10.0, 0, 2.0]} rotation={[0, 0, 0]} />
      <MedicalEquipment position={[10.0, 0, -2.0]} rotation={[0, 0, 0]} />
      <HolographicConsole position={[13.2, 1.5, 0]} rotation={[0, -Math.PI / 2, 0]} />

      {/* Sub-Chamber Beta East Wall (x = 13.5, z = -4.0 to 4.0) */}
      <mesh position={[13.5, 3.1, 0]} receiveShadow>
        <boxGeometry args={[0.2, 6.2, 8.0]} />
        <meshStandardMaterial color="#06090e" roughness={0.5} metalness={0.6} />
      </mesh>

      {/* DIVIDER WALL: Beta to Deep Vault with ENTRANCE 3 at x = 10.1, z = -4.0 */}
      <mesh position={[6.8, 3.1, -4.0]} receiveShadow>
        <boxGeometry args={[3.8, 6.2, 0.2]} />
        <meshStandardMaterial color="#05070a" roughness={0.6} metalness={0.7} />
      </mesh>
      <mesh position={[12.6, 3.1, -4.0]} receiveShadow>
        <boxGeometry args={[1.8, 6.2, 0.2]} />
        <meshStandardMaterial color="#05070a" roughness={0.6} metalness={0.7} />
      </mesh>
      {/* ENTRANCE 3 VAULT AIRLOCK (x = 10.1, z = -4.0) */}
      <group position={[10.1, 2.2, -4.0]}>
        <WarningSigns position={[0, 2.2, 0.24]} rotation={[0, 0, 0]} />
        <mesh position={[0, 1.8, 0]}>
          <boxGeometry args={[2.8, 0.6, 0.45]} />
          <meshStandardMaterial color="#1a080c" metalness={0.9} roughness={0.25} />
        </mesh>
        {/* Red Bio-Hazard Strobe Light */}
        <pointLight position={[0, 1.8, 0.35]} color="#ff0044" intensity={3.2} distance={4.0} />
        <mesh position={[0, 1.65, 0.24]}>
          <planeGeometry args={[2.2, 0.22]} />
          <meshBasicMaterial color="#ff0033" toneMapped={false} />
        </mesh>
      </group>

      {/* ------------------------------------------------------------- */}
      {/* DEEP CONTAINMENT VAULT: SPECIMEN EX-000 (x: 8.0 to 13.5, z: -12.0 to -4.0) */}
      {/* ------------------------------------------------------------- */}
      <mesh position={[10.75, 0, -8.0]} rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[5.5, 8.0]} />
        <meshStandardMaterial
          color="#07080e"
          roughness={0.25}
          metalness={0.9}
        />
      </mesh>
      {/* Vault West Wall (x = 8.0) */}
      <mesh position={[8.0, 3.1, -8.0]} receiveShadow>
        <boxGeometry args={[0.2, 6.2, 8.0]} />
        <meshStandardMaterial color="#04060a" roughness={0.65} metalness={0.5} />
      </mesh>
      {/* Vault East Wall (x = 13.5) */}
      <mesh position={[13.5, 3.1, -8.0]} receiveShadow>
        <boxGeometry args={[0.2, 6.2, 8.0]} />
        <meshStandardMaterial color="#04060a" roughness={0.65} metalness={0.5} />
      </mesh>
      {/* Vault South Wall (z = -12.0) */}
      <mesh position={[10.75, 3.1, -12.0]} receiveShadow>
        <boxGeometry args={[5.5, 6.2, 0.2]} />
        <meshStandardMaterial color="#04060a" roughness={0.65} metalness={0.5} />
      </mesh>

      {/* Ceiling Panels across all areas */}
      <mesh position={[4.0, 6.15, 1.0]} rotation={[Math.PI / 2, 0, 0]}>
        <planeGeometry args={[18, 32]} />
        <meshStandardMaterial color="#162332" roughness={0.45} metalness={0.6} />
      </mesh>
    </group>
  );
}

// -------------------------------------------------------------
// AWAKENING DAIS & START AREA (Z = 11.5 - In front of capsule, player spawn point)
// -------------------------------------------------------------
function AwakeningDais() {
  return (
    <group position={[0, 0, 13.5]} name="awakening-dais">
      {/* Raised Hexagonal Metal Dais */}
      <mesh position={[0, 0.15, 0]} receiveShadow>
        <cylinderGeometry args={[2.2, 2.5, 0.3, 8]} />
        <meshStandardMaterial color="#182838" metalness={0.88} roughness={0.25} />
      </mesh>
      {/* Cyan Uplight Recess Ring */}
      <mesh position={[0, 0.31, 0]} rotation={[-Math.PI / 2, 0, 0]}>
        <ringGeometry args={[1.6, 1.85, 32]} />
        <meshStandardMaterial
          color="#063b46"
          emissive="#00c6d8"
          emissiveIntensity={0.72}
          metalness={0.35}
          roughness={0.32}
        />
      </mesh>
      <pointLight position={[0, 0.5, 0]} color="#00d8e8" intensity={1.1} distance={3.2} />
    </group>
  );
}

export function OpeningRoom({
  flags,
  quality,
  focusedInteractionId = null,
  visualEvent = null,
  breachProgress = 0,
  isAgitated = false,
  hasWeapon = false,
  onPickupWeapon,
  playerPos,
  onMonsterHpChange,
  onMonsterAttack,
  onMonsterDefeated,
  lastHitNonce = 0,
  lastHitDamage = 0,
  combatStudyEnabled = false,
}: OpeningRoomProps) {
  const visualQuality = OPENING_ROOM_VISUAL_QUALITY[quality];

  return (
    <group name="opening-room">
      <DigitalClock inspected={flags.openingClockInspected} focused={focusedInteractionId === 'opening-clock'} visualEvent={visualEvent} />
      <TornPhoto inspected={flags.openingPhotoInspected} focused={focusedInteractionId === 'opening-photo'} visualEvent={visualEvent} />
      {(['clock', 'photo'] as const).map((key) => {
        const anchor = OPENING_ROOM_ANCHORS[key];
        const height = anchor.y - 0.35;
        return <mesh key={key} position={[anchor.x, height / 2, anchor.z - 0.08]} castShadow receiveShadow>
          <boxGeometry args={[key === 'clock' ? 0.65 : 1.05, height, 0.48]} />
          <meshStandardMaterial color="#14232d" metalness={0.65} roughness={0.55} />
        </mesh>;
      })}
      <group position={anchorTuple(OPENING_ROOM_ANCHORS.door)} name="opening-door-control">
        <mesh>
          <boxGeometry args={[0.55, 0.65, 0.12]} />
          <meshStandardMaterial color="#121d25" metalness={0.6} roughness={0.4} />
        </mesh>
        <mesh position={[0, 0, 0.07]} rotation={[0, 0, flags.openingDoorUnlocked ? Math.PI / 2 : 0]}>
          <boxGeometry args={[0.06, 0.32, 0.025]} />
          <meshBasicMaterial color={flags.openingDoorUnlocked ? '#55e7ff' : '#ff4058'} />
        </mesh>
        <InteractiveHighlight active={focusedInteractionId === 'opening-door'} radius={0.44} />
      </group>
      <RoomLighting
        quality={quality}
        doorUnlocked={flags.openingDoorUnlocked}
        focusedInteractionId={focusedInteractionId}
        visualEvent={visualEvent}
        breachProgress={breachProgress}
      />

      {/* 1. Complete Architecture: Main Corridor & 3 Nested Wings */}
      <MainCorridorAndWings focusedInteractionId={focusedInteractionId} />

      {/* 2. Awakening Dais and Echo's High-Quality Start Capsule */}
      <AwakeningDais />
      <WakeCapsuleModel
        position={[0, 0.3, 14.6]}
        rotation={[0, Math.PI, 0]}
        scale={1.25}
        isOpen={true}
      />

      {/* 3. Row of Ultra-Detailed Stasis Pods in Main Corridor */}
      <UltraStasisPod position={[-3.6, 0, 10.0]} label="EX-001" fluidColor="#00f0ff" />
      <UltraStasisPod position={[-3.6, 0, 5.0]} label="EX-002" fluidColor="#00f0ff" />
      <UltraStasisPod position={[-3.6, 0, 0.0]} label="EX-003" fluidColor="#ff8800" isCritical={true} />
      <UltraStasisPod position={[-3.6, 0, -5.0]} label="EX-004" fluidColor="#00f0ff" />

      {/* 4. Sub-Chamber Beta: Corrupted Ruptured Pods */}
      <UltraStasisPod position={[11.5, 0, 2.0]} label="EX-007" fluidColor="#ff2255" isCritical={true} />
      <UltraStasisPod position={[11.5, 0, -2.0]} label="EX-008" fluidColor="#ff0033" isCritical={true} />

      {/* 5. DEEP CONTAINMENT VAULT: SPECIMEN EX-000 POD & MONSTER */}
      {combatStudyEnabled && <group position={[11.0, 0, -8.5]}>
        <UltraStasisPod
          position={[0, 0, 0]}
          scale={1.35}
          label="SPECIMEN EX-000"
          fluidColor="#7700ee"
          fluidIntensity={3.5}
          isCritical={true}
          isShattered={breachProgress >= 0.55}
        />
        {/* The 3D Horror Monster Entity */}
        <StasisMonsterModel
          position={[0, 0, 0]}
          rotation={[0, 0, 0]}
          scale={2.4}
          breachProgress={breachProgress}
          isAgitated={isAgitated || breachProgress > 0}
          playerPos={playerPos}
          onMonsterHpChange={onMonsterHpChange}
          onMonsterAttack={onMonsterAttack}
          onMonsterDefeated={onMonsterDefeated}
          lastHitNonce={lastHitNonce}
          lastHitDamage={lastHitDamage}
        />
      </group>}

      {/* 6. End Monument: 5-Meter Quarantine Blast Vault at z = -14.5 */}
      <QuarantineBlastVault isBreached={breachProgress > 0.8} />

      {/* 7. Tactical Cyber-Katana Weapon Supply Crate */}
      {combatStudyEnabled && <CyberKatanaPickup
        hasWeapon={hasWeapon}
        focused={focusedInteractionId === 'opening-katana-chest' || focusedInteractionId === 'cyber-katana'}
        onPickup={onPickupWeapon}
      />}


      {/* 8. Room Atmosphere: Floating Dust, Nitrogen Fog, Flickering LED lights */}
      <RoomAtmosphere quality={quality} visualEvent={visualEvent} />

      {/* Cables */}
      {ROOM_CABLES.map((cable, idx) => (
        <Cable key={idx} points={cable.points} color={cable.color} radius={cable.radius} />
      ))}
    </group>
  );
}
