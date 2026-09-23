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
  stunNonce?: number;
  stunDuration?: number;
  onPhaseChange?: (phase: 1 | 2) => void;
  onShockwave?: (shockwaveCenter: Vector3, radius: number) => void;
  onStaggerChange?: (isStaggered: boolean) => void;
  onSlamWindup?: (isWindup: boolean) => void;
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
  stunNonce = 0,
  stunDuration = 2.0,
  onPhaseChange,
  onShockwave,
  onStaggerChange,
  onSlamWindup,
}: {
  breachProgress: number;
  isAgitated: boolean;
  playerPos?: Vector3;
  onMonsterHpChange?: (currentHp: number, maxHp: number) => void;
  onMonsterAttack?: (damage: number) => void;
  onMonsterDefeated?: () => void;
  lastHitNonce?: number;
  lastHitDamage?: number;
  stunNonce?: number;
  stunDuration?: number;
  onPhaseChange?: (phase: 1 | 2) => void;
  onShockwave?: (shockwaveCenter: Vector3, radius: number) => void;
  onStaggerChange?: (isStaggered: boolean) => void;
  onSlamWindup?: (isWindup: boolean) => void;
}) {
  const { scene } = useGLTF('/assets/props/tripo_monster.glb');
  const monsterGroupRef = useRef<Group>(null);
  const eyeLightRef = useRef<PointLight>(null);
  const materialsRef = useRef<MeshStandardMaterial[]>([]);
  const clawArcRef = useRef<Mesh>(null);
  const shockwaveMeshRef = useRef<Mesh>(null);
  const telegraphMeshRef = useRef<Mesh>(null);
  const bioSpinesRef = useRef<Group>(null);

  const hpRef = useRef(1000);
  const maxHpRef = useRef(1000);
  const phaseRef = useRef<1 | 2>(1);
  const attackCountRef = useRef(0);
  const staggerTimerRef = useRef(0);
  const shockwaveTimerRef = useRef(0);
  const shockwaveRadiusRef = useRef(0);
  const recoilRef = useRef(0);
  const attackCooldownRef = useRef(2.0);
  const isDefeatedRef = useRef(false);
  const lastProcessedHitRef = useRef(lastHitNonce);
  const flashTimerRef = useRef(0);
  const logicalPosRef = useRef(new Vector3(0, 0, 0.8));
  const stunTimerRef = useRef(0);
  const lastProcessedStunRef = useRef(stunNonce);

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
      let effectiveDamage = lastHitDamage || 50;

      // Interruption check: If monster is winding up ground slam, trigger synaptic stagger!
      const currentAttackState = monsterGroupRef.current?.userData.attackState;
      if (currentAttackState?.phase === 'slam_windup') {
        staggerTimerRef.current = 3.5;
        onStaggerChange?.(true);
        currentAttackState.phase = 'idle';
      }

      if (staggerTimerRef.current > 0) {
        effectiveDamage *= 2; // Kinetic counter deals 2x critical damage!
      }

      hpRef.current = Math.max(0, hpRef.current - effectiveDamage);
      recoilRef.current = staggerTimerRef.current > 0 ? 0.35 : 1.0;
      flashTimerRef.current = 0.35;
      onMonsterHpChange?.(hpRef.current, maxHpRef.current);

      // Phase 2 Enrage Transition at <= 350 HP
      if (hpRef.current <= 350 && phaseRef.current === 1) {
        phaseRef.current = 2;
        recoilRef.current = 1.8;
        onPhaseChange?.(2);
      }

      if (hpRef.current <= 0 && !isDefeatedRef.current) {
        isDefeatedRef.current = true;
        onMonsterDefeated?.();
      }
    }
  }, [lastHitDamage, lastHitNonce, onMonsterDefeated, onMonsterHpChange, onPhaseChange, onStaggerChange]);

  // Handle resonance pulse stuns & counter interruption
  useEffect(() => {
    if (stunNonce > 0 && stunNonce !== lastProcessedStunRef.current && !isDefeatedRef.current) {
      lastProcessedStunRef.current = stunNonce;
      const currentAttackState = monsterGroupRef.current?.userData.attackState;
      if (currentAttackState?.phase === 'slam_windup') {
        // Countered during slam windup with resonance pulse!
        staggerTimerRef.current = 3.5;
        onStaggerChange?.(true);
        currentAttackState.phase = 'idle';
        recoilRef.current = 1.8;
      } else {
        stunTimerRef.current = stunDuration;
        recoilRef.current = 1.2;
      }
    }
  }, [onStaggerChange, stunDuration, stunNonce]);

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

    // Kinetic Stagger (overload from counter / interrupted ground slam)
    if (staggerTimerRef.current > 0) {
      staggerTimerRef.current = Math.max(0, staggerTimerRef.current - delta);
      monster.position.y = MathUtils.damp(monster.position.y, -0.35, 6, delta);
      monster.rotation.x = MathUtils.damp(monster.rotation.x, 0.58, 6, delta);
      monster.rotation.z = Math.sin(time * 15.0) * 0.04;
      if (eyeLight) {
        eyeLight.color.set('#00f0ff');
        eyeLight.intensity = 2.5 + Math.sin(time * 25.0) * 2.0;
      }
      if (staggerTimerRef.current <= 0) {
        onStaggerChange?.(false);
      }
      return;
    }

    if (stunTimerRef.current > 0) {
      stunTimerRef.current = Math.max(0, stunTimerRef.current - delta);
      // High-frequency bio-resonance paralysis jitter
      monster.position.x = MathUtils.damp(monster.position.x, logicalPosRef.current.x + Math.sin(time * 50.0) * 0.035, 15, delta);
      monster.rotation.z = Math.sin(time * 40.0) * 0.06;
      if (eyeLight) {
        eyeLight.color.set('#00f0ff');
        eyeLight.intensity = 5.5 + Math.sin(time * 40.0) * 3.0;
      }
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
      const isPhase2 = phaseRef.current === 2;

      // Heavy Demonic Respiration (Breathing & Muscle Expansion)
      const breathPulse = Math.sin(time * (isPhase2 ? 5.2 : 3.2));
      const breathScaleY = 1.0 + breathPulse * 0.05;
      const breathScaleXZ = 1.0 - breathPulse * 0.025;
      monster.scale.set(breathScaleXZ, breathScaleY, breathScaleXZ);

      // In Phase 2, illuminate bio-spines
      if (isPhase2 && bioSpinesRef.current) {
        bioSpinesRef.current.visible = true;
      }

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
        const stalkSpeed = isPhase2 ? 1.75 : 1.25;
        if (dist > 1.8 && dist < 14.0 && recoilRef.current <= 0) {
          logicalPosRef.current.x += (dx / dist) * stalkSpeed * delta;
          logicalPosRef.current.z += (dz / dist) * stalkSpeed * delta;

          // Heavy grounded footfall stomps and aggressive forward prowl
          monster.position.y = Math.abs(Math.sin(time * (isPhase2 ? 8.5 : 6.0))) * 0.035 + hitRecoilY;
          monster.rotation.z = Math.sin(time * (isPhase2 ? 8.5 : 6.0)) * 0.08 + hitRecoilShake;
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

        // Fierce Claw Lunge & Swipe / Ground Slam Attack Patterns
        attackCooldownRef.current -= delta;
        const attackState = monster.userData.attackState || { phase: 'idle', timer: 0 };

        if (dist <= (isPhase2 ? 3.6 : 2.8) && attackCooldownRef.current <= 0 && recoilRef.current <= 0 && attackState.phase === 'idle') {
          attackCooldownRef.current = isPhase2 ? 1.75 : 2.4;
          attackCountRef.current += 1;

          if (isPhase2 && attackCountRef.current % 2 === 1) {
            // Leaping Ground Slam
            attackState.phase = 'slam_windup';
            attackState.timer = 0.55;
            onSlamWindup?.(true);
            if (telegraphMeshRef.current) {
              telegraphMeshRef.current.visible = true;
              telegraphMeshRef.current.scale.set(0.4, 0.4, 1);
            }
          } else {
            // Claw attack
            attackState.phase = 'windup';
            attackState.timer = isPhase2 ? 0.38 : 0.6;
          }
        }

        if (attackState.phase === 'slam_windup') {
          attackState.timer -= delta;
          const slamProgress = Math.max(0, Math.min(1, 1.0 - (attackState.timer / 0.55)));
          if (telegraphMeshRef.current) {
            const s = 0.4 + slamProgress * 1.0;
            telegraphMeshRef.current.scale.set(s, s, 1);
          }
          monster.position.y = MathUtils.damp(monster.position.y, 0.55, 8, delta);
          monster.rotation.x = MathUtils.damp(monster.rotation.x, -0.65, 8, delta);
          if (attackState.timer <= 0) {
            attackState.phase = 'slam_active';
            attackState.timer = 0.2;
            onSlamWindup?.(false);
            if (telegraphMeshRef.current) telegraphMeshRef.current.visible = false;
            monster.position.y = 0;
            monster.rotation.x = 0.45;
            shockwaveTimerRef.current = 0.75;
            shockwaveRadiusRef.current = 0.5;
            onMonsterAttack?.(30);
          }
        } else if (attackState.phase === 'slam_active') {
          attackState.timer -= delta;
          if (attackState.timer <= 0) {
            attackState.phase = 'idle';
          }
        } else if (attackState.phase === 'windup') {
          attackState.timer -= delta;
          monster.rotation.x = MathUtils.damp(monster.rotation.x, -0.45, 8, delta);
          if (attackState.timer <= 0) {
            attackState.phase = 'active';
            attackState.timer = 0.15;
            onMonsterAttack?.(25);
            if (clawArcRef.current) clawArcRef.current.visible = true;
            logicalPosRef.current.x += (dx / dist) * 0.65;
            logicalPosRef.current.z += (dz / dist) * 0.65;
            monster.rotation.x = 0.35;
          }
        } else if (attackState.phase === 'active') {
          attackState.timer -= delta;
          if (attackState.timer <= 0) {
            attackState.phase = 'idle';
          }
        }

        monster.userData.attackState = attackState;
      }

      // Handle expanding shockwave ring
      if (shockwaveTimerRef.current > 0) {
        shockwaveTimerRef.current = Math.max(0, shockwaveTimerRef.current - delta);
        const progress = 1.0 - (shockwaveTimerRef.current / 0.75);
        shockwaveRadiusRef.current = 0.5 + progress * 3.8;

        if (shockwaveMeshRef.current) {
          shockwaveMeshRef.current.visible = true;
          const scaleVal = shockwaveRadiusRef.current;
          shockwaveMeshRef.current.scale.set(scaleVal, scaleVal, 1);
          const mat = shockwaveMeshRef.current.material as any;
          if (mat) {
            mat.opacity = Math.max(0, (1.0 - progress) * 0.9);
          }
        }

        if (playerPos) {
          const monsterWorldPos = new Vector3(
            11.0 + monster.position.x * 2.4,
            0,
            -8.5 + monster.position.z * 2.4
          );
          onShockwave?.(monsterWorldPos, shockwaveRadiusRef.current);
        }

        if (shockwaveTimerRef.current <= 0 && shockwaveMeshRef.current) {
          shockwaveMeshRef.current.visible = false;
        }
      }

      // Arena containment boundaries mapped to world space (Deep Containment Vault)
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
        eyeLight.intensity = (flashTimerRef.current > 0 ? 12.0 : (isPhase2 ? 9.5 : 5.5)) + Math.sin(time * 18.0) * 2.5;
        eyeLight.color.set(flashTimerRef.current > 0 ? '#ffffff' : (isPhase2 ? '#ff0055' : '#ff0033'));
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

      {/* Bio-Arc Spine Spikes (Phase 2 Berserk) */}
      <group ref={bioSpinesRef} visible={false} position={[0, 0.75, -0.22]}>
        {[-0.18, 0, 0.18].map((xOff, i) => (
          <mesh key={i} position={[xOff, i * 0.12, 0]} rotation={[0.4, 0, 0]}>
            <coneGeometry args={[0.06, 0.38, 8]} />
            <meshStandardMaterial
              color="#ff0033"
              emissive="#ff0033"
              emissiveIntensity={2.5}
              roughness={0.2}
            />
          </mesh>
        ))}
      </group>

      {/* Red Ground Slam Telegraph Ring */}
      <mesh
        ref={telegraphMeshRef}
        visible={false}
        position={[0, 0.02, 0]}
        rotation={[-Math.PI / 2, 0, 0]}
      >
        <ringGeometry args={[1.2, 1.35, 32]} />
        <meshBasicMaterial color="#ff0044" transparent opacity={0.8} side={DoubleSide} />
      </mesh>

      {/* Expanding Kinetic Shockwave Ring */}
      <mesh
        ref={shockwaveMeshRef}
        visible={false}
        position={[0, 0.03, 0]}
        rotation={[-Math.PI / 2, 0, 0]}
      >
        <ringGeometry args={[0.85, 1.0, 32]} />
        <meshBasicMaterial color="#ff2244" transparent opacity={0.85} side={DoubleSide} />
      </mesh>
    </group>
  );
}

function MonsterFallback({ isAgitated = false }: { isAgitated?: boolean }) {
  return (
    <group position={[0, 1.1, 0]}>
      {/* Faceted bio-mechanical silhouette */}
      <mesh castShadow>
        <capsuleGeometry args={[0.38, 1.45, 8, 16]} />
        <meshStandardMaterial color="#120308" metalness={0.92} roughness={0.25} />
      </mesh>
      {/* Menacing red ocular core */}
      <mesh position={[0, 0.45, 0.32]}>
        <sphereGeometry args={[0.08, 12, 12]} />
        <meshBasicMaterial color="#ff0033" toneMapped={false} />
      </mesh>
      <pointLight color="#ff0033" intensity={isAgitated ? 4.5 : 1.8} distance={3.5} />
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
  onPhaseChange,
  onShockwave,
  onStaggerChange,
  onSlamWindup,
  lastHitNonce = 0,
  lastHitDamage = 0,
  stunNonce = 0,
  stunDuration = 2.0,
}: StasisMonsterModelProps) {
  const shouldMountGlb = isAgitated || breachProgress > 0;

  return (
    <group position={position} rotation={rotation} scale={scale} name="specimen-ex000-monster">
      {shouldMountGlb ? (
        <Suspense fallback={<MonsterFallback isAgitated={isAgitated} />}>
          <MonsterGlbMesh
            breachProgress={breachProgress}
            isAgitated={isAgitated}
            playerPos={playerPos}
            onMonsterHpChange={onMonsterHpChange}
            onMonsterAttack={onMonsterAttack}
            onMonsterDefeated={onMonsterDefeated}
            onPhaseChange={onPhaseChange}
            onShockwave={onShockwave}
            onStaggerChange={onStaggerChange}
            onSlamWindup={onSlamWindup}
            lastHitNonce={lastHitNonce}
            lastHitDamage={lastHitDamage}
            stunNonce={stunNonce}
            stunDuration={stunDuration}
          />
        </Suspense>
      ) : (
        <MonsterFallback isAgitated={false} />
      )}
    </group>
  );
}
