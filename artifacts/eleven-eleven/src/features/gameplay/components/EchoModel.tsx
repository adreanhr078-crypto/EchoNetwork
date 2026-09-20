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
  Box3,
  Color,
  DoubleSide,
  LoopOnce,
  Vector3,
  type AnimationAction,
  type Group,
} from 'three';

import {
  findEchoAnimationClip,
  resolveLocomotionPlaybackScale,
} from '../systems/echoAnimationSystem';
import { resolveCharacterModelFit } from '../systems/characterModelSystem';
import { createCombatAnimationClips } from '../animations/combatAnimationClips';
import type {
  EchoAnimationState,
  EchoVisualStateRef,
} from '../types/echoAnimation.types';
import { EchoAnimationController } from './EchoAnimationController';

const configuredModelUrl = import.meta.env.VITE_ECHO_MODEL_URL?.trim();

/** Replaceable Echo runtime asset. Visual acceptance remains quality-gated. */
export const ECHO_MODEL_CONFIG = Object.freeze({
  modelUrl: configuredModelUrl || '/assets/characters/echo.runtime.glb',
  targetHeight: 1.78,
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

  const modelFit = useMemo(() => {
    scene.updateMatrixWorld(true);
    const bounds = new Box3().setFromObject(scene);
    const fit = resolveCharacterModelFit(
      {
        min: { x: bounds.min.x, y: bounds.min.y, z: bounds.min.z },
        max: { x: bounds.max.x, y: bounds.max.y, z: bounds.max.z },
      },
      ECHO_MODEL_CONFIG.targetHeight,
    );
    return {
      ...fit,
      offsetVector: new Vector3(fit.offset.x, fit.offset.y, fit.offset.z),
    };
  }, [scene]);

  // Keep imported locomotion clips and the recoverable procedural combat study separate.
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

  // Stylized cel/rim treatment; final material acceptance remains quality-gated.
  useMemo(() => {
    scene.traverse((child) => {
      if ((child as any).isMesh) {
        const mesh = child as any;
        mesh.castShadow = true;
        mesh.receiveShadow = true;
        const materials = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
        for (const mat of materials) {
          if (!mat) continue;
          mat.side = DoubleSide;

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
                // View-space Fresnel rim accent.
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

    // Model-audited clip durations and distance-driven steps share one gait scale.
    if (activeActionRef.current && (desiredState === 'walk' || desiredState === 'run')) {
      activeActionRef.current.timeScale = resolveLocomotionPlaybackScale(
        visual.speed,
        desiredState,
      );
    }
  });


  useEffect(() => () => {
    for (const action of Object.values(actions)) action?.stop();
  }, [actions]);

  return (
    <group
      ref={groupRef}
      scale={modelFit.scale}
    >
      <primitive
        object={scene}
        position={modelFit.offsetVector}
        castShadow
        receiveShadow
      />
    </group>
  );
}

export function EchoModel({
  visualStateRef,
}: EchoModelProps) {
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
