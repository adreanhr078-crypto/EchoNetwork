import { useEffect, useRef } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { AdditiveBlending, MathUtils, type Group } from 'three';

interface ScreenBreakRuntimeProps {
  reducedMotion: boolean;
  onComplete: () => void;
}

function ScreenBreakScene({ reducedMotion }: { reducedMotion: boolean }) {
  const shardsRef = useRef<Group>(null);
  const { camera } = useThree();
  const elapsedRef = useRef(0);

  useFrame((_, delta) => {
    const group = shardsRef.current;
    if (!group) return;
    elapsedRef.current += Math.min(delta, .05);
    const progress = MathUtils.clamp(
      elapsedRef.current / (reducedMotion ? .7 : 2.35),
      0,
      1,
    );
    const eased = MathUtils.smoothstep(progress, 0, 1);
    camera.position.z = MathUtils.lerp(5.2, 2.4, eased);
    camera.position.x = Math.sin(progress * Math.PI) * .26;
    camera.lookAt(0, 0, 0);
    group.children.forEach((shard, index) => {
      const direction = index % 2 === 0 ? 1 : -1;
      shard.position.x = MathUtils.lerp(0, direction * (1.1 + index * .09), eased);
      shard.position.y = MathUtils.lerp(0, (index - 8) * .11, eased);
      shard.position.z = MathUtils.lerp(.18, -.55 - index * .035, eased);
      shard.rotation.x += delta * (1.5 + index * .04) * direction;
      shard.rotation.y += delta * (1.2 + index * .03);
    });
  });

  return (
    <group ref={shardsRef}>
      <mesh position={[0, 0, -.5]}>
        <planeGeometry args={[8, 5]} />
        <meshBasicMaterial color="#010407" />
      </mesh>
      {Array.from({ length: 18 }, (_, index) => (
        <mesh
          key={index}
          position={[(index - 9) * .08, (index % 3 - 1) * .08, index * .02]}
          rotation={[0, 0, (index % 4 - 2) * .12]}
        >
          <planeGeometry args={[.25 + (index % 3) * .08, .8 + (index % 4) * .13]} />
          <meshBasicMaterial
            color={index % 3 === 0 ? '#ff4962' : '#58e9ff'}
            transparent
            opacity={.32 + (index % 4) * .1}
            blending={AdditiveBlending}
            toneMapped={false}
            side={2}
          />
        </mesh>
      ))}
    </group>
  );
}

export function ScreenBreakRuntime({
  reducedMotion,
  onComplete,
}: ScreenBreakRuntimeProps) {
  const completedRef = useRef(false);
  const finish = () => {
    if (completedRef.current) return;
    completedRef.current = true;
    onComplete();
  };

  useEffect(() => {
    const timer = window.setTimeout(finish, reducedMotion ? 850 : 2_650);
    return () => window.clearTimeout(timer);
  }, [reducedMotion]);

  return (
    <div className="screen-break-runtime" role="dialog" aria-modal="true" aria-label="Screen break">
      <Canvas
        className="screen-break-runtime__canvas"
        dpr={reducedMotion ? [1, 1] : [1, 1.5]}
        camera={{ fov: 48, near: .1, far: 30, position: [0, 0, 5.2] }}
        gl={{ antialias: !reducedMotion, powerPreference: 'high-performance' }}
      >
        <color attach="background" args={['#010407']} />
        <ScreenBreakScene reducedMotion={reducedMotion} />
      </Canvas>
      <div className="screen-break-runtime__hud" aria-hidden="true">
        <small>INTERFACE LAYER // FAILURE</small>
        <strong>11:11</strong>
        <span>DEPTH CHANNEL OPEN</span>
      </div>
      <button type="button" className="screen-break-runtime__skip" onClick={finish}>
        Skip transition
      </button>
    </div>
  );
}
