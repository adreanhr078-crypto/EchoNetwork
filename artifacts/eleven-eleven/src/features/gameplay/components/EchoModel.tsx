import {
  useEffect,
  useMemo,
  useRef,
} from 'react';
import {
  Clone,
  useAnimations,
  useGLTF,
} from '@react-three/drei';
import { useFrame } from '@react-three/fiber';
import type {
  AnimationAction,
  Group,
} from 'three';
import {
  findEchoAnimationClip,
} from '../systems/echoAnimationSystem';
import type {
  EchoAnimationState,
  EchoVisualStateRef,
} from '../types/echoAnimation.types';
import { EchoAnimationController } from './EchoAnimationController';

const configuredModelUrl = import.meta.env.VITE_ECHO_MODEL_URL?.trim();

/**
 * FINAL ECHO MODEL REPLACEMENT POINT:
 * Set VITE_ECHO_MODEL_URL to a local, licensed .glb in public/assets. Keep the
 * rig at human scale with its feet at y=0 and include named animation clips.
 */
export const ECHO_MODEL_CONFIG = Object.freeze({
  modelUrl: configuredModelUrl || '/assets/characters/echo.glb',
  scale: 1,
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
  const { actions } = useAnimations(animations, groupRef);
  const activeStateRef = useRef<EchoAnimationState | null>(null);
  const activeActionRef = useRef<AnimationAction | null>(null);
  const clipNames = useMemo(
    () => animations.map((clip) => clip.name),
    [animations],
  );

  useFrame(() => {
    const desiredState = visualStateRef.current.state;
    if (desiredState === activeStateRef.current) return;
    activeStateRef.current = desiredState;

    const clipName = findEchoAnimationClip(clipNames, desiredState);
    const nextAction = clipName ? actions[clipName] ?? null : null;
    if (nextAction === activeActionRef.current) return;

    if (nextAction) {
      nextAction.reset().fadeIn(0.22).play();
    }
    activeActionRef.current?.fadeOut(0.22);
    activeActionRef.current = nextAction;
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
      <Clone object={scene} castShadow receiveShadow />
    </group>
  );
}

export function EchoModel({
  visualStateRef,
}: EchoModelProps) {
  if (ECHO_MODEL_CONFIG.modelUrl) {
    return (
      <EchoGlbModel
        url={ECHO_MODEL_CONFIG.modelUrl}
        visualStateRef={visualStateRef}
      />
    );
  }

  return <EchoAnimationController visualStateRef={visualStateRef} />;
}
