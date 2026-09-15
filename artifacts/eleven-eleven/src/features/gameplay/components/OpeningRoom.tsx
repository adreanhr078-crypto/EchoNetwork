import {
  Suspense,
  useMemo,
  useRef,
} from 'react';
import { useFrame } from '@react-three/fiber';
import {
  AdditiveBlending,
  CatmullRomCurve3,
  DoubleSide,
  MathUtils,
  Vector3,
  type Group,
  type MeshBasicMaterial,
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

export type OpeningRoomVisualEvent = RoomVisualEvent;

export interface OpeningRoomProps {
  flags: OpeningRoomNarrativeFlags;
  quality: QualityTier;
  focusedInteractionId?: string | null;
  visualEvent?: OpeningRoomVisualEvent | null;
}

const CLOCK_POSITION: [number, number, number] = [0.65, 1.62, -3.31];
const PHOTO_POSITION: [number, number, number] = [2.55, 1.08, -1.5];
const DOOR_POSITION: [number, number, number] = [-2.3, 1.48, -3.31];

const ROOM_CABLES = [
  {
    points: [
      [-4.35, 2.95, 2.75],
      [-4.28, 2.78, 1.65],
      [-4.3, 2.35, 0.5],
      [-4.27, 1.72, 0.15],
    ],
    color: '#163b43',
    radius: 0.018,
  },
  {
    points: [
      [-4.28, 2.91, 2.76],
      [-3.15, 3.24, 2.66],
      [-1.82, 3.27, 2.63],
      [-0.9, 3.16, 2.58],
    ],
    color: '#1b2c32',
    radius: 0.022,
  },
  {
    points: [
      [-1.04, 3.2, -3.36],
      [-0.3, 3.03, -3.35],
      [0.42, 2.25, -3.34],
      [0.65, 1.92, -3.32],
    ],
    color: '#194a52',
    radius: 0.014,
  },
  {
    points: [
      [-1.35, 3.26, -3.35],
      [-2.05, 3.0, -3.34],
      [-2.93, 2.82, -3.33],
      [-3.13, 2.2, -3.31],
    ],
    color: '#591720',
    radius: 0.014,
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
      <tubeGeometry args={[curve, 28, radius, 6, false]} />
      <meshStandardMaterial
        color={color}
        metalness={0.58}
        roughness={0.5}
      />
    </mesh>
  );
}

function DigitalOne({ x }: { x: number }) {
  return (
    <group position={[x, 0, 0.091]}>
      <mesh position={[0, 0.085, 0]}>
        <boxGeometry args={[0.055, 0.17, 0.015]} />
        <meshBasicMaterial
          color="#ff7582"
          toneMapped={false}
        />
      </mesh>
      <mesh position={[0, -0.095, 0]}>
        <boxGeometry args={[0.055, 0.17, 0.015]} />
        <meshBasicMaterial
          color="#ff5366"
          toneMapped={false}
        />
      </mesh>
    </group>
  );
}

function DigitalClock({
  inspected,
  focused,
  visualEvent,
}: {
  inspected: boolean;
  focused: boolean;
  visualEvent?: OpeningRoomVisualEvent | null;
}) {
  const clockRef = useRef<Group>(null);
  const pulseMaterialRef = useRef<MeshBasicMaterial>(null);
  const lastNonceRef = useRef(-1);
  const effectStartedAtRef = useRef(-100);

  useFrame(({ clock }) => {
    const clockGroup = clockRef.current;
    const pulseMaterial = pulseMaterialRef.current;
    if (!clockGroup || !pulseMaterial) return;

    const isClockEvent = visualEvent?.interactionId === 'opening-clock';
    if (
      isClockEvent
      && visualEvent
      && visualEvent.nonce !== lastNonceRef.current
    ) {
      lastNonceRef.current = visualEvent.nonce;
      effectStartedAtRef.current = clock.elapsedTime;
    }

    const elapsed = clock.elapsedTime - effectStartedAtRef.current;
    const active = elapsed >= 0 && elapsed < 0.9;
    const envelope = active
      ? Math.sin((elapsed / 0.9) * Math.PI)
      : 0;
    clockGroup.position.x = CLOCK_POSITION[0]
      + Math.sin(elapsed * 57) * envelope * 0.018;
    clockGroup.position.y = CLOCK_POSITION[1]
      + Math.sin(elapsed * 31) * envelope * 0.008;
    pulseMaterial.opacity = (
      inspected ? 0.09 : 0.04
    ) + envelope * 0.32;
  });

  return (
    <>
      <group
        ref={clockRef}
        position={CLOCK_POSITION}
        name="stopped-digital-clock"
      >
        <mesh castShadow>
          <boxGeometry args={[1.16, 0.52, 0.17]} />
          <meshStandardMaterial
            color="#05090c"
            emissive={inspected ? '#09323a' : '#25070c'}
            emissiveIntensity={inspected ? 0.34 : 0.2}
            metalness={0.78}
            roughness={0.3}
          />
        </mesh>
        <mesh position={[0, 0, 0.09]}>
          <planeGeometry args={[0.97, 0.36]} />
          <meshBasicMaterial color="#130407" />
        </mesh>
        <DigitalOne x={-0.36} />
        <DigitalOne x={-0.17} />
        <DigitalOne x={0.17} />
        <DigitalOne x={0.36} />
        <mesh position={[0, 0.085, 0.102]}>
          <circleGeometry args={[0.026, 12]} />
          <meshBasicMaterial color="#ff5a6c" toneMapped={false} />
        </mesh>
        <mesh position={[0, -0.085, 0.102]}>
          <circleGeometry args={[0.026, 12]} />
          <meshBasicMaterial color="#ff5a6c" toneMapped={false} />
        </mesh>
        <mesh position={[0, 0, 0.108]}>
          <planeGeometry args={[1.02, 0.4]} />
          <meshBasicMaterial
            ref={pulseMaterialRef}
            color={OPENING_ROOM_PALETTE.memory}
            transparent
            opacity={0.04}
            depthWrite={false}
            blending={AdditiveBlending}
            toneMapped={false}
          />
        </mesh>
        <mesh position={[0, -0.34, -0.01]} castShadow>
          <boxGeometry args={[1.28, 0.12, 0.28]} />
          <meshStandardMaterial
            color="#11191d"
            metalness={0.64}
            roughness={0.43}
          />
        </mesh>
        <InteractiveHighlight
          active={focused}
          radius={0.52}
          position={[0, 0, 0.14]}
        />
      </group>
      <MemoryGlitchEffect
        event={visualEvent}
        interactionId="opening-clock"
        position={[0.65, 1.62, -3.1]}
        radius={0.66}
        particleCount={22}
      />
    </>
  );
}

function TornPhoto({
  inspected,
  focused,
  visualEvent,
}: {
  inspected: boolean;
  focused: boolean;
  visualEvent?: OpeningRoomVisualEvent | null;
}) {
  const photoRef = useRef<Group>(null);
  const lastNonceRef = useRef(-1);
  const effectStartedAtRef = useRef(-100);

  useFrame(({ clock }) => {
    const photo = photoRef.current;
    if (!photo) return;

    const isPhotoEvent = visualEvent?.interactionId === 'opening-photo';
    if (
      isPhotoEvent
      && visualEvent
      && visualEvent.nonce !== lastNonceRef.current
    ) {
      lastNonceRef.current = visualEvent.nonce;
      effectStartedAtRef.current = clock.elapsedTime;
    }

    const elapsed = clock.elapsedTime - effectStartedAtRef.current;
    const active = elapsed >= 0 && elapsed < 1.05;
    const envelope = active
      ? Math.sin((elapsed / 1.05) * Math.PI)
      : 0;
    photo.position.y = PHOTO_POSITION[1] + envelope * 0.075;
    photo.rotation.x = -0.38 + envelope * 0.12;
    photo.rotation.z = 0.02 + Math.sin(elapsed * 46) * envelope * 0.025;
  });

  return (
    <>
      <group
        ref={photoRef}
        position={PHOTO_POSITION}
        rotation={[-0.38, 0.05, 0.02]}
        name="torn-photograph"
      >
        <mesh position={[-0.19, 0.01, 0]} castShadow>
          <boxGeometry args={[0.46, 0.57, 0.035]} />
          <meshStandardMaterial
            color="#a9aaa2"
            emissive={inspected ? '#15383d' : '#080d0e'}
            emissiveIntensity={inspected ? 0.32 : 0.08}
            roughness={0.92}
          />
        </mesh>
        <mesh
          position={[0.245, -0.025, 0.004]}
          rotation={[0, 0, -0.055]}
          castShadow
        >
          <boxGeometry args={[0.34, 0.49, 0.032]} />
          <meshStandardMaterial
            color="#93958e"
            emissive={inspected ? '#12343a' : '#070b0c'}
            emissiveIntensity={inspected ? 0.28 : 0.06}
            roughness={0.95}
          />
        </mesh>
        <mesh position={[-0.16, 0.1, 0.026]}>
          <circleGeometry args={[0.115, 18]} />
          <meshBasicMaterial color="#27343a" />
        </mesh>
        <mesh position={[-0.16, -0.12, 0.026]}>
          <planeGeometry args={[0.32, 0.23]} />
          <meshBasicMaterial color="#202d32" />
        </mesh>
        <mesh
          position={[0.15, 0.015, 0.028]}
          rotation={[0, 0, 0.72]}
        >
          <planeGeometry args={[0.035, 0.64]} />
          <meshBasicMaterial color="#081014" />
        </mesh>
        {[-0.2, -0.05, 0.1].map((x, index) => (
          <mesh
            key={x}
            position={[x + 0.31, -0.245 + index * 0.014, 0.029]}
            rotation={[0, 0, -0.08 + index * 0.12]}
          >
            <planeGeometry args={[0.16, 0.017]} />
            <meshBasicMaterial
              color={
                inspected
                  ? OPENING_ROOM_PALETTE.memory
                  : '#32444a'
              }
              transparent
              opacity={inspected ? 0.58 : 0.36}
            />
          </mesh>
        ))}
        <InteractiveHighlight
          active={focused}
          radius={0.48}
          position={[0, 0, 0.08]}
        />
      </group>
      <MemoryGlitchEffect
        event={visualEvent}
        interactionId="opening-photo"
        position={[2.55, 1.18, -1.34]}
        radius={0.62}
        particleCount={26}
      />
    </>
  );
}

function LockGlyph({ unlocked }: { unlocked: boolean }) {
  return (
    <group position={[0, 0.18, 0.106]}>
      <mesh position={[0, -0.11, 0]}>
        <boxGeometry args={[0.32, 0.27, 0.025]} />
        <meshBasicMaterial
          color={
            unlocked
              ? OPENING_ROOM_PALETTE.memory
              : OPENING_ROOM_PALETTE.danger
          }
          transparent
          opacity={0.76}
          toneMapped={false}
        />
      </mesh>
      <mesh position={[0, 0.055, 0]}>
        <torusGeometry args={[0.115, 0.035, 8, 24, Math.PI]} />
        <meshBasicMaterial
          color={
            unlocked
              ? OPENING_ROOM_PALETTE.memory
              : OPENING_ROOM_PALETTE.danger
          }
          transparent
          opacity={0.8}
          toneMapped={false}
        />
      </mesh>
      <mesh position={[0, -0.1, 0.018]}>
        <circleGeometry args={[0.035, 12]} />
        <meshBasicMaterial color="#071014" />
      </mesh>
    </group>
  );
}

function ExitDoor({
  unlocked,
  focused,
  visualEvent,
}: {
  unlocked: boolean;
  focused: boolean;
  visualEvent?: OpeningRoomVisualEvent | null;
}) {
  const hingeRef = useRef<Group>(null);
  const responseRef = useRef<Group>(null);
  const progressRef = useRef(unlocked ? 1 : 0);
  const lastNonceRef = useRef(-1);
  const effectStartedAtRef = useRef(-100);

  useFrame(({ clock }, delta) => {
    const hinge = hingeRef.current;
    const response = responseRef.current;
    if (!hinge || !response) return;

    progressRef.current = MathUtils.clamp(
      progressRef.current + (unlocked ? 1 : -1) * delta / 1.45,
      0,
      1,
    );
    const progress = progressRef.current;
    const eased = 1 - (1 - progress) ** 3;
    hinge.rotation.y = -1.42 * eased;

    const isDoorEvent = visualEvent?.interactionId === 'opening-door';
    if (
      isDoorEvent
      && visualEvent
      && visualEvent.nonce !== lastNonceRef.current
    ) {
      lastNonceRef.current = visualEvent.nonce;
      effectStartedAtRef.current = clock.elapsedTime;
    }

    const elapsed = clock.elapsedTime - effectStartedAtRef.current;
    const lockedResponse = visualEvent?.outcome === 'locked'
      && elapsed >= 0
      && elapsed < 0.62;
    const envelope = lockedResponse
      ? Math.sin((elapsed / 0.62) * Math.PI)
      : 0;
    response.position.x = Math.sin(elapsed * 57) * envelope * 0.035;
    response.rotation.z = Math.sin(elapsed * 42) * envelope * 0.008;
  });

  return (
    <>
      <group name="exit-door">
        <mesh position={[-2.3, 1.48, -3.47]}>
          <planeGeometry args={[1.76, 2.96]} />
          <meshBasicMaterial color="#000205" side={DoubleSide} />
        </mesh>
        <mesh position={[-3.22, 1.48, -3.25]} castShadow>
          <boxGeometry args={[0.16, 3.18, 0.32]} />
          <meshStandardMaterial
            color="#18262c"
            metalness={0.82}
            roughness={0.32}
          />
        </mesh>
        <mesh position={[-1.38, 1.48, -3.25]} castShadow>
          <boxGeometry args={[0.16, 3.18, 0.32]} />
          <meshStandardMaterial
            color="#18262c"
            metalness={0.82}
            roughness={0.32}
          />
        </mesh>
        <mesh position={[-2.3, 3.02, -3.25]} castShadow>
          <boxGeometry args={[2, 0.16, 0.32]} />
          <meshStandardMaterial
            color="#18262c"
            metalness={0.82}
            roughness={0.32}
          />
        </mesh>
        <group ref={responseRef}>
          <group
            ref={hingeRef}
            position={[-3.15, 0, -3.31]}
            rotation={[0, -1.42 * progressRef.current, 0]}
          >
            <mesh
              position={[0.85, 1.48, 0]}
              castShadow
              receiveShadow
            >
              <boxGeometry args={[1.7, 2.96, 0.16]} />
              <meshStandardMaterial
                color={unlocked ? '#10282d' : '#10171b'}
                emissive={unlocked ? '#0a5964' : '#310a12'}
                emissiveIntensity={unlocked ? 0.44 : 0.18}
                metalness={0.84}
                roughness={0.36}
              />
            </mesh>
            {[0.48, 0.92, 1.36, 1.8, 2.24].map((y) => (
              <mesh
                key={y}
                position={[0.85, y, 0.092]}
              >
                <boxGeometry args={[1.42, 0.025, 0.018]} />
                <meshBasicMaterial
                  color={unlocked ? '#1c5962' : '#48131a'}
                  transparent
                  opacity={0.5}
                />
              </mesh>
            ))}
            <LockGlyph unlocked={unlocked} />
            <mesh position={[1.45, 1.45, 0.12]}>
              <sphereGeometry args={[0.07, 12, 12]} />
              <meshStandardMaterial
                color={unlocked ? '#8cf5ff' : '#8a1f2e'}
                emissive={unlocked ? '#36d7e8' : '#66101d'}
                emissiveIntensity={1.2}
              />
            </mesh>
          </group>
        </group>
        <InteractiveHighlight
          active={focused}
          color={
            unlocked
              ? OPENING_ROOM_PALETTE.memory
              : OPENING_ROOM_PALETTE.danger
          }
          radius={0.68}
          position={[-2.3, 1.45, -3.14]}
        />
      </group>
      <MemoryGlitchEffect
        event={visualEvent}
        interactionId="opening-door"
        position={[-2.3, 1.45, -3.08]}
        radius={0.82}
        particleCount={24}
      />
    </>
  );
}

function BedFallback() {
  return (
    <mesh position={[-2.68, 0.45, 1.33]} castShadow>
      <boxGeometry args={[1.8, 0.6, 2.2]} />
      <meshStandardMaterial
        color="#15252c"
        emissive="#07313a"
        emissiveIntensity={0.15}
        roughness={0.9}
      />
    </mesh>
  );
}

function Bed() {
  return (
    <group name="opening-room-bed">
      {/* Sci-Fi Awakening Dais with Obsidian Finish & Cyan Emissive Conduit Rings */}
      <mesh position={[-2.68, 0.08, 1.33]} castShadow receiveShadow>
        <cylinderGeometry args={[1.45, 1.55, 0.16, 24]} />
        <meshStandardMaterial
          color="#0b1114"
          metalness={0.65}
          roughness={0.42}
        />
      </mesh>
      {/* Outer Cyan Emissive Energy Ring */}
      <mesh position={[-2.68, 0.165, 1.33]} rotation={[-Math.PI / 2, 0, 0]}>
        <ringGeometry args={[1.32, 1.42, 32]} />
        <meshBasicMaterial color="#00e5ff" toneMapped={false} />
      </mesh>
      {/* Radial floor energy conduits */}
      {[0, 1, 2, 3].map((i) => {
        const angle = (i * Math.PI) / 2 + 0.35;
        const x = -2.68 + Math.cos(angle) * 1.6;
        const z = 1.33 + Math.sin(angle) * 1.6;
        return (
          <mesh key={i} position={[x, 0.02, z]} rotation={[0, -angle, 0]}>
            <boxGeometry args={[0.42, 0.025, 0.06]} />
            <meshStandardMaterial
              color="#0d1e24"
              emissive="#00b4d8"
              emissiveIntensity={0.8}
              roughness={0.5}
            />
          </mesh>
        );
      })}
      {/* Production Sector 11 Wake Capsule (Hard-Surface, Rigged Hydraulic Canopy) */}
      <Suspense fallback={<BedFallback />}>
        <WakeCapsuleModel
          position={[-2.68, 0.16, 1.33]}
          rotation={[0, 0.35, 0]}
          scale={2.35}
          isOpen={true}
        />
      </Suspense>
    </group>
  );
}

function Desk({ detailed }: { detailed: boolean }) {
  return (
    <group name="opening-room-desk">
      <mesh position={[2.65, 0.92, -2.1]} castShadow receiveShadow>
        <boxGeometry args={[2, 0.15, 1.1]} />
        <meshStandardMaterial
          color="#1a252a"
          metalness={0.46}
          roughness={0.58}
        />
      </mesh>
      <mesh position={[3.33, 0.45, -2.1]} castShadow>
        <boxGeometry args={[0.57, 0.82, 0.92]} />
        <meshStandardMaterial
          color="#121b20"
          metalness={0.52}
          roughness={0.5}
        />
      </mesh>
      {[0.25, 0.5, 0.75].map((y) => (
        <group key={y}>
          <mesh position={[3.32, y, -1.625]}>
            <boxGeometry args={[0.48, 0.18, 0.035]} />
            <meshStandardMaterial color="#1c2a30" metalness={0.48} />
          </mesh>
          <mesh position={[3.32, y, -1.6]}>
            <boxGeometry args={[0.16, 0.018, 0.012]} />
            <meshBasicMaterial color="#3a6670" />
          </mesh>
        </group>
      ))}
      {[
        [1.78, 0.43, -2.5],
        [1.78, 0.43, -1.7],
      ].map(([x, y, z], index) => (
        <mesh key={index} position={[x, y, z]} castShadow>
          <boxGeometry args={[0.12, 0.86, 0.12]} />
          <meshStandardMaterial color="#0f171b" metalness={0.62} />
        </mesh>
      ))}
      <group position={[3.05, 1.26, -2.45]} rotation={[0, -0.12, 0]}>
        <mesh castShadow>
          <boxGeometry args={[0.92, 0.58, 0.075]} />
          <meshStandardMaterial
            color="#080e12"
            metalness={0.68}
            roughness={0.34}
          />
        </mesh>
        <mesh position={[0, 0, 0.043]}>
          <planeGeometry args={[0.79, 0.45]} />
          <meshBasicMaterial
            color="#061a20"
            transparent
            opacity={0.96}
          />
        </mesh>
        {[-0.25, -0.12, 0.02, 0.17].map((y, index) => (
          <mesh
            key={y}
            position={[
              -0.2 + (index % 2) * 0.15,
              y,
              0.049,
            ]}
          >
            <planeGeometry args={[0.24 + index * 0.05, 0.012]} />
            <meshBasicMaterial
              color={index === 2 ? '#b72538' : '#2ab7c9'}
              transparent
              opacity={0.45}
            />
          </mesh>
        ))}
        <mesh position={[0, -0.42, -0.02]}>
          <boxGeometry args={[0.08, 0.28, 0.08]} />
          <meshStandardMaterial color="#17242a" metalness={0.72} />
        </mesh>
        <mesh position={[0, -0.56, -0.02]}>
          <boxGeometry args={[0.46, 0.045, 0.25]} />
          <meshStandardMaterial color="#17242a" metalness={0.72} />
        </mesh>
      </group>
      <mesh position={[2.15, 1.02, -1.93]} rotation={[0, -0.12, 0]}>
        <boxGeometry args={[0.62, 0.035, 0.25]} />
        <meshStandardMaterial color="#10191e" roughness={0.66} />
      </mesh>
      <mesh
        position={[1.92, 1.16, -2.38]}
        rotation={[0, 0.15, -0.32]}
      >
        <cylinderGeometry args={[0.025, 0.025, 0.62, 8]} />
        <meshStandardMaterial color="#273940" metalness={0.72} />
      </mesh>
      <mesh position={[1.83, 1.48, -2.36]} rotation={[0, 0, -0.22]}>
        <coneGeometry args={[0.22, 0.3, 16, 1, true]} />
        <meshStandardMaterial
          color="#1b2a30"
          emissive="#164f59"
          emissiveIntensity={0.35}
          metalness={0.58}
          side={DoubleSide}
        />
      </mesh>
      {detailed && (
        <>
          {[
            [2.26, 1.015, -2.52, -0.16],
            [2.58, 1.018, -2.36, 0.08],
            [2.39, 1.021, -1.82, 0.19],
          ].map(([x, y, z, rotation], index) => (
            <mesh
              key={index}
              position={[x, y, z]}
              rotation={[-Math.PI / 2, 0, rotation]}
            >
              <planeGeometry args={[0.39, 0.25]} />
              <meshStandardMaterial
                color={index === 1 ? '#7a7770' : '#a49f92'}
                roughness={1}
              />
            </mesh>
          ))}
          <mesh position={[3.56, 1.08, -1.84]}>
            <cylinderGeometry args={[0.085, 0.065, 0.23, 14]} />
            <meshStandardMaterial color="#1f3239" roughness={0.68} />
          </mesh>
        </>
      )}
    </group>
  );
}

function MachineCore({ detailed }: { detailed: boolean }) {
  return (
    <group
      position={[-4.18, 1.35, 0.42]}
      name="memory-system-conduit"
    >
      <mesh castShadow>
        <cylinderGeometry args={[0.28, 0.31, 1.52, 16]} />
        <meshStandardMaterial
          color="#102027"
          metalness={0.82}
          roughness={0.31}
        />
      </mesh>
      <mesh>
        <cylinderGeometry args={[0.17, 0.17, 1.18, 16]} />
        <meshStandardMaterial
          color="#153a43"
          emissive="#18aabe"
          emissiveIntensity={0.75}
          transparent
          opacity={0.72}
          metalness={0.16}
          roughness={0.22}
        />
      </mesh>
      {[-0.62, 0.62].map((y) => (
        <mesh key={y} position={[0, y, 0]}>
          <torusGeometry args={[0.33, 0.045, 8, 20]} />
          <meshStandardMaterial color="#293d44" metalness={0.88} />
        </mesh>
      ))}
      {detailed && [-0.36, -0.12, 0.12, 0.36].map((y, index) => (
        <mesh key={y} position={[0.282, y, 0]}>
          <boxGeometry args={[0.045, 0.09, 0.1]} />
          <meshBasicMaterial
            color={index === 2 ? '#ff4058' : '#5cecff'}
            transparent
            opacity={0.72}
          />
        </mesh>
      ))}
    </group>
  );
}

function Floor({
  detailCount,
  detailed,
}: {
  detailCount: number;
  detailed: boolean;
}) {
  const { width, depth } = OPENING_ROOM_CONFIG.dimensions;

  return (
    <group name="opening-room-floor">
      <mesh position={[0, -0.08, 0]} receiveShadow>
        <boxGeometry args={[width, 0.16, depth]} />
        <meshStandardMaterial
          color={OPENING_ROOM_PALETTE.floor}
          metalness={0.22}
          roughness={0.82}
        />
      </mesh>
      {Array.from({ length: detailCount }, (_, index) => {
        const z = -3.12 + index * (6.24 / Math.max(1, detailCount - 1));
        return (
          <mesh
            key={index}
            position={[0, 0.006, z]}
            rotation={[-Math.PI / 2, 0, 0]}
          >
            <planeGeometry args={[8.65, 0.018]} />
            <meshBasicMaterial
              color={index % 3 ? '#15262c' : '#25404a'}
              transparent
              opacity={index % 3 ? 0.42 : 0.26}
            />
          </mesh>
        );
      })}
      {[-3.15, -1.5, 0.1, 1.7, 3.28].map((x) => (
        <mesh
          key={x}
          position={[x, 0.008, 0]}
          rotation={[-Math.PI / 2, 0, 0]}
        >
          <planeGeometry args={[0.018, 6.35]} />
          <meshBasicMaterial
            color="#0a171c"
            transparent
            opacity={0.68}
          />
        </mesh>
      ))}
      <mesh position={[-0.25, 0.018, 1.02]} receiveShadow>
        <boxGeometry args={[3.65, 0.025, 2.04]} />
        <meshStandardMaterial
          color="#111c22"
          emissive="#082029"
          emissiveIntensity={0.08}
          roughness={1}
        />
      </mesh>
      <mesh
        position={[-0.25, 0.034, 1.02]}
        rotation={[-Math.PI / 2, 0, 0]}
      >
        <planeGeometry args={[3.42, 1.82]} />
        <meshBasicMaterial
          color="#1a3440"
          transparent
          opacity={0.22}
        />
      </mesh>
      {detailed && (
        <>
          {[
            [0.75, 0.045, 0.42, -0.25],
            [1.14, 0.047, 0.68, 0.14],
            [0.94, 0.049, 1.02, 0.04],
          ].map(([x, y, z, rotation], index) => (
            <mesh
              key={index}
              position={[x, y, z]}
              rotation={[-Math.PI / 2, 0, rotation]}
            >
              <planeGeometry args={[0.48, 0.31]} />
              <meshStandardMaterial
                color={index === 1 ? '#777269' : '#908a7d'}
                roughness={1}
              />
            </mesh>
          ))}
          {[
            [-0.9, 0.041, -1.35, 0.16],
            [-0.45, 0.041, -1.23, -0.24],
            [0.1, 0.041, -1.52, 0.08],
          ].map(([x, y, z, rotation], index) => (
            <mesh
              key={index}
              position={[x, y, z]}
              rotation={[-Math.PI / 2, 0, rotation]}
            >
              <planeGeometry args={[0.66, 0.02]} />
              <meshBasicMaterial
                color={index === 1 ? '#7b1b29' : '#224f58'}
                transparent
                opacity={0.46}
              />
            </mesh>
          ))}
        </>
      )}
    </group>
  );
}

function WallNote({
  position,
  size,
  rotation = 0,
  accent = false,
}: {
  position: [number, number, number];
  size: [number, number];
  rotation?: number;
  accent?: boolean;
}) {
  return (
    <group position={position} rotation={[0, 0, rotation]}>
      <mesh>
        <planeGeometry args={size} />
        <meshStandardMaterial
          color={accent ? '#6d6860' : '#4d5351'}
          roughness={0.98}
          side={DoubleSide}
        />
      </mesh>
      {[0.22, 0, -0.22].map((y, index) => (
        <mesh
          key={y}
          position={[0, y * size[1], 0.006]}
        >
          <planeGeometry
            args={[size[0] * (0.56 + index * 0.1), 0.012]}
          />
          <meshBasicMaterial
            color={accent && index === 1 ? '#8c2632' : '#252f31'}
            transparent
            opacity={0.6}
          />
        </mesh>
      ))}
    </group>
  );
}

function Walls({ detailed }: { detailed: boolean }) {
  const { width, height, depth } = OPENING_ROOM_CONFIG.dimensions;
  const doorLeftEdge = -3.15;
  const doorRightEdge = -1.45;
  const leftBackWidth = doorLeftEdge + width / 2;
  const rightBackWidth = width / 2 - doorRightEdge;

  return (
    <group name="opening-room-architecture">
      <mesh position={[-width / 2, height / 2, 0]} receiveShadow>
        <boxGeometry args={[0.18, height, depth]} />
        <meshStandardMaterial
          color={OPENING_ROOM_PALETTE.wall}
          roughness={0.78}
        />
      </mesh>
      <mesh position={[width / 2, height / 2, 0]} receiveShadow>
        <boxGeometry args={[0.18, height, depth]} />
        <meshStandardMaterial
          color={OPENING_ROOM_PALETTE.wall}
          roughness={0.78}
        />
      </mesh>
      <mesh position={[0, height / 2, depth / 2]} receiveShadow>
        <boxGeometry args={[width, height, 0.18]} />
        <meshStandardMaterial color="#050b0f" roughness={0.86} />
      </mesh>
      <mesh
        position={[
          -width / 2 + leftBackWidth / 2,
          height / 2,
          -depth / 2,
        ]}
        receiveShadow
      >
        <boxGeometry args={[leftBackWidth, height, 0.18]} />
        <meshStandardMaterial
          color={OPENING_ROOM_PALETTE.wall}
          roughness={0.78}
        />
      </mesh>
      <mesh
        position={[
          doorRightEdge + rightBackWidth / 2,
          height / 2,
          -depth / 2,
        ]}
        receiveShadow
      >
        <boxGeometry args={[rightBackWidth, height, 0.18]} />
        <meshStandardMaterial
          color={OPENING_ROOM_PALETTE.wall}
          roughness={0.78}
        />
      </mesh>
      <mesh position={[-2.3, 3.3, -depth / 2]} receiveShadow>
        <boxGeometry args={[1.7, 0.6, 0.18]} />
        <meshStandardMaterial
          color={OPENING_ROOM_PALETTE.wall}
          roughness={0.78}
        />
      </mesh>
      <mesh position={[0, height, 0]} receiveShadow>
        <boxGeometry args={[width, 0.12, depth]} />
        <meshStandardMaterial
          color="#061014"
          transparent
          opacity={0.92}
          roughness={0.72}
        />
      </mesh>

      {[-2.7, 0, 2.7].map((z) => (
        <mesh key={z} position={[-4.39, 1.8, z]}>
          <boxGeometry args={[0.025, 3.25, 0.035]} />
          <meshStandardMaterial color="#16272d" metalness={0.42} />
        </mesh>
      ))}
      {[-2.9, -0.95, 1, 2.95].map((z) => (
        <mesh key={z} position={[4.39, 1.8, z]}>
          <boxGeometry args={[0.025, 3.25, 0.035]} />
          <meshStandardMaterial color="#16272d" metalness={0.42} />
        </mesh>
      ))}
      {[0.62, 1.82, 3.05].map((y) => (
        <mesh key={y} position={[0.82, y, -3.395]}>
          <boxGeometry args={[3.86, 0.035, 0.035]} />
          <meshStandardMaterial color="#16272d" metalness={0.42} />
        </mesh>
      ))}

      <mesh position={[2.62, 2.02, -3.39]}>
        <boxGeometry args={[2.18, 1.08, 0.045]} />
        <meshStandardMaterial
          color="#101b20"
          metalness={0.22}
          roughness={0.76}
        />
      </mesh>
      <mesh position={[2.62, 2.02, -3.36]}>
        <planeGeometry args={[2.02, 0.92]} />
        <meshStandardMaterial color="#263638" roughness={0.94} />
      </mesh>
      {detailed && (
        <>
          <WallNote
            position={[2.18, 2.18, -3.325]}
            size={[0.46, 0.58]}
            rotation={-0.08}
          />
          <WallNote
            position={[2.75, 2.04, -3.32]}
            size={[0.54, 0.42]}
            rotation={0.11}
            accent
          />
          <WallNote
            position={[3.28, 2.27, -3.325]}
            size={[0.36, 0.5]}
            rotation={-0.04}
          />
          <WallNote
            position={[2.42, 1.72, -3.325]}
            size={[0.38, 0.3]}
            rotation={0.05}
          />
          <WallNote
            position={[3.03, 1.7, -3.325]}
            size={[0.42, 0.28]}
            rotation={-0.12}
          />
        </>
      )}

      <group position={[-0.95, 2.62, -3.39]}>
        <mesh>
          <boxGeometry args={[1.36, 0.12, 0.11]} />
          <meshStandardMaterial
            color="#1a2d34"
            metalness={0.78}
            roughness={0.3}
          />
        </mesh>
        <mesh position={[0, 0, 0.075]}>
          <planeGeometry args={[1.12, 0.035]} />
          <meshBasicMaterial
            color="#79edff"
            transparent
            opacity={0.74}
            toneMapped={false}
          />
        </mesh>
      </group>
      <group position={[-2.3, 3.05, -3.32]}>
        <mesh>
          <boxGeometry args={[1.24, 0.09, 0.09]} />
          <meshStandardMaterial color="#281319" metalness={0.7} />
        </mesh>
        <mesh position={[0, 0, 0.06]}>
          <planeGeometry args={[1.02, 0.024]} />
          <meshBasicMaterial
            color="#ff4058"
            transparent
            opacity={0.56}
            toneMapped={false}
          />
        </mesh>
      </group>

      {detailed && (
        <group name="wall-damage">
          {[
            [-0.42, 2.18, -3.315, 0.53, 0.36],
            [-0.17, 2.02, -3.312, -0.42, 0.27],
            [3.82, 0.82, -3.31, 0.68, 0.44],
            [4.38, 1.2, 1.72, Math.PI / 2, 0.32],
          ].map(([x, y, z, rotation, length], index) => (
            <mesh
              key={index}
              position={[x, y, z]}
              rotation={[0, 0, rotation]}
            >
              <planeGeometry args={[length, 0.018]} />
              <meshBasicMaterial
                color={index === 2 ? '#4d151d' : '#1b343b'}
                transparent
                opacity={0.72}
                side={DoubleSide}
              />
            </mesh>
          ))}
        </group>
      )}
      <mesh position={[0, 0.18, 3.39]}>
        <boxGeometry args={[8.82, 0.32, 0.1]} />
        <meshStandardMaterial color="#101a1f" metalness={0.35} />
      </mesh>
      <mesh position={[4.39, 0.18, 0]}>
        <boxGeometry args={[0.1, 0.32, 6.82]} />
        <meshStandardMaterial color="#101a1f" metalness={0.35} />
      </mesh>
      <mesh position={[-4.39, 0.18, 0]}>
        <boxGeometry args={[0.1, 0.32, 6.82]} />
        <meshStandardMaterial color="#101a1f" metalness={0.35} />
      </mesh>
    </group>
  );
}

function SideShelf({ detailed }: { detailed: boolean }) {
  return (
    <group position={[4.28, 1.42, 1.7]} rotation={[0, -Math.PI / 2, 0]}>
      {[0, 0.62, 1.24].map((y) => (
        <mesh key={y} position={[0, y, 0]}>
          <boxGeometry args={[1.24, 0.08, 0.34]} />
          <meshStandardMaterial
            color="#17242a"
            metalness={0.52}
            roughness={0.5}
          />
        </mesh>
      ))}
      {[-0.56, 0.56].map((x) => (
        <mesh key={x} position={[x, 0.62, 0]}>
          <boxGeometry args={[0.07, 1.3, 0.28]} />
          <meshStandardMaterial color="#10191e" metalness={0.65} />
        </mesh>
      ))}
      {detailed && (
        <>
          {[-0.38, -0.24, -0.1, 0.07].map((x, index) => (
            <mesh
              key={x}
              position={[x, 0.18 + (index % 2) * 0.01, 0]}
              rotation={[0, 0, (index - 1.5) * 0.035]}
            >
              <boxGeometry args={[0.11, 0.29 + index * 0.03, 0.22]} />
              <meshStandardMaterial
                color={index === 2 ? '#1e5863' : '#303b3e'}
                roughness={0.86}
              />
            </mesh>
          ))}
          <mesh position={[0.29, 0.78, 0]}>
            <boxGeometry args={[0.46, 0.24, 0.25]} />
            <meshStandardMaterial color="#242f32" roughness={0.76} />
          </mesh>
        </>
      )}
    </group>
  );
}

export function OpeningRoom({
  flags,
  quality,
  focusedInteractionId = null,
  visualEvent = null,
}: OpeningRoomProps) {
  const visualQuality = OPENING_ROOM_VISUAL_QUALITY[quality];

  return (
    <group name="opening-room">
      <RoomLighting
        quality={quality}
        doorUnlocked={flags.openingDoorUnlocked}
        focusedInteractionId={focusedInteractionId}
        visualEvent={visualEvent}
      />
      <Floor
        detailCount={visualQuality.floorDetails}
        detailed={visualQuality.propDetails}
      />
      <Walls detailed={visualQuality.propDetails} />
      <Bed />
      <Desk detailed={visualQuality.propDetails} />
      <MachineCore detailed={visualQuality.propDetails} />
      <SideShelf detailed={visualQuality.propDetails} />

      {ROOM_CABLES
        .slice(0, quality === 'mobile' ? 2 : ROOM_CABLES.length)
        .map((cable, index) => (
          <Cable
            key={index}
            points={cable.points}
            color={cable.color}
            radius={cable.radius}
          />
        ))}

      <DigitalClock
        inspected={flags.openingClockInspected}
        focused={focusedInteractionId === 'opening-clock'}
        visualEvent={visualEvent}
      />
      <TornPhoto
        inspected={flags.openingPhotoInspected}
        focused={focusedInteractionId === 'opening-photo'}
        visualEvent={visualEvent}
      />
      <ExitDoor
        unlocked={flags.openingDoorUnlocked}
        focused={focusedInteractionId === 'opening-door'}
        visualEvent={visualEvent}
      />
      <RoomAtmosphere quality={quality} visualEvent={visualEvent} />

      <mesh position={[0.15, 3.28, 0.35]}>
        <boxGeometry args={[1.5, 0.08, 0.24]} />
        <meshStandardMaterial
          color="#192a30"
          emissive="#1c6874"
          emissiveIntensity={0.28}
          metalness={0.66}
          roughness={0.38}
        />
      </mesh>
      <mesh position={DOOR_POSITION} visible={false}>
        <boxGeometry args={[0.01, 0.01, 0.01]} />
        <meshBasicMaterial />
      </mesh>
    </group>
  );
}
