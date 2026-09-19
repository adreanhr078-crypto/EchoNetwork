import { Suspense, useEffect, useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import { useGLTF } from '@react-three/drei';
import {
  Color,
  DoubleSide,
  MathUtils,
  Vector3,
  type Group,
  type Mesh,
  type MeshStandardMaterial,
  type PointLight,
} from 'three';

export interface StasisMonsterModelProps {
  position?: [number, number, number];
  rotation?: [number, number, number];
  scale?: number;
  breachProgress?: number;
  isAgitated?: boolean;
  playerPos?: Vector3;
  onMonsterHpChange?: (currentHp: number, maxHp: number) => void;
  onMonsterAttack?: (damage: number) => void;
  onMonsterDefeated?: () => void;
  lastHitNonce?: number;
  lastHitDamage?: number;
}

function MonsterGlbMesh({
  breachProgress = 0,
  isAgitated = false,
  playerPos,
  onMonsterHpChange,
  onMonsterAttack,
  onMonsterDefeated,
  lastHitNonce = 0,
  lastHitDamage = 0,
}: {
  breachProgress: number;
  isAgitated: boolean;
  playerPos?: Vector3;
  onMonsterHpChange?: (currentHp: number, maxHp: number) => void;
  onMonsterAttack?: (damage: number) => void;
  onMonsterDefeated?: () => void;
  lastHitNonce?: number;
  lastHitDamage?: number;
}) {
  const { scene } = useGLTF('/assets/props/tripo_monster.glb');
  const monsterGroupRef = useRef<Group>(null);
  const eyeLightRef = useRef<PointLight>(null);
  const materialsRef = useRef<MeshStandardMaterial[]>([]);
  const clawArcRef = useRef<Mesh>(null);

  const hpRef = useRef(1000);
  const maxHpRef = useRef(1000);
  const recoilRef = useRef(0);
  const attackCooldownRef = useRef(2.0);
  const isDefeatedRef = useRef(false);
  const lastProcessedHitRef = useRef(lastHitNonce);
  const flashTimerRef = useRef(0);
  const logicalPosRef = useRef(new Vector3(0, 0, 0.8));

  const clonedScene = useMemo(() => {
    const clone = scene.clone(true);
    const mats: MeshStandardMaterial[] = [];

    clone.traverse((child) => {
      if ((child as Mesh).isMesh) {
        const mesh = child as Mesh;
        mesh.castShadow = true;
        mesh.receiveShadow = true;

        const originalMat = Array.isArray(mesh.material)
          ? mesh.material[0]
          : mesh.material;

        if (originalMat) {
          const mat = originalMat.clone() as MeshStandardMaterial;
          mat.roughness = 0.35;
          mat.metalness = 0.65;
          mat.side = DoubleSide;
          mat.emissive = new Color('#3b071e');
          mat.emissiveIntensity = 0.8;

          mat.onBeforeCompile = (shader) => {
            shader.uniforms.uTime = { value: 0 };
            shader.uniforms.uAgitation = { value: 0 };
            shader.uniforms.uBreach = { value: 0 };
            shader.uniforms.uHitFlash = { value: 0 };

            shader.vertexShader = `
              varying vec3 vWorldPos;
              varying vec3 vNormalVec;
              ${shader.vertexShader}
            `;
            shader.vertexShader = shader.vertexShader.replace(
              '#include <begin_vertex>',
              `
              #include <begin_vertex>
              vWorldPos = (modelMatrix * vec4(transformed, 1.0)).xyz;
              vNormalVec = normalize(normalMatrix * normal);
              `
            );

            shader.fragmentShader = `
              uniform float uTime;
              uniform float uAgitation;
              uniform float uBreach;
              uniform float uHitFlash;
              varying vec3 vWorldPos;
              varying vec3 vNormalVec;
              ${shader.fragmentShader}
            `;

            shader.fragmentShader = shader.fragmentShader.replace(
              '#include <dithering_fragment>',
              `
              #include <dithering_fragment>

              // Stylized Horror Veins & Bio-luminescence
              // Authentic 11.11 Bio-mechanical Veins & Signal Crimson Glow
              float pulse = sin(uTime * 3.5 + vWorldPos.y * 8.0) * 0.5 + 0.5;
              float agitationFlash = sin(uTime * 22.0) * 0.5 + 0.5;

              // Menacing rim glow
              float fresnel = 1.0 - clamp(dot(normalize(vNormalVec), vec3(0.0, 0.0, 1.0)), 0.0, 1.0);
              fresnel = pow(fresnel, 3.0);

              vec3 veinColor = mix(vec3(0.35, 0.02, 0.06), vec3(0.72, 0.05, 0.12), pulse);
              if (uAgitation > 0.5) {
                veinColor = mix(veinColor, vec3(0.85, 0.08, 0.15), agitationFlash);
              }

              gl_FragColor.rgb += clamp(veinColor * fresnel * (0.8 + uBreach * 0.6), 0.0, 0.85);

              // Flash bright white/crimson on damage hit
              if (uHitFlash > 0.05) {
                gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(1.0, 0.85, 0.9), clamp(uHitFlash * 0.75, 0.0, 0.8));
              }
              `
            );

            (mat as any).userDataShader = shader;
          };

          mesh.material = mat;
          mats.push(mat);
        }
      }
    });

    materialsRef.current = mats;
    return clone;
  }, [scene]);

  // Handle damage hits from Echo
  useEffect(() => {
    if (lastHitNonce > 0 && lastHitNonce !== lastProcessedHitRef.current && !isDefeatedRef.current) {
      lastProcessedHitRef.current = lastHitNonce;
      hpRef.current = Math.max(0, hpRef.current - (lastHitDamage || 50));
      recoilRef.current = 1.0;
      flashTimerRef.current = 0.35;
      onMonsterHpChange?.(hpRef.current, maxHpRef.current);

      if (hpRef.current <= 0 && !isDefeatedRef.current) {
        isDefeatedRef.current = true;
        onMonsterDefeated?.();
      }
    }
  }, [lastHitDamage, lastHitNonce, onMonsterDefeated, onMonsterHpChange]);

  useFrame(({ clock }, rawDelta) => {
    const timeScale = (window as any).__11_11_TIME_SCALE ?? 1.0;
    const delta = rawDelta * timeScale;
    const time = clock.getElapsedTime();
    const monster = monsterGroupRef.current;
    const eyeLight = eyeLightRef.current;

    flashTimerRef.current = Math.max(0, flashTimerRef.current - delta);

    for (const mat of materialsRef.current) {
      const shader = (mat as any).userDataShader;
      if (shader?.uniforms) {
        if (shader.uniforms.uTime) shader.uniforms.uTime.value = time;
        if (shader.uniforms.uAgitation) shader.uniforms.uAgitation.value = isAgitated ? 1.0 : 0.0;
        if (shader.uniforms.uBreach) shader.uniforms.uBreach.value = breachProgress;
        if (shader.uniforms.uHitFlash) shader.uniforms.uHitFlash.value = flashTimerRef.current > 0 ? 0.8 : 0.0;
      }
    }

    if (!monster) return;

    if (isDefeatedRef.current) {
      // Defeat collapse
      monster.position.y = MathUtils.damp(monster.position.y, -0.65, 3, delta);
      monster.rotation.x = MathUtils.damp(monster.rotation.x, 1.25, 3, delta);
      if (eyeLight) eyeLight.intensity = MathUtils.damp(eyeLight.intensity, 0, 4, delta);
      if (clawArcRef.current) clawArcRef.current.visible = false;
      return;
    }

    // Stage 1: Inside Tube (waiting / pounding)
    if (breachProgress < 0.2) {
      const twitch = isAgitated ? Math.sin(time * 26.0) * 0.03 : Math.sin(time * 2.0) * 0.008;
      monster.position.set(0, 0.225 + Math.sin(time * 1.6) * 0.025, 0);
      monster.rotation.set(twitch, Math.sin(time * 0.8) * 0.08, Math.cos(time * 1.4) * 0.03);

      if (eyeLight) {
        eyeLight.intensity = isAgitated
          ? 3.8 + Math.sin(time * 28.0) * 2.2
          : 1.5 + Math.sin(time * 3.0) * 0.8;
      }
    } else if (breachProgress < 0.75) {
      // Stage 2: Violently striking the tube glass!
      const strikePhase = MathUtils.euclideanModulo(time * 7.5, 1.0);
      const strikeImpulse = Math.sin(strikePhase * Math.PI);

      monster.position.set(0, 0.225 + Math.sin(time * 4.0) * 0.025, strikeImpulse * 0.28);
      monster.rotation.set(-0.15 + strikeImpulse * 0.35, Math.sin(time * 6.0) * 0.18, 0);

      if (eyeLight) {
        eyeLight.intensity = 6.5 + Math.sin(time * 36.0) * 3.5;
        eyeLight.color.set('#ff0033');
      }
    } else {
      // Stage 3 & 4: Out of the tube! Living Boss Combat Animation, AI Tracking & Violent Reactions
      // Heavy Demonic Respiration (Breathing & Muscle Expansion)
      const breathPulse = Math.sin(time * 3.2);
      const breathScaleY = 1.0 + breathPulse * 0.05;
      const breathScaleXZ = 1.0 - breathPulse * 0.025;
      monster.scale.set(breathScaleXZ, breathScaleY, breathScaleXZ);

      // Visceral Hit Recoil & Impact Stagger: compress defensively instead of floating
      let hitRecoilPitch = 0;
      let hitRecoilShake = 0;
      let hitRecoilY = 0;
      if (recoilRef.current > 0) {
        recoilRef.current = Math.max(0, recoilRef.current - delta * 3.2);
        hitRecoilPitch = -0.45 * recoilRef.current;
        hitRecoilShake = Math.sin(time * 38.0) * 0.14 * recoilRef.current;
        hitRecoilY = -recoilRef.current * 0.06; // Crouch defensively under blow
      }

      if (playerPos) {
        // Monster root is at [11.0, 0, -8.5] with scale 2.4
        const monsterWorldX = 11.0 + monster.position.x * 2.4;
        const monsterWorldZ = -8.5 + monster.position.z * 2.4;
        const dx = playerPos.x - monsterWorldX;
        const dz = playerPos.z - monsterWorldZ;
        const dist = Math.hypot(dx, dz);

        // Menacing Head Tracking: face Echo directly without broken offsets
        const desiredYaw = Math.atan2(dx, dz);
        monster.rotation.y = MathUtils.damp(monster.rotation.y, desiredYaw, 9, delta);

        // Predatory Stalking & Hunting Strides across full arena floor (Grounded feet)
        if (dist > 1.8 && dist < 14.0 && recoilRef.current <= 0) {
          const stalkSpeed = 1.25; // in local units * 2.4 = 3.0 m/s in world space
          logicalPosRef.current.x += (dx / dist) * stalkSpeed * delta;
          logicalPosRef.current.z += (dz / dist) * stalkSpeed * delta;

          // Heavy grounded footfall stomps and aggressive forward prowl
          monster.position.y = Math.abs(Math.sin(time * 6.0)) * 0.035 + hitRecoilY;
          monster.rotation.z = Math.sin(time * 6.0) * 0.08 + hitRecoilShake;
          monster.rotation.x = 0.12 + hitRecoilPitch;
        } else {
          monster.position.y = MathUtils.damp(monster.position.y, hitRecoilY, 10, delta);
          monster.rotation.z = MathUtils.damp(monster.rotation.z, hitRecoilShake, 10, delta);
          monster.rotation.x = MathUtils.damp(monster.rotation.x, hitRecoilPitch, 10, delta);
        }

        // Violent Knockback on Hit Recoil
        if (recoilRef.current > 0.05) {
          const knockbackDirX = dist > 0.1 ? -(dx / dist) : 0;
          const knockbackDirZ = dist > 0.1 ? -(dz / dist) : -1;
          logicalPosRef.current.x += knockbackDirX * recoilRef.current * delta * 2.5;
          logicalPosRef.current.z += knockbackDirZ * recoilRef.current * delta * 2.5;
        }

        // Fierce Claw Lunge & Swipe Attack
        attackCooldownRef.current -= delta;
        const attackState = monster.userData.attackState || { phase: 'idle', timer: 0 };

        if (dist <= 2.8 && attackCooldownRef.current <= 0 && recoilRef.current <= 0 && attackState.phase === 'idle') {
          attackCooldownRef.current = 2.4;
          attackState.phase = 'windup';
          attackState.timer = 0.6; // 0.6s telegraph wind-up
        }

        if (attackState.phase === 'windup') {
          attackState.timer -= delta;
          monster.rotation.x = MathUtils.damp(monster.rotation.x, -0.45, 8, delta); // Rear back heavily
          if (attackState.timer <= 0) {
            attackState.phase = 'active';
            attackState.timer = 0.15; // 0.15s active damage window
            onMonsterAttack?.(25);
            if (clawArcRef.current) clawArcRef.current.visible = true;
            // Explosive forward lunge towards player
            logicalPosRef.current.x += (dx / dist) * 0.65;
            logicalPosRef.current.z += (dz / dist) * 0.65;
            monster.rotation.x = 0.35; // Slam down
          }
        } else if (attackState.phase === 'active') {
          attackState.timer -= delta;
          if (attackState.timer <= 0) {
            attackState.phase = 'idle';
          }
        }

        monster.userData.attackState = attackState;
      }

      // Arena containment boundaries mapped to world space (Deep Containment Vault)
      // Give monster more room to stalk — expanded from x:-2.15..1.04, z:-1.65..1.45
      logicalPosRef.current.x = MathUtils.clamp(logicalPosRef.current.x, -2.5, 2.5);
      logicalPosRef.current.z = MathUtils.clamp(logicalPosRef.current.z, -2.0, 2.0);

      // Smooth visual position toward logical position
      monster.position.x = MathUtils.damp(monster.position.x, logicalPosRef.current.x, 12, delta);
      monster.position.z = MathUtils.damp(monster.position.z, logicalPosRef.current.z, 12, delta);

      // Claw arc visual fade
      if (clawArcRef.current && clawArcRef.current.visible) {
        const mat = clawArcRef.current.material as any;
        if (mat) {
          mat.opacity = Math.max(0, mat.opacity - delta * 3.5);
          if (mat.opacity <= 0) {
            clawArcRef.current.visible = false;
            mat.opacity = 0.85;
          }
        }
      }

      if (eyeLight) {
        eyeLight.intensity = (flashTimerRef.current > 0 ? 12.0 : 5.5) + Math.sin(time * 18.0) * 2.5;
        eyeLight.color.set(flashTimerRef.current > 0 ? '#ffffff' : '#ff0033');
      }
    }
  });

  return (
    <group ref={monsterGroupRef}>
      <primitive object={clonedScene} scale={1.0} position={[0, 0, 0]} />
      <pointLight
        ref={eyeLightRef}
        position={[0, 0.88, 0.18]}
        color="#ff0044"
        intensity={3.2}
        distance={4.0}
        decay={2}
      />

      {/* Crimson Claw Swipe Trail Arc */}
      <mesh
        ref={clawArcRef}
        visible={false}
        position={[0, 0.65, 0.35]}
        rotation={[-Math.PI / 6, 0, 0]}
      >
        <ringGeometry args={[0.4, 0.75, 16, 1, 0, Math.PI * 0.7]} />
        <meshBasicMaterial color="#ff0022" transparent opacity={0.85} side={DoubleSide} toneMapped={false} />
      </mesh>
    </group>
  );
}

function MonsterFallback() {
  return (
    <group position={[0, 1.1, 0]}>
      <mesh castShadow>
        <capsuleGeometry args={[0.35, 1.4, 8, 16]} />
        <meshStandardMaterial color="#1a040d" metalness={0.9} roughness={0.3} />
      </mesh>
      <pointLight color="#ff0044" intensity={2.5} distance={4.0} />
    </group>
  );
}

export function StasisMonsterModel({
  position = [11.0, 0, -8.5],
  rotation = [0, Math.PI, 0],
  scale = 1.0,
  breachProgress = 0,
  isAgitated = false,
  playerPos,
  onMonsterHpChange,
  onMonsterAttack,
  onMonsterDefeated,
  lastHitNonce = 0,
  lastHitDamage = 0,
}: StasisMonsterModelProps) {
  return (
    <group position={position} rotation={rotation} scale={scale} name="specimen-ex000-monster">
      <Suspense fallback={<MonsterFallback />}>
        <MonsterGlbMesh
          breachProgress={breachProgress}
          isAgitated={isAgitated}
          playerPos={playerPos}
          onMonsterHpChange={onMonsterHpChange}
          onMonsterAttack={onMonsterAttack}
          onMonsterDefeated={onMonsterDefeated}
          lastHitNonce={lastHitNonce}
          lastHitDamage={lastHitDamage}
        />
      </Suspense>
    </group>
  );
}

useGLTF.preload('/assets/props/tripo_monster.glb');
