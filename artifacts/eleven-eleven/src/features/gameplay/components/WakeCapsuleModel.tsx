import { useEffect, useMemo, useRef } from 'react';
import { useAnimations, useGLTF } from '@react-three/drei';
import { useFrame } from '@react-three/fiber';
import {
  CanvasTexture,
  LoopOnce,
  MathUtils,
  type Group,
  type Mesh,
  type MeshStandardMaterial,
  type Sprite,
  type SpriteMaterial,
} from 'three';

export const WAKE_CAPSULE_MODEL_URL = '/assets/props/sector11-wake-capsule-v2.glb';

export interface WakeCapsuleModelProps {
  position?: [number, number, number];
  rotation?: [number, number, number];
  scale?: number;
  isOpen?: boolean;
}

const VAPOR_COUNT = 8;

function createCondensationRoughnessMap() {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 512;
  const context = canvas.getContext('2d');
  if (!context) return new CanvasTexture(canvas);

  context.fillStyle = '#242424';
  context.fillRect(0, 0, canvas.width, canvas.height);

  let seed = 0x1111;
  const random = () => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return seed / 0xffffffff;
  };

  for (let index = 0; index < 180; index += 1) {
    const x = 24 + random() * 464;
    const y = 18 + random() * 476;
    const radius = 1.8 + Math.pow(random(), 2.4) * 11;
    const stretch = 0.72 + random() * 1.55;
    const droplet = context.createRadialGradient(
      x - radius * 0.22,
      y - radius * 0.28,
      radius * 0.08,
      x,
      y,
      radius * 1.1,
    );
    droplet.addColorStop(0, 'rgba(248,248,248,0.92)');
    droplet.addColorStop(0.38, 'rgba(188,188,188,0.72)');
    droplet.addColorStop(1, 'rgba(50,50,50,0)');
    context.save();
    context.translate(x, y);
    context.scale(1, stretch);
    context.translate(-x, -y);
    context.fillStyle = droplet;
    context.beginPath();
    context.arc(x, y, radius, 0, Math.PI * 2);
    context.fill();
    context.restore();

    if (radius > 7 && random() > 0.42) {
      const length = 18 + random() * 58;
      context.strokeStyle = `rgba(178,178,178,${0.12 + random() * 0.22})`;
      context.lineWidth = Math.max(1.2, radius * 0.28);
      context.lineCap = 'round';
      context.beginPath();
      context.moveTo(x, y + radius * 0.72);
      context.bezierCurveTo(
        x + (random() - 0.5) * 7,
        y + radius + length * 0.32,
        x + (random() - 0.5) * 9,
        y + radius + length * 0.68,
        x + (random() - 0.5) * 12,
        y + radius + length,
      );
      context.stroke();
    }
  }

  const texture = new CanvasTexture(canvas);
  texture.needsUpdate = true;
  return texture;
}

function CapsuleGlassSurface({
  scene,
  capsuleOpen,
}: {
  scene: Group;
  capsuleOpen: boolean;
}) {
  const treatedMaterialRef = useRef<MeshStandardMaterial | null>(null);
  const condensationMap = useMemo(createCondensationRoughnessMap, []);

  useEffect(() => {
    const glass = scene.getObjectByName('Door_Glass') as Mesh | null;
    if (!glass || Array.isArray(glass.material)) return undefined;

    const originalMaterial = glass.material as MeshStandardMaterial;
    const treatedMaterial = originalMaterial.clone();
    treatedMaterial.name = 'M_Capsule_Glass_Condensation';
    treatedMaterial.roughness = capsuleOpen ? 0.34 : 0.68;
    treatedMaterial.roughnessMap = condensationMap;
    treatedMaterial.metalness = 0.03;
    treatedMaterial.depthWrite = false;
    treatedMaterial.envMapIntensity = 1.35;
    treatedMaterial.needsUpdate = true;
    treatedMaterialRef.current = treatedMaterial;
    glass.material = treatedMaterial;

    return () => {
      glass.material = originalMaterial;
      treatedMaterial.dispose();
      treatedMaterialRef.current = null;
    };
  }, [condensationMap, scene]);

  useEffect(() => () => condensationMap.dispose(), [condensationMap]);

  useFrame((_, rawDelta) => {
    const material = treatedMaterialRef.current;
    if (!material) return;
    material.roughness = MathUtils.damp(
      material.roughness,
      capsuleOpen ? 0.34 : 0.68,
      2.4,
      Math.min(rawDelta, 0.05),
    );
  });

  return null;
}

function CapsuleColdVapor({ active }: { active: boolean }) {
  const spritesRef = useRef<(Sprite | null)[]>([]);
  const materialsRef = useRef<(SpriteMaterial | null)[]>([]);
  const elapsedRef = useRef(0);
  const wasActiveRef = useRef(false);
  const vaporTexture = useMemo(() => {
    const canvas = document.createElement('canvas');
    canvas.width = 64;
    canvas.height = 64;
    const context = canvas.getContext('2d');
    if (context) {
      const gradient = context.createRadialGradient(32, 32, 2, 32, 32, 31);
      gradient.addColorStop(0, 'rgba(210,250,255,0.9)');
      gradient.addColorStop(0.28, 'rgba(115,224,235,0.42)');
      gradient.addColorStop(1, 'rgba(30,120,135,0)');
      context.fillStyle = gradient;
      context.fillRect(0, 0, 64, 64);
    }
    return new CanvasTexture(canvas);
  }, []);

  useEffect(() => () => vaporTexture.dispose(), [vaporTexture]);

  useFrame((_, rawDelta) => {
    if (active && !wasActiveRef.current) elapsedRef.current = 0;
    wasActiveRef.current = active;
    elapsedRef.current += Math.min(rawDelta, 0.05);
    const elapsed = elapsedRef.current;
    const releaseEnvelope = active
      ? 1 - MathUtils.smoothstep(elapsed, 1.15, 2.8)
      : 0;

    spritesRef.current.forEach((sprite, index) => {
      const material = materialsRef.current[index];
      if (!sprite || !material) return;
      const cycle = (elapsed * (0.42 + index * 0.012) + index / VAPOR_COUNT) % 1;
      const angle = index * 2.39996;
      const radius = 0.34 + cycle * 0.42;
      sprite.position.set(
        Math.cos(angle) * radius,
        0.12 + cycle * 0.88,
        Math.sin(angle) * radius * 0.62,
      );
      const scale = 0.28 + cycle * 0.48;
      sprite.scale.set(scale, scale * 0.72, 1);
      material.opacity = Math.sin(cycle * Math.PI) * 0.2 * releaseEnvelope;
      sprite.visible = material.opacity > 0.002;
    });
  });

  return (
    <group name="capsule-cold-vapor">
      {Array.from({ length: VAPOR_COUNT }, (_, index) => (
        <sprite
          key={index}
          ref={(sprite) => { spritesRef.current[index] = sprite; }}
        >
          <spriteMaterial
            ref={(material) => { materialsRef.current[index] = material; }}
            map={vaporTexture}
            color="#9beaf2"
            transparent
            opacity={0}
            depthWrite={false}
            toneMapped={false}
          />
        </sprite>
      ))}
    </group>
  );
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
      <CapsuleGlassSurface scene={scene} capsuleOpen={isOpen} />
      <CapsuleColdVapor active={isOpen} />
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
