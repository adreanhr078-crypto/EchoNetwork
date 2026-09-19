// Existing clock/photo presentation restored from the accepted source, not new Canon.
import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import { AdditiveBlending, type Group, type MeshBasicMaterial } from 'three';
import { OPENING_ROOM_PALETTE, type RoomVisualEvent } from '../data/openingRoom.visuals';
import { OPENING_ROOM_ANCHORS, anchorTuple } from '../data/openingRoom.anchors';
import { InteractiveHighlight } from './InteractiveHighlight';
import { MemoryGlitchEffect } from './MemoryGlitchEffect';
const CLOCK_POSITION = anchorTuple(OPENING_ROOM_ANCHORS.clock);
const PHOTO_POSITION = anchorTuple(OPENING_ROOM_ANCHORS.photo);

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

export function DigitalClock({
  inspected,
  focused,
  visualEvent,
}: {
  inspected: boolean;
  focused: boolean;
  visualEvent?: RoomVisualEvent | null;
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
        position={[CLOCK_POSITION[0], CLOCK_POSITION[1], CLOCK_POSITION[2] + 0.2]}
        radius={0.66}
        particleCount={22}
      />
    </>
  );
}

export function TornPhoto({
  inspected,
  focused,
  visualEvent,
}: {
  inspected: boolean;
  focused: boolean;
  visualEvent?: RoomVisualEvent | null;
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
        position={[PHOTO_POSITION[0], PHOTO_POSITION[1] + 0.1, PHOTO_POSITION[2] + 0.2]}
        radius={0.62}
        particleCount={26}
      />
    </>
  );
}
