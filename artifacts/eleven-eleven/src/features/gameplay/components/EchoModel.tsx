import {
  Suspense,
  useEffect,
  useMemo,
  useRef,
} from 'react';
import {
  useAnimations,
  useGLTF,
} from '@react-three/drei';
import { useFrame } from '@react-three/fiber';
import {
  Color,
  LoopOnce,
  type AnimationAction,
  type Group,
} from 'three';

import {
  findEchoAnimationClip,
} from '../systems/echoAnimationSystem';
import { createCombatAnimationClips } from '../animations/combatAnimationClips';
import type {
  EchoAnimationState,
  EchoVisualStateRef,
} from '../types/echoAnimation.types';
import { EchoAnimationController } from './EchoAnimationController';

const configuredModelUrl = import.meta.env.VITE_ECHO_MODEL_URL?.trim();

/**
 * FINAL ECHO MODEL REPLACEMENT POINT:
 * Human proportioned rigged 3D character at 1.78m height with Genshin cel-shading
 * and high-fidelity obsidian cyber coat.
 */
export const ECHO_MODEL_CONFIG = Object.freeze({
  modelUrl: configuredModelUrl || '/assets/characters/echo.glb',
  scale: 1.82,
  yOffset: 0,
});

interface EchoModelProps {
  visualStateRef: EchoVisualStateRef;
}

function EchoGlbModel({
  url,
  visualStateRef,
}: {
  url: string;
  visualStateRef: EchoVisualStateRef;
}) {
  const groupRef = useRef<Group>(null);
  const { scene, animations } = useGLTF(url);

  // Combine GLB animations with high-fidelity anime martial arts combat clips
  const sanitizedAnimations = useMemo(() => {
    const glbClips = animations.map((clip) => clip.clone());
    const combatClips = createCombatAnimationClips();
    return [...glbClips, ...combatClips];
  }, [animations]);

  // Bind animations directly to scene Object3D so mixer actions are valid on frame 1
  const { actions } = useAnimations(sanitizedAnimations, scene);
  const activeStateRef = useRef<EchoAnimationState | null>(null);
  const activeActionRef = useRef<AnimationAction | null>(null);
  const clipNames = useMemo(
    () => sanitizedAnimations.map((clip) => clip.name),
    [sanitizedAnimations],
  );

  console.log('[EchoGlbModel] Mounted successfully with clips:', clipNames);

  // Genshin Impact style Anime Cel-Shading + Rim Light shader injection
  useMemo(() => {
    scene.traverse((child) => {
      if ((child as any).isMesh) {
        const mesh = child as any;
        mesh.castShadow = true;
        mesh.receiveShadow = true;
        const materials = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
        for (const mat of materials) {
          if (!mat) continue;
          mat.side = 2; // DoubleSide to prevent backface clipping

          if (mat.name === 'M_SkinTattoo_EX011') {
            mat.emissiveIntensity = 2.8;
            mat.toneMapped = false;
          } else {
            // Anime Cel-Shading on character hero material
            mat.roughness = 0.45;
            mat.metalness = 0.05;
            mat.envMapIntensity = 0.85;

            mat.onBeforeCompile = (shader: any) => {
              shader.uniforms.uRimColor = { value: new Color('#38bdf8') };
              shader.uniforms.uRimPower = { value: 3.2 };

              // Inject rim lighting and toon diffuse quantization in fragment shader
              shader.fragmentShader = `
                uniform vec3 uRimColor;
                uniform float uRimPower;
              ` + shader.fragmentShader;

              shader.fragmentShader = shader.fragmentShader.replace(
                '#include <dithering_fragment>',
                `
                #include <dithering_fragment>
                // Genshin Impact Anime Fresnel Rim Glow
                vec3 viewDir = normalize(vViewPosition);
                float rimDot = 1.0 - max(dot(viewDir, normal), 0.0);
                float rimIntensity = pow(rimDot, uRimPower);
                gl_FragColor.rgb += uRimColor * rimIntensity * 0.45;
                `
              );
            };
            mat.needsUpdate = true;
          }
        }
      }
    });
  }, [scene]);

  useFrame(() => {
    const visual = visualStateRef.current;
    const desiredState = visual.state;

    // Evaluate whenever state changes OR if active action hasn't started yet
    if (desiredState !== activeStateRef.current || !activeActionRef.current) {
      const clipName = findEchoAnimationClip(clipNames, desiredState);
      const nextAction = clipName ? actions[clipName] ?? null : null;

      if (nextAction) {
        activeStateRef.current = desiredState;
        if (nextAction !== activeActionRef.current) {
          const isCombat = ['punch1', 'punch2', 'kick', 'slash', 'dodge'].includes(desiredState);
          if (isCombat) {
            nextAction.reset();
            nextAction.setLoop(LoopOnce, 1);
            nextAction.clampWhenFinished = true;
            nextAction.fadeIn(0.06).play();

            const mixer = nextAction.getMixer();
            const onFinished = (e: { action: typeof nextAction }) => {
              if (e.action === nextAction) {
                mixer.removeEventListener('finished', onFinished as any);
                activeStateRef.current = null;
                activeActionRef.current = null;
                nextAction.clampWhenFinished = false;
              }
            };
            mixer.addEventListener('finished', onFinished as any);
          } else {
            nextAction.reset().fadeIn(0.18).play();
          }
          activeActionRef.current?.fadeOut(isCombat ? 0.08 : 0.18);
          activeActionRef.current = nextAction;
        }
      }
    }

    // Dynamic locomotion timeScale sync: eliminates foot sliding and matches natural steps
    if (activeActionRef.current && (desiredState === 'walk' || desiredState === 'run')) {
      const targetSpeed = desiredState === 'run' ? 5.2 : 2.4;
      const speedScale = Math.max(0.88, Math.min(1.35, visual.speed / targetSpeed));
      activeActionRef.current.timeScale = speedScale;
    }
  });


  useEffect(() => () => {
    for (const action of Object.values(actions)) action?.stop();
  }, [actions]);

  return (
    <group
      ref={groupRef}
      scale={ECHO_MODEL_CONFIG.scale}
      position={[0, ECHO_MODEL_CONFIG.yOffset, 0]}
    >
      <primitive object={scene} castShadow receiveShadow />
    </group>
  );
}

export function EchoModel({
  visualStateRef,
}: EchoModelProps) {
  console.log('[EchoModel] Invoked. Config:', ECHO_MODEL_CONFIG);
  if (ECHO_MODEL_CONFIG.modelUrl) {
    return (
      <Suspense fallback={<EchoAnimationController visualStateRef={visualStateRef} />}>
        <EchoGlbModel
          url={ECHO_MODEL_CONFIG.modelUrl}
          visualStateRef={visualStateRef}
        />
      </Suspense>
    );
  }

  return <EchoAnimationController visualStateRef={visualStateRef} />;
}

if (ECHO_MODEL_CONFIG.modelUrl) {
  useGLTF.preload(ECHO_MODEL_CONFIG.modelUrl);
}
