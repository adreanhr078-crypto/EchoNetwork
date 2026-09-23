const fs = require('fs');
const restRotations = JSON.parse(fs.readFileSync('scratch_bone_rest_rotations.json'));

const code = `import {
  AnimationClip,
  Euler,
  Quaternion,
  QuaternionKeyframeTrack,
} from 'three';

/**
 * Rest-pose bone rotations extracted directly from Echo's rigged skeleton (echo.glb).
 * Used to compute absolute quaternions for animation keyframes so that transitions
 * blend seamlessly into and out of the rest/idle pose without popping or distortion.
 */
const ECHO_REST_ROTATIONS: Record<string, readonly [number, number, number, number]> = ${JSON.stringify(restRotations, null, 2)};

function makeQuatTrack(
  boneName: string,
  times: number[],
  deltaEulers: Array<[number, number, number]>,
): QuaternionKeyframeTrack {
  const rest = ECHO_REST_ROTATIONS[boneName] ?? [0, 0, 0, 1];
  const restQ = new Quaternion(rest[0], rest[1], rest[2], rest[3]);
  const quatValues: number[] = [];

  for (let i = 0; i < times.length; i++) {
    const [x, y, z] = deltaEulers[i];
    const deltaQ = new Quaternion().setFromEuler(new Euler(x, y, z, 'YXZ'));
    const combined = restQ.clone().multiply(deltaQ).normalize();
    quatValues.push(combined.x, combined.y, combined.z, combined.w);
  }

  return new QuaternionKeyframeTrack(\`\${boneName}.quaternion\`, times, quatValues);
}

/**
 * Synthesizes high-fidelity anime martial arts combat animation clips
 * (Genshin / NieR: Automata quality) tailored directly to Echo's 41-bone armature.
 */
export function createCombatAnimationClips(): AnimationClip[] {
  // 1. PUNCH_JAB: Fast, crisp left lead jab with hip drive, torso coil, and chin guard
  const punchJab = new AnimationClip('PUNCH_JAB', 0.28, [
    makeQuatTrack('hips', [0, 0.08, 0.14, 0.28], [[0,0,0], [0.05, 0.12, 0], [0.05, 0.12, 0], [0,0,0]]),
    makeQuatTrack('spine_01', [0, 0.08, 0.14, 0.28], [[0,0,0], [0.08, 0.22, 0], [0.08, 0.22, 0], [0,0,0]]),
    makeQuatTrack('spine_02', [0, 0.08, 0.14, 0.28], [[0,0,0], [0.05, 0.18, 0], [0.05, 0.18, 0], [0,0,0]]),
    makeQuatTrack('clavicle.L', [0, 0.08, 0.14, 0.28], [[0,0,0], [0.15, 0.25, 0], [0.15, 0.25, 0], [0,0,0]]),
    makeQuatTrack('upper_arm.L', [0, 0.08, 0.14, 0.28], [[0,0,0], [1.15, 0.35, -0.25], [1.15, 0.35, -0.25], [0,0,0]]),
    makeQuatTrack('lower_arm.L', [0, 0.08, 0.14, 0.28], [[0,0,0], [0.85, 0, 0.2], [0.85, 0, 0.2], [0,0,0]]),
    makeQuatTrack('hand.L', [0, 0.08, 0.14, 0.28], [[0,0,0], [0.2, 0.4, 0], [0.2, 0.4, 0], [0,0,0]]),
    makeQuatTrack('upper_arm.R', [0, 0.08, 0.14, 0.28], [[0,0,0], [0.55, -0.25, 0.4], [0.55, -0.25, 0.4], [0,0,0]]),
    makeQuatTrack('lower_arm.R', [0, 0.08, 0.14, 0.28], [[0,0,0], [0.95, -0.15, 0.35], [0.95, -0.15, 0.35], [0,0,0]]),
    makeQuatTrack('head', [0, 0.08, 0.14, 0.28], [[0,0,0], [-0.1, -0.05, 0], [-0.1, -0.05, 0], [0,0,0]])
  ]);

  // 2. PUNCH_CROSS: Heavy right cross with kinetic chain drive, hip pivot, and torso follow-through
  const punchCross = new AnimationClip('PUNCH_CROSS', 0.34, [
    makeQuatTrack('hips', [0, 0.09, 0.16, 0.34], [[0,0,0], [0.06, -0.32, 0], [0.06, -0.32, 0], [0,0,0]]),
    makeQuatTrack('spine_01', [0, 0.09, 0.16, 0.34], [[0,0,0], [0.12, -0.42, 0], [0.12, -0.42, 0], [0,0,0]]),
    makeQuatTrack('spine_02', [0, 0.09, 0.16, 0.34], [[0,0,0], [0.08, -0.35, 0], [0.08, -0.35, 0], [0,0,0]]),
    makeQuatTrack('clavicle.R', [0, 0.09, 0.16, 0.34], [[0,0,0], [0.18, -0.28, 0], [0.18, -0.28, 0], [0,0,0]]),
    makeQuatTrack('upper_arm.R', [0, 0.09, 0.16, 0.34], [[0,0,0], [1.35, -0.35, 0.3], [1.35, -0.35, 0.3], [0,0,0]]),
    makeQuatTrack('lower_arm.R', [0, 0.09, 0.16, 0.34], [[0,0,0], [0.95, 0, -0.25], [0.95, 0, -0.25], [0,0,0]]),
    makeQuatTrack('hand.R', [0, 0.09, 0.16, 0.34], [[0,0,0], [0.25, -0.45, 0], [0.25, -0.45, 0], [0,0,0]]),
    makeQuatTrack('upper_arm.L', [0, 0.09, 0.16, 0.34], [[0,0,0], [0.65, 0.3, -0.35], [0.65, 0.3, -0.35], [0,0,0]]),
    makeQuatTrack('lower_arm.L', [0, 0.09, 0.16, 0.34], [[0,0,0], [1.05, 0.15, -0.3], [1.05, 0.15, -0.3], [0,0,0]]),
    makeQuatTrack('thigh.R', [0, 0.09, 0.16, 0.34], [[0,0,0], [0.15, -0.25, 0], [0.15, -0.25, 0], [0,0,0]]),
    makeQuatTrack('head', [0, 0.09, 0.16, 0.34], [[0,0,0], [-0.08, 0.1, 0], [-0.08, 0.1, 0], [0,0,0]])
  ]);

  // 3. KICK_ROUNDHOUSE: High martial arts roundhouse kick with 90° pivot, hip rollover, chambering & snap
  const kickRoundhouse = new AnimationClip('KICK_ROUNDHOUSE', 0.46, [
    makeQuatTrack('hips', [0, 0.10, 0.18, 0.26, 0.34, 0.46], [
      [0,0,0],
      [-0.15, -0.4, 0.35],
      [-0.2, -0.7, 0.55],
      [-0.2, -0.7, 0.55],
      [-0.1, -0.35, 0.25],
      [0,0,0]
    ]),
    makeQuatTrack('spine_01', [0, 0.10, 0.18, 0.26, 0.34, 0.46], [
      [0,0,0],
      [0.15, 0.2, -0.3],
      [0.25, 0.4, -0.45],
      [0.25, 0.4, -0.45],
      [0.12, 0.18, -0.2],
      [0,0,0]
    ]),
    makeQuatTrack('thigh.L', [0, 0.10, 0.18, 0.26, 0.34, 0.46], [
      [0,0,0],
      [0.1, -0.35, 0],
      [0.15, -0.65, 0],
      [0.15, -0.65, 0],
      [0.08, -0.25, 0],
      [0,0,0]
    ]),
    makeQuatTrack('thigh.R', [0, 0.10, 0.18, 0.26, 0.34, 0.46], [
      [0,0,0],
      [1.15, -0.2, 0.55],
      [1.45, -0.4, 0.85],
      [1.45, -0.4, 0.85],
      [0.95, -0.15, 0.4],
      [0,0,0]
    ]),
    makeQuatTrack('shin.R', [0, 0.10, 0.18, 0.26, 0.34, 0.46], [
      [0,0,0],
      [1.35, 0, 0],
      [0.15, 0, 0],
      [0.15, 0, 0],
      [1.1, 0, 0],
      [0,0,0]
    ]),
    makeQuatTrack('upper_arm.L', [0, 0.10, 0.18, 0.26, 0.34, 0.46], [
      [0,0,0],
      [0.75, 0.25, -0.2],
      [0.85, 0.35, -0.25],
      [0.85, 0.35, -0.25],
      [0.4, 0.15, -0.1],
      [0,0,0]
    ]),
    makeQuatTrack('upper_arm.R', [0, 0.10, 0.18, 0.26, 0.34, 0.46], [
      [0,0,0],
      [-0.35, -0.2, 0.4],
      [-0.55, -0.4, 0.6],
      [-0.55, -0.4, 0.6],
      [-0.2, -0.15, 0.2],
      [0,0,0]
    ])
  ]);

  // 4. KATANA_SLASH: Clean cyber-katana diagonal cleave with shoulder coil and follow-through
  const katanaSlash = new AnimationClip('KATANA_SLASH', 0.38, [
    makeQuatTrack('hips', [0, 0.08, 0.16, 0.24, 0.38], [
      [0,0,0],
      [0.05, 0.25, 0],
      [0.1, -0.3, 0],
      [0.1, -0.3, 0],
      [0,0,0]
    ]),
    makeQuatTrack('spine_01', [0, 0.08, 0.16, 0.24, 0.38], [
      [0,0,0],
      [0.1, 0.35, 0],
      [0.18, -0.45, 0],
      [0.18, -0.45, 0],
      [0,0,0]
    ]),
    makeQuatTrack('clavicle.R', [0, 0.08, 0.16, 0.24, 0.38], [
      [0,0,0],
      [0.2, 0.25, 0.15],
      [0.15, -0.3, -0.2],
      [0.15, -0.3, -0.2],
      [0,0,0]
    ]),
    makeQuatTrack('upper_arm.R', [0, 0.08, 0.16, 0.24, 0.38], [
      [0,0,0],
      [1.25, 0.4, 0.55],
      [-1.25, -0.35, -0.65],
      [-1.25, -0.35, -0.65],
      [0,0,0]
    ]),
    makeQuatTrack('lower_arm.R', [0, 0.08, 0.16, 0.24, 0.38], [
      [0,0,0],
      [1.15, 0, 0.3],
      [0.45, 0, -0.35],
      [0.45, 0, -0.35],
      [0,0,0]
    ]),
    makeQuatTrack('upper_arm.L', [0, 0.08, 0.16, 0.24, 0.38], [
      [0,0,0],
      [0.35, -0.2, -0.3],
      [-0.45, 0.25, 0.35],
      [-0.45, 0.25, 0.35],
      [0,0,0]
    ])
  ]);

  // 5. DODGE_ROLL: Tactical evasive somersault roll with compact tuck and agile spring-back
  const dodgeRoll = new AnimationClip('DODGE_ROLL', 0.34, [
    makeQuatTrack('hips', [0, 0.08, 0.17, 0.25, 0.34], [
      [0,0,0],
      [-0.6, 0, 0],
      [-2.2, 0, 0],
      [-2.9, 0, 0],
      [0,0,0]
    ]),
    makeQuatTrack('spine_01', [0, 0.08, 0.17, 0.25, 0.34], [
      [0,0,0],
      [-0.5, 0, 0],
      [-0.95, 0, 0],
      [-0.7, 0, 0],
      [0,0,0]
    ]),
    makeQuatTrack('thigh.L', [0, 0.08, 0.17, 0.25, 0.34], [
      [0,0,0],
      [0.9, 0, 0],
      [1.4, 0, 0],
      [0.8, 0, 0],
      [0,0,0]
    ]),
    makeQuatTrack('shin.L', [0, 0.08, 0.17, 0.25, 0.34], [
      [0,0,0],
      [1.1, 0, 0],
      [1.6, 0, 0],
      [0.9, 0, 0],
      [0,0,0]
    ]),
    makeQuatTrack('thigh.R', [0, 0.08, 0.17, 0.25, 0.34], [
      [0,0,0],
      [0.9, 0, 0],
      [1.4, 0, 0],
      [0.8, 0, 0],
      [0,0,0]
    ]),
    makeQuatTrack('shin.R', [0, 0.08, 0.17, 0.25, 0.34], [
      [0,0,0],
      [1.1, 0, 0],
      [1.6, 0, 0],
      [0.9, 0, 0],
      [0,0,0]
    ])
  ]);

  return [punchJab, punchCross, kickRoundhouse, katanaSlash, dodgeRoll];
}
`;

fs.writeFileSync('artifacts/eleven-eleven/src/features/gameplay/animations/combatAnimationClips.ts', code, 'utf8');
console.log('combatAnimationClips.ts written successfully!');
