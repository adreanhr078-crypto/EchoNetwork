import { useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import {
  Color,
  MathUtils,
  type PointLight,
  type SpotLight,
} from 'three';
import type { QualityTier } from '../../../ui/design-system';
import {
  OPENING_ROOM_PALETTE,
  OPENING_ROOM_VISUAL_QUALITY,
  type RoomVisualEvent,
} from '../data/openingRoom.visuals';

interface RoomLightingProps {
  quality: QualityTier;
  doorUnlocked: boolean;
  focusedInteractionId?: string | null;
  visualEvent?: RoomVisualEvent | null;
  breachProgress?: number;
}

export function RoomLighting({
  quality,
  doorUnlocked,
  focusedInteractionId,
  visualEvent,
  breachProgress = 0,
}: RoomLightingProps) {
  const overheadRef = useRef<PointLight>(null);
  const memoryRef = useRef<PointLight>(null);
  const doorRef = useRef<PointLight>(null);
  const deskSpotRef = useRef<SpotLight>(null);
  const vaultStrobeRef = useRef<PointLight>(null);
  const lastNonceRef = useRef(-1);
  const eventStartedAtRef = useRef(-100);
  const doorTargetColor = useMemo(
    () => new Color(
      doorUnlocked
        ? OPENING_ROOM_PALETTE.memory
        : OPENING_ROOM_PALETTE.danger,
    ),
    [doorUnlocked],
  );
  const qualityConfig = OPENING_ROOM_VISUAL_QUALITY[quality];

  useFrame(({ clock }, delta) => {
    const overhead = overheadRef.current;
    const memory = memoryRef.current;
    const door = doorRef.current;
    const deskSpot = deskSpotRef.current;
    const vaultStrobe = vaultStrobeRef.current;

    if (
      visualEvent
      && visualEvent.nonce !== lastNonceRef.current
    ) {
      lastNonceRef.current = visualEvent.nonce;
      eventStartedAtRef.current = clock.elapsedTime;
    }

    const time = clock.elapsedTime;
    const eventElapsed = time - eventStartedAtRef.current;
    const memoryPulse = visualEvent?.memoryGranted
      && eventElapsed >= 0
      && eventElapsed < 1.2
      ? Math.sin((eventElapsed / 1.2) * Math.PI)
      : 0;
    const lockedPulse = visualEvent?.interactionId === 'opening-door'
      && visualEvent.outcome === 'locked'
      && eventElapsed >= 0
      && eventElapsed < 0.65
      ? Math.max(0, Math.sin(eventElapsed * 31))
      : 0;

    const electricalNoise = 0.96
      + Math.sin(time * 17.7) * 0.02
      + Math.sin(time * 3.1) * 0.02;
    if (overhead) {
      overhead.intensity = (
        quality === 'mobile' ? 2.0 : 2.8
      ) * electricalNoise;
    }
    if (memory) {
      memory.intensity = MathUtils.damp(
        memory.intensity,
        1.8
          + memoryPulse * 3.5
          + (focusedInteractionId === 'opening-clock' ? 1.0 : 0),
        8,
        delta,
      );
    }
    if (door) {
      door.color.lerp(doorTargetColor, 1 - Math.exp(-delta * 6));
      door.intensity = MathUtils.damp(
        door.intensity,
        (doorUnlocked ? 3.6 : 1.8)
          + lockedPulse * 3.5
          + (focusedInteractionId === 'opening-door' ? 1.0 : 0),
        11,
        delta,
      );
    }
    if (deskSpot) {
      deskSpot.intensity = MathUtils.damp(
        deskSpot.intensity,
        2.6 + (focusedInteractionId === 'opening-photo' ? 0.9 : 0),
        6,
        delta,
      );
    }
    if (vaultStrobe) {
      if (breachProgress > 0) {
        const strobe = Math.sin(time * 14.0);
        vaultStrobe.intensity = strobe > 0.08 ? (3.5 + breachProgress * 4.0) : 0.2;
      } else {
        vaultStrobe.intensity = 0;
      }
    }
  });

  return (
    <group name="opening-room-light-rig">
      {/* Global ambient — balanced obsidian contrast for sci-fi atmosphere */}
      <ambientLight intensity={0.55} color="#101a26" />
      <hemisphereLight
        color="#182c40"
        groundColor="#040810"
        intensity={0.6}
      />
      {/* Key directional — focused top-down key light like Genshin */}
      <directionalLight
        position={[3, 16, 6]}
        intensity={2.4}
        color="#e6f4ff"
        castShadow={qualityConfig.dynamicShadows}
        shadow-mapSize-width={quality === 'high' ? 2048 : 1024}
        shadow-mapSize-height={quality === 'high' ? 2048 : 1024}
        shadow-bias={-0.0002}
      />
      {/* Fill light from opposite side */}
      <directionalLight
        position={[-5, 8, -4]}
        intensity={0.75}
        color="#508fae"
      />

      {/* Awakening Dais & Echo Hero Spotlight (z = 10.8) — soft balanced anime key light */}
      <pointLight
        position={[0, 3.8, 10.8]}
        intensity={2.2}
        distance={8}
        decay={2.0}
        color="#ffffff"
      />
      <pointLight
        position={[0, 1.5, 9.8]}
        intensity={1.2}
        distance={5}
        decay={2.0}
        color="#90d8ff"
      />
      {/* Stasis Pod Back Glow */}
      <pointLight
        position={[0, 2.0, 13.8]}
        intensity={2.0}
        distance={6}
        decay={2.0}
        color="#00cfff"
      />

      {/* CORRIDOR CEILING LED ARRAY — balanced 3-light array with natural falloff */}
      {[-10, 0, 10].map((z) => (
        <pointLight
          key={z}
          position={[0, 5.0, z]}
          intensity={quality === 'mobile' ? 1.8 : 2.5}
          distance={12}
          decay={2.0}
          color={z === 0 ? '#00e5ff' : '#33ccff'}
        />
      ))}

      {/* Emergency Containment Breach Strobe Light */}
      <pointLight
        ref={vaultStrobeRef}
        position={[11.0, 4.5, -8.5]}
        intensity={0}
        distance={14}
        decay={2.0}
        color="#ff0033"
      />

      {/* Deep Containment Arena Primary Floodlight — main overhead illumination */}
      <pointLight
        position={[11.0, 5.8, -8.5]}
        intensity={quality === 'mobile' ? 4.5 : 8.0}
        distance={22}
        decay={1.6}
        color="#d8f4ff"
      />

      {/* Monster Silhouette Rim Keylight — brings out 3D form */}
      <pointLight
        position={[11.0, 2.6, -11.6]}
        intensity={5.5}
        distance={12}
        decay={1.8}
        color="#ff1744"
      />

      {/* 4-Corner Vault Floodlights — fill all dark spots */}
      <pointLight position={[8.2, 3.2, -5.5]}  intensity={3.8} distance={11} decay={2.0} color="#00c8ff" />
      <pointLight position={[14.2, 3.2, -5.5]} intensity={3.8} distance={11} decay={2.0} color="#00c8ff" />
      <pointLight position={[8.2, 3.2, -11.5]} intensity={3.5} distance={11} decay={2.0} color="#4080ff" />
      <pointLight position={[14.2, 3.2, -11.5]} intensity={3.5} distance={11} decay={2.0} color="#4080ff" />

      {/* Dramatic overhead spotlight on monster position */}
      <spotLight
        position={[11.0, 8.0, -8.5]}
        target-position={[11.0, 0, -8.5]}
        intensity={quality === 'mobile' ? 0 : 12.0}
        angle={0.45}
        penumbra={0.6}
        distance={16}
        decay={1.4}
        color="#ffffff"
        castShadow={quality === 'high'}
      />

      <pointLight
        position={[11.0, 0.5, -8.5]}
        intensity={2.0}
        distance={7}
        decay={2.0}
        color="#0a1d30"
      />

      {/* Side wall accent lights — add depth and color richness */}
      {[-6, 6].map((z) => (
        <pointLight
          key={`west-${z}`}
          position={[-4.0, 2.5, z]}
          intensity={1.6}
          distance={8}
          decay={2.0}
          color="#00c8ff"
        />
      ))}

      {/* Sub-Lab Alpha — warm cyan science zone */}
      <pointLight
        position={[9.0, 4.2, 7.5]}
        intensity={3.5}
        distance={14}
        decay={2.0}
        color="#00f0ff"
      />

      {/* Sub-Chamber Beta — warm amber genetic quarantine zone */}
      <pointLight
        position={[9.5, 4.0, 0]}
        intensity={3.2}
        distance={14}
        decay={2.0}
        color="#ff9922"
      />

      {/* Deep Containment Vault EX-000 — blood red alert */}
      <pointLight
        position={[11.0, 4.2, -8.0]}
        intensity={4.0}
        distance={12}
        decay={2.0}
        color="#ff0033"
      />

      {/* Clock Point of Interest — pulsing memory light */}
      <pointLight
        ref={memoryRef}
        position={[0.65, 1.8, -3.0]}
        intensity={2.5}
        distance={8}
        decay={2.0}
        color={OPENING_ROOM_PALETTE.memory}
      />
      {/* Workstation Desk Spotlight */}
      <spotLight
        ref={deskSpotRef}
        position={[2.55, 3.6, -1.0]}
        intensity={3.6}
        distance={12}
        decay={2.0}
        angle={0.65}
        penumbra={0.75}
        color="#8cf4ff"
        castShadow={quality === 'high'}
      />
      {/* Exit Blast Door Light */}
      <pointLight
        ref={doorRef}
        position={[-2.3, 2.0, -3.0]}
        intensity={doorUnlocked ? 4.0 : 2.0}
        distance={8}
        decay={2.0}
        color={
          doorUnlocked
            ? OPENING_ROOM_PALETTE.memory
            : OPENING_ROOM_PALETTE.danger
        }
      />
    </group>
  );
}
