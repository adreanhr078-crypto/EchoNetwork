import {
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
const ECHO_REST_ROTATIONS: Record<string, readonly [number, number, number, number]> = {
  "pelvis": [
    -0.13661006093025208,
    -0.8601400852203369,
    -0.3026028573513031,
    0.38720571994781494
  ],
  "chest": [
    -1.8584241923136346e-9,
    9.435557046799659e-8,
    2.7095666155219078e-8,
    1
  ],
  "L_UpperarmTwist02": [
    8.752994773431055e-9,
    2.0570054104496194e-8,
    2.3832853912608698e-7,
    1
  ],
  "L_UpperarmTwist01": [
    -5.551638704304196e-9,
    2.2454756276601984e-7,
    2.999513526447117e-8,
    1
  ],
  "hand.L": [
    0.27308496832847595,
    0.6352605819702148,
    -0.004525399766862392,
    0.7223905920982361
  ],
  "L_ForearmTwist02": [
    -3.120520375432534e-8,
    1.4580674445596742e-8,
    -1.3038517820973539e-8,
    1
  ],
  "L_ForearmTwist01": [
    -2.049424274730427e-8,
    -2.7356353626828422e-8,
    -7.17118453508192e-8,
    1
  ],
  "lower_arm.L": [
    0.0625343844294548,
    0.17521479725837708,
    0.06818258762359619,
    0.980173647403717
  ],
  "upper_arm.L": [
    0.04547813907265663,
    0.025707831606268883,
    -0.7044022679328918,
    0.7078758478164673
  ],
  "clavicle.L": [
    0.5963666439056396,
    -0.8001852035522461,
    -0.011366813443601131,
    0.06262053549289703
  ],
  "hand.R": [
    0.1793527454137802,
    -0.5196126699447632,
    0.07650842517614365,
    0.8318544030189514
  ],
  "R_ForearmTwist02": [
    1.4082958799122025e-8,
    -2.930952121005248e-7,
    -7.450581485102248e-9,
    1
  ],
  "R_ForearmTwist01": [
    -1.4995075403589908e-8,
    -2.182623859425803e-7,
    -1.1920928955078125e-7,
    1
  ],
  "lower_arm.R": [
    0.17439337074756622,
    -0.39649200439453125,
    -0.008746418170630932,
    0.9012793898582458
  ],
  "R_UpperarmTwist02": [
    -6.186382961459458e-8,
    4.480411774920867e-8,
    -3.4924596548080444e-7,
    1
  ],
  "R_UpperarmTwist01": [
    1.435789087622652e-8,
    -5.318452878100288e-8,
    1.555308699607849e-7,
    1
  ],
  "upper_arm.R": [
    -0.172691211104393,
    0.10139778256416321,
    0.5813151001930237,
    0.7886500954627991
  ],
  "clavicle.R": [
    -0.6759777665138245,
    -0.7349183559417725,
    0.052285607904195786,
    0.014672149904072285
  ],
  "head": [
    1.3756681482846034e-7,
    -4.160265376640382e-8,
    4.96838801211652e-8,
    1
  ],
  "neck_upper": [
    1.9996333833205426e-7,
    1.6332160157617182e-7,
    -4.221510607749224e-8,
    1
  ],
  "neck": [
    -1.0227768143522553e-7,
    1.1426476476117386e-7,
    1.8389983980071634e-9,
    1
  ],
  "spine_02": [
    8.028897582335048e-7,
    -1.1697710533553618e-7,
    -1.6582634998485446e-7,
    1
  ],
  "spine_01": [
    -0.13661010563373566,
    -0.8601399064064026,
    -0.30260324478149414,
    0.3872058689594269
  ],
  "L_ThighTwist02": [
    6.175141464836997e-8,
    8.42678176127265e-8,
    -1.4319086361069822e-8,
    1
  ],
  "L_ThighTwist01": [
    6.433495070012896e-9,
    -3.0495777991745854e-7,
    4.18804120272398e-8,
    1
  ],
  "toe.L": [
    -3.3084759820667387e-7,
    -0.02541467547416687,
    1.1103432484560471e-7,
    0.9996770024299622
  ],
  "foot.L": [
    0.6227408051490784,
    -0.07617241889238358,
    0.0732751190662384,
    0.775256335735321
  ],
  "L_CalfTwist02": [
    -8.158435038652101e-10,
    2.5820554583333433e-9,
    3.5247469387655883e-9,
    1
  ],
  "L_CalfTwist01": [
    2.342109173270046e-9,
    2.902419460326655e-8,
    2.1936557459412143e-8,
    1
  ],
  "shin.L": [
    0.02820810116827488,
    -0.0023624671157449484,
    -0.05601929873228073,
    0.9980283975601196
  ],
  "thigh.L": [
    0.34869980812072754,
    -0.3884492516517639,
    0.8475882411003113,
    0.09544512629508972
  ],
  "R_ThighTwist02": [
    5.393213342586023e-8,
    -1.1010712341885665e-7,
    1.2922100722789764e-8,
    1
  ],
  "R_ThighTwist01": [
    -7.735918217122162e-8,
    4.516292051448545e-8,
    1.4901161193847656e-8,
    1
  ],
  "toe.R": [
    -3.487436401883315e-7,
    0.024895379319787025,
    1.2332907317613717e-7,
    0.999690055847168
  ],
  "foot.R": [
    0.5985069870948792,
    0.08287477493286133,
    -0.045376405119895935,
    0.795526385307312
  ],
  "R_CalfTwist02": [
    -1.1411032119212905e-9,
    -1.6574213645981217e-7,
    6.490790838142857e-8,
    1
  ],
  "R_CalfTwist01": [
    9.69273905582213e-9,
    1.4527697089761205e-7,
    -5.756646714871749e-8,
    1
  ],
  "shin.R": [
    0.08632485568523407,
    0.005940276198089123,
    -0.011866667307913303,
    0.9961786866188049
  ],
  "thigh.R": [
    0.3798017203807831,
    -0.3845745027065277,
    0.8191419243812561,
    0.19198855757713318
  ],
  "hips": [
    0.36812150478363037,
    -0.3681212365627289,
    -0.16997630894184113,
    0.836708664894104
  ],
  "root": [
    -0.7071067690849304,
    5.7642520090439575e-8,
    -4.260662933575077e-9,
    0.7071067690849304
  ],
  "Echo_Body_Mesh": [
    0,
    0,
    0,
    1
  ],
  "SkinTattoo_EX011_Echo": [
    0,
    0,
    0,
    1
  ],
  "Echo_Armature": [
    0,
    0,
    0,
    1
  ]
};

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

  return new QuaternionKeyframeTrack(`${boneName}.quaternion`, times, quatValues);
}

/**
 * Synthesizes high-fidelity anime martial arts combat animation clips
 * (Genshin / NieR: Automata quality) tailored directly to Echo's 41-bone armature.
 */
export function createCombatAnimationClips(): AnimationClip[] {
  // 1. PUNCH_JAB: Lead left jab — coil → SNAP → hold impact → retract → guard
  //    Extended to 0.45s so the snap and retraction are clearly visible
  const punchJab = new AnimationClip('PUNCH_JAB', 0.45, [
    // Hips: slight forward lean into the jab
    makeQuatTrack('hips',     [0, 0.05, 0.12, 0.22, 0.35, 0.45], [[0,0,0], [0.04, 0.10, 0], [0.06, 0.15, 0], [0.05, 0.12, 0], [0.02, 0.05, 0], [0,0,0]]),
    makeQuatTrack('spine_01', [0, 0.05, 0.12, 0.22, 0.35, 0.45], [[0,0,0], [0.06, 0.18, 0], [0.09, 0.26, 0], [0.08, 0.22, 0], [0.03, 0.08, 0], [0,0,0]]),
    makeQuatTrack('spine_02', [0, 0.05, 0.12, 0.22, 0.35, 0.45], [[0,0,0], [0.04, 0.14, 0], [0.06, 0.20, 0], [0.05, 0.17, 0], [0.02, 0.06, 0], [0,0,0]]),
    // Clavicle L: drives forward with the jab
    makeQuatTrack('clavicle.L', [0, 0.05, 0.12, 0.22, 0.35, 0.45], [[0,0,0], [0.10, 0.20, 0], [0.18, 0.32, 0], [0.15, 0.25, 0], [0.06, 0.10, 0], [0,0,0]]),
    // Upper arm L: full extension snap at t=0.12
    makeQuatTrack('upper_arm.L', [0, 0.05, 0.12, 0.22, 0.35, 0.45], [[0,0,0], [0.65, 0.25, -0.18], [1.28, 0.42, -0.30], [1.15, 0.35, -0.25], [0.45, 0.15, -0.10], [0,0,0]]),
    makeQuatTrack('lower_arm.L', [0, 0.05, 0.12, 0.22, 0.35, 0.45], [[0,0,0], [0.50, 0, 0.12], [0.92, 0, 0.24], [0.85, 0, 0.20], [0.35, 0, 0.08], [0,0,0]]),
    makeQuatTrack('hand.L',      [0, 0.05, 0.12, 0.22, 0.35, 0.45], [[0,0,0], [0.12, 0.25, 0], [0.22, 0.45, 0], [0.20, 0.40, 0], [0.08, 0.15, 0], [0,0,0]]),
    // Right arm: guard position — elbow up, forearm across chin
    makeQuatTrack('upper_arm.R', [0, 0.05, 0.12, 0.22, 0.35, 0.45], [[0,0,0], [0.45, -0.20, 0.35], [0.60, -0.28, 0.45], [0.55, -0.25, 0.40], [0.25, -0.10, 0.18], [0,0,0]]),
    makeQuatTrack('lower_arm.R', [0, 0.05, 0.12, 0.22, 0.35, 0.45], [[0,0,0], [0.80, -0.12, 0.28], [1.02, -0.18, 0.38], [0.95, -0.15, 0.35], [0.40, -0.06, 0.14], [0,0,0]]),
    // Head: chin tucked into lead shoulder during jab
    makeQuatTrack('head', [0, 0.05, 0.12, 0.22, 0.35, 0.45], [[0,0,0], [-0.08, -0.04, 0], [-0.12, -0.06, 0], [-0.10, -0.05, 0], [-0.04, -0.02, 0], [0,0,0]]),
  ]);

  // 2. PUNCH_CROSS: Heavy rear right cross — full kinetic chain: rear foot pivot → hip → shoulder → fist
  //    Extended to 0.55s for full wind-up visibility
  const punchCross = new AnimationClip('PUNCH_CROSS', 0.55, [
    // Hips: major 45° counter-clockwise pivot (rear foot drive)
    makeQuatTrack('hips',     [0, 0.06, 0.14, 0.24, 0.40, 0.55], [[0,0,0], [0.04, -0.22, 0], [0.08, -0.45, 0], [0.06, -0.38, 0], [0.02, -0.12, 0], [0,0,0]]),
    makeQuatTrack('spine_01', [0, 0.06, 0.14, 0.24, 0.40, 0.55], [[0,0,0], [0.08, -0.28, 0], [0.14, -0.52, 0], [0.12, -0.45, 0], [0.04, -0.15, 0], [0,0,0]]),
    makeQuatTrack('spine_02', [0, 0.06, 0.14, 0.24, 0.40, 0.55], [[0,0,0], [0.05, -0.22, 0], [0.10, -0.42, 0], [0.08, -0.35, 0], [0.03, -0.12, 0], [0,0,0]]),
    // Clavicle R: drives hard forward with the cross
    makeQuatTrack('clavicle.R', [0, 0.06, 0.14, 0.24, 0.40, 0.55], [[0,0,0], [0.12, -0.22, 0], [0.20, -0.35, 0], [0.18, -0.28, 0], [0.06, -0.10, 0], [0,0,0]]),
    // Rear right fist fires with full power — longer extension than jab
    makeQuatTrack('upper_arm.R', [0, 0.06, 0.14, 0.24, 0.40, 0.55], [[0,0,0], [0.72, -0.28, 0.22], [1.55, -0.45, 0.38], [1.35, -0.35, 0.30], [0.55, -0.14, 0.12], [0,0,0]]),
    makeQuatTrack('lower_arm.R', [0, 0.06, 0.14, 0.24, 0.40, 0.55], [[0,0,0], [0.55, 0, -0.18], [1.08, 0, -0.30], [0.95, 0, -0.25], [0.38, 0, -0.10], [0,0,0]]),
    makeQuatTrack('hand.R',      [0, 0.06, 0.14, 0.24, 0.40, 0.55], [[0,0,0], [0.15, -0.30, 0], [0.28, -0.52, 0], [0.25, -0.45, 0], [0.10, -0.18, 0], [0,0,0]]),
    // Lead left arm: tight guard at cheek, elbow forward
    makeQuatTrack('upper_arm.L', [0, 0.06, 0.14, 0.24, 0.40, 0.55], [[0,0,0], [0.45, 0.22, -0.28], [0.72, 0.35, -0.42], [0.65, 0.30, -0.35], [0.25, 0.12, -0.14], [0,0,0]]),
    makeQuatTrack('lower_arm.L', [0, 0.06, 0.14, 0.24, 0.40, 0.55], [[0,0,0], [0.72, 0.12, -0.22], [1.12, 0.18, -0.35], [1.05, 0.15, -0.30], [0.42, 0.06, -0.12], [0,0,0]]),
    // Right leg: rear foot pivots on ball of foot as hip turns
    makeQuatTrack('thigh.R', [0, 0.06, 0.14, 0.24, 0.40, 0.55], [[0,0,0], [0.08, -0.18, 0], [0.18, -0.30, 0], [0.15, -0.25, 0], [0.06, -0.10, 0], [0,0,0]]),
    // Head tracks target — slight counter-rotation to hip pivot
    makeQuatTrack('head', [0, 0.06, 0.14, 0.24, 0.40, 0.55], [[0,0,0], [-0.05, 0.06, 0], [-0.10, 0.12, 0], [-0.08, 0.10, 0], [-0.03, 0.04, 0], [0,0,0]]),
  ]);

  // 3. KICK_ROUNDHOUSE: Professional Muay Thai/Kickboxing roundhouse — 3 distinct phases:
  //    CHAMBER (knee up) → PIVOT+WHIP (hip turnover, shin launches) → LAND (back to stance)
  //    Extended to 0.72s so each phase is clearly animated and satisfying
  const kickRoundhouse = new AnimationClip('KICK_ROUNDHOUSE', 0.72, [
    // Hips: big rotation — 90° pivot on planted foot, then return
    makeQuatTrack('hips', [0, 0.08, 0.18, 0.30, 0.42, 0.56, 0.72], [
      [0,0,0],
      [-0.08, -0.28, 0.22],   // start chambering
      [-0.18, -0.62, 0.48],   // full pivot/hip turnover
      [-0.22, -0.82, 0.62],   // IMPACT — shin whip at peak
      [-0.15, -0.55, 0.40],   // begin returning
      [-0.05, -0.18, 0.12],   // almost back
      [0,0,0],                // stand
    ]),
    makeQuatTrack('spine_01', [0, 0.08, 0.18, 0.30, 0.42, 0.56, 0.72], [
      [0,0,0],
      [0.10, 0.15, -0.22],
      [0.22, 0.32, -0.42],
      [0.28, 0.45, -0.52],
      [0.18, 0.28, -0.35],
      [0.06, 0.10, -0.12],
      [0,0,0],
    ]),
    // Planted LEFT leg: pivot on ball of foot
    makeQuatTrack('thigh.L', [0, 0.08, 0.18, 0.30, 0.42, 0.56, 0.72], [
      [0,0,0],
      [0.06, -0.28, 0],
      [0.12, -0.55, 0],
      [0.15, -0.72, 0],
      [0.10, -0.42, 0],
      [0.04, -0.14, 0],
      [0,0,0],
    ]),
    // Kicking RIGHT leg: chamber (knee up high) → hip opens → shin whips horizontal → land
    makeQuatTrack('thigh.R', [0, 0.08, 0.18, 0.30, 0.42, 0.56, 0.72], [
      [0,0,0],
      [0.85, -0.15, 0.42],    // knee chamber — lift knee high
      [1.55, -0.35, 0.88],    // hip turnover — thigh horizontal
      [1.68, -0.45, 1.05],    // IMPACT position
      [1.10, -0.20, 0.62],
      [0.42, -0.08, 0.22],
      [0,0,0],
    ]),
    // Shin: chamber (folded back) → straighten explosively at impact → fold again for land
    makeQuatTrack('shin.R', [0, 0.08, 0.18, 0.30, 0.42, 0.56, 0.72], [
      [0,0,0],
      [1.45, 0, 0],   // folded tight in chamber
      [0.85, 0, 0],   // starting to straighten
      [0.05, 0, 0],   // FULLY EXTENDED — impact!
      [0.65, 0, 0],   // beginning to fold for landing
      [1.25, 0, 0],
      [0,0,0],
    ]),
    // Arms: left arm swings back for counterbalance, right arm goes forward
    makeQuatTrack('upper_arm.L', [0, 0.08, 0.18, 0.30, 0.42, 0.56, 0.72], [
      [0,0,0],
      [0.55, 0.18, -0.15],
      [0.95, 0.35, -0.25],
      [1.05, 0.42, -0.30],
      [0.68, 0.22, -0.18],
      [0.25, 0.08, -0.06],
      [0,0,0],
    ]),
    makeQuatTrack('upper_arm.R', [0, 0.08, 0.18, 0.30, 0.42, 0.56, 0.72], [
      [0,0,0],
      [-0.28, -0.15, 0.32],
      [-0.62, -0.35, 0.65],
      [-0.72, -0.45, 0.75],
      [-0.45, -0.22, 0.48],
      [-0.16, -0.08, 0.18],
      [0,0,0],
    ]),
  ]);

  // 4. KATANA_SLASH: Cyber-katana iai draw slash — backswing → diagonal cleave → follow-through → sheathe guard
  //    Extended to 0.60s for cinematic impact
  const katanaSlash = new AnimationClip('KATANA_SLASH', 0.60, [
    // Hips: big weight transfer — lean back for coil, then drive forward into slash
    makeQuatTrack('hips', [0, 0.08, 0.18, 0.28, 0.40, 0.60], [
      [0,0,0],
      [0.04, 0.22, 0],   // coil back
      [0.12, -0.22, 0],  // hip drive forward
      [0.14, -0.38, 0],  // full extension — CLEAVE
      [0.06, -0.18, 0],
      [0,0,0],
    ]),
    makeQuatTrack('spine_01', [0, 0.08, 0.18, 0.28, 0.40, 0.60], [
      [0,0,0],
      [0.08, 0.32, 0],
      [0.22, -0.42, 0],
      [0.26, -0.55, 0],
      [0.12, -0.25, 0],
      [0,0,0],
    ]),
    makeQuatTrack('spine_02', [0, 0.08, 0.18, 0.28, 0.40, 0.60], [
      [0,0,0],
      [0.05, 0.24, 0],
      [0.15, -0.32, 0],
      [0.18, -0.42, 0],
      [0.08, -0.18, 0],
      [0,0,0],
    ]),
    // Right clavicle + arm: rise for backswing then DRIVE diagonal downward
    makeQuatTrack('clavicle.R', [0, 0.08, 0.18, 0.28, 0.40, 0.60], [
      [0,0,0],
      [0.16, 0.22, 0.12],
      [0.22, -0.28, -0.18],
      [0.18, -0.35, -0.22],
      [0.08, -0.14, -0.08],
      [0,0,0],
    ]),
    makeQuatTrack('upper_arm.R', [0, 0.08, 0.18, 0.28, 0.40, 0.60], [
      [0,0,0],
      [1.45, 0.45, 0.65],   // raised high for backswing
      [-0.85, -0.42, -0.55], // diagonal slash downward
      [-1.45, -0.45, -0.72], // follow-through
      [-0.65, -0.22, -0.32],
      [0,0,0],
    ]),
    makeQuatTrack('lower_arm.R', [0, 0.08, 0.18, 0.28, 0.40, 0.60], [
      [0,0,0],
      [1.22, 0, 0.35],
      [0.38, 0, -0.42],
      [0.18, 0, -0.55],
      [0.28, 0, -0.25],
      [0,0,0],
    ]),
    // Left arm: extended forward for balance during slash, then pulls back
    makeQuatTrack('upper_arm.L', [0, 0.08, 0.18, 0.28, 0.40, 0.60], [
      [0,0,0],
      [0.28, -0.15, -0.25],
      [-0.55, 0.28, 0.42],
      [-0.68, 0.35, 0.52],
      [-0.35, 0.15, 0.25],
      [0,0,0],
    ]),
  ]);

  // 5. DODGE_ROLL: Tactical evasive somersault roll with compact tuck and agile spring-back
  const dodgeRoll = new AnimationClip('DODGE_ROLL', 0.34, [
    makeQuatTrack('hips',     [0, 0.08, 0.17, 0.25, 0.34], [[0,0,0], [-0.6, 0, 0], [-2.2, 0, 0], [-2.9, 0, 0], [0,0,0]]),
    makeQuatTrack('spine_01', [0, 0.08, 0.17, 0.25, 0.34], [[0,0,0], [-0.5, 0, 0], [-0.95, 0, 0], [-0.7, 0, 0], [0,0,0]]),
    makeQuatTrack('thigh.L',  [0, 0.08, 0.17, 0.25, 0.34], [[0,0,0], [0.9, 0, 0], [1.4, 0, 0], [0.8, 0, 0], [0,0,0]]),
    makeQuatTrack('shin.L',   [0, 0.08, 0.17, 0.25, 0.34], [[0,0,0], [1.1, 0, 0], [1.6, 0, 0], [0.9, 0, 0], [0,0,0]]),
    makeQuatTrack('thigh.R',  [0, 0.08, 0.17, 0.25, 0.34], [[0,0,0], [0.9, 0, 0], [1.4, 0, 0], [0.8, 0, 0], [0,0,0]]),
    makeQuatTrack('shin.R',   [0, 0.08, 0.17, 0.25, 0.34], [[0,0,0], [1.1, 0, 0], [1.6, 0, 0], [0.9, 0, 0], [0,0,0]]),
  ]);

  return [punchJab, punchCross, kickRoundhouse, katanaSlash, dodgeRoll];
}
