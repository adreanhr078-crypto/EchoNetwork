import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { AnimationClip, VectorKeyframeTrack } from 'three';
import {
  OPENING_DOOR_INTERACTION,
  OPENING_PHOTO_INTERACTION,
  OPENING_ROOM_INTERACTIONS,
} from '../features/gameplay/data/openingRoom.interactions';
import { OPENING_ROOM_MEMORY_ID } from '../features/gameplay/data/openingRoom.puzzles';
import { OPENING_ROOM_ANCHORS } from '../features/gameplay/data/openingRoom.anchors';
import { OPENING_ROOM_CONFIG } from '../features/gameplay/data/openingRoom.config';
import {
  findNearestEnabledInteraction,
} from '../features/gameplay/systems/interactionSystem';
import {
  resolveCameraArmScale,
  resolveCameraRegionBounds,
} from '../features/gameplay/systems/cameraCollisionSystem';
import {
  advanceFootstepPhase,
  findEchoAnimationClip,
  normalizeImportedHipTranslation,
  resolveLocomotionPlaybackScale,
  resolveEchoAnimationState,
} from '../features/gameplay/systems/echoAnimationSystem';
import {
  resolveCharacterModelFit,
} from '../features/gameplay/systems/characterModelSystem';
import {
  collidesWithObstacle,
  integrateHorizontalVelocity,
  movePlayer,
} from '../features/gameplay/systems/playerMovementSystem';
import {
  canUnlockOpeningDoor,
  createOpeningRoomNarrativeFlags,
  transitionOpeningRoomPuzzle,
  type OpeningRoomNarrativeFlags,
} from '../features/gameplay/systems/puzzleSystem';
import type {
  CollisionObstacle,
  InteractionDefinition,
  PlayerMovementConfig,
  PlayerMovementInput,
  RoomBounds,
} from '../features/gameplay/types/gameplay.types';

const ROOM_BOUNDS: RoomBounds = {
  min: { x: -5, y: 0, z: -5 },
  max: { x: 5, y: 2, z: 5 },
};

const MOVEMENT: PlayerMovementConfig = {
  walkSpeed: 4,
  sprintSpeed: 7,
  halfExtents: { x: 0.25, y: 0.5, z: 0.25 },
};

const FORWARD_INPUT: PlayerMovementInput = {
  forward: true,
  backward: false,
  left: false,
  right: false,
  sprint: false,
};

const IDLE_INPUT: PlayerMovementInput = {
  ...FORWARD_INPUT,
  forward: false,
};

function approximatelyEqual(
  actual: number,
  expected: number,
  tolerance = 1e-9,
): void {
  assert.ok(
    Math.abs(actual - expected) <= tolerance,
    `expected ${actual} to be within ${tolerance} of ${expected}`,
  );
}

function solvedFlags(): OpeningRoomNarrativeFlags {
  return createOpeningRoomNarrativeFlags({
    openingClockInspected: true,
    openingPhotoInspected: true,
    openingMemoryRecovered: true,
    openingPuzzleSolved: true,
  });
}

describe('Opening room player movement', () => {
  it('accelerates responsively and decelerates without an instant speed snap', () => {
    const first = integrateHorizontalVelocity({
      velocity: { x: 0, z: 0 },
      input: FORWARD_INPUT,
      deltaSeconds: 1 / 60,
      movement: MOVEMENT,
    });
    const second = integrateHorizontalVelocity({
      velocity: first,
      input: FORWARD_INPUT,
      deltaSeconds: 1 / 60,
      movement: MOVEMENT,
    });
    assert.ok(Math.abs(first.z) > 0);
    assert.ok(Math.abs(first.z) < MOVEMENT.walkSpeed);
    assert.ok(Math.abs(second.z) > Math.abs(first.z));

    const released = integrateHorizontalVelocity({
      velocity: second,
      input: IDLE_INPUT,
      deltaSeconds: 1 / 60,
      movement: MOVEMENT,
    });
    assert.ok(Math.abs(released.z) < Math.abs(second.z));
    assert.ok(Math.abs(released.z) > 0);
  });

  it('uses delta time and clamps the player to the room', () => {
    const quarterSecond = movePlayer({
      position: { x: 0, y: 0.5, z: 0 },
      input: FORWARD_INPUT,
      deltaSeconds: 0.25,
      roomBounds: ROOM_BOUNDS,
      obstacles: [],
      movement: MOVEMENT,
    });
    const halfSecond = movePlayer({
      position: { x: 0, y: 0.5, z: 0 },
      input: FORWARD_INPUT,
      deltaSeconds: 0.5,
      roomBounds: ROOM_BOUNDS,
      obstacles: [],
      movement: MOVEMENT,
    });

    approximatelyEqual(quarterSecond.z, -1);
    approximatelyEqual(halfSecond.z, -2);

    const againstWall = movePlayer({
      position: { x: 0, y: 0.5, z: 0 },
      input: {
        ...FORWARD_INPUT,
        forward: false,
        right: true,
      },
      deltaSeconds: 10,
      roomBounds: ROOM_BOUNDS,
      obstacles: [],
      movement: MOVEMENT,
    });
    assert.equal(againstWall.x, 4.75);
  });

  it('stops on an AABB obstacle while preserving sliding movement', () => {
    const obstacle: CollisionObstacle = {
      id: 'test-cabinet',
      min: { x: 0.8, y: 0, z: -1 },
      max: { x: 1.4, y: 1.5, z: 1 },
    };
    const moved = movePlayer({
      position: { x: 0, y: 0.5, z: 0 },
      input: {
        forward: true,
        backward: false,
        left: false,
        right: true,
        sprint: false,
      },
      deltaSeconds: 0.5,
      roomBounds: ROOM_BOUNDS,
      obstacles: [obstacle],
      movement: MOVEMENT,
    });

    approximatelyEqual(moved.x, 0.55);
    assert.ok(moved.z < -1);
    assert.equal(
      collidesWithObstacle(
        moved,
        MOVEMENT.halfExtents,
        [obstacle],
      ),
      false,
    );
  });
});

describe('Echo visual animation state', () => {
  it('selects idle, walk, run, interaction, and locked states deterministically', () => {
    const base = {
      sprinting: false,
      interactionActive: false,
      cinematicLocked: false,
      paused: false,
    };

    assert.equal(resolveEchoAnimationState({ ...base, speed: 0 }), 'idle');
    assert.equal(resolveEchoAnimationState({ ...base, speed: 1.2 }), 'walk');
    assert.equal(
      resolveEchoAnimationState({
        ...base,
        speed: 2.8,
        sprinting: true,
      }),
      'run',
    );
    assert.equal(
      resolveEchoAnimationState({
        ...base,
        speed: 0,
        interactionActive: true,
      }),
      'interact',
    );
    assert.equal(
      resolveEchoAnimationState({
        ...base,
        speed: 1,
        cinematicLocked: true,
      }),
      'lockedByCinematic',
    );
    assert.equal(
      resolveEchoAnimationState({
        ...base,
        speed: 0,
        cinematicLocked: true,
        cinematicPhase: 'wakeup',
      }),
      'wakeup',
    );
    assert.equal(
      resolveEchoAnimationState({
        ...base,
        speed: 0,
        cinematicLocked: true,
        cinematicPhase: 'standup',
      }),
      'standup',
    );
  });

  it('maps only animation clips that actually exist in a supplied GLB', () => {
    const clips = ['Breathing Idle', 'Locomotion_Walk', 'Sprint_Forward'];
    assert.equal(findEchoAnimationClip(clips, 'idle'), 'Breathing Idle');
    assert.equal(findEchoAnimationClip(clips, 'walk'), 'Locomotion_Walk');
    assert.equal(findEchoAnimationClip(clips, 'run'), 'Sprint_Forward');
    assert.equal(findEchoAnimationClip(clips, 'interact'), null);
  });
});

describe('Opening room interactions', () => {
  interface SelectionContext {
    readonly allowedId: string;
  }

  function interaction(
    id: string,
    x: number,
    interactionDistance: number,
  ): InteractionDefinition<SelectionContext> {
    return {
      id,
      type: 'inspect',
      position: { x, y: 0, z: 0 },
      interactionDistance,
      prompt: `inspect ${id}`,
      enabledCondition: ({ allowedId }) => allowedId === id,
      onInteract: () => ({
        outcome: 'narration',
        message: id,
        effects: [],
      }),
    };
  }

  it('selects the nearest in-range interaction whose condition passes', () => {
    const interactions = [
      interaction('disabled-near', 0.25, 2),
      interaction('enabled-near', 1, 2),
      interaction('enabled-far', 3, 2),
    ];
    const nearest = findNearestEnabledInteraction(
      { x: 0, y: 0, z: 0 },
      interactions,
      { allowedId: 'enabled-near' },
    );

    assert.equal(nearest?.interaction.id, 'enabled-near');
    assert.equal(nearest?.interaction.prompt, 'inspect enabled-near');
    assert.equal(nearest?.distance, 1);
  });

  it('keeps all opening interactions data-driven and spoiler-safe', () => {
    assert.deepEqual(
      OPENING_ROOM_INTERACTIONS.map(({ id }) => id),
      ['opening-clock', 'opening-photo', 'opening-door'],
    );

    for (const definition of OPENING_ROOM_INTERACTIONS) {
      assert.ok(definition.type);
      assert.ok(Number.isFinite(definition.position.x));
      assert.ok(definition.interactionDistance > 0);
      assert.ok(definition.prompt.length > 0);
      assert.equal(typeof definition.enabledCondition, 'function');
      assert.equal(typeof definition.onInteract, 'function');
    }

    const photoCopy = OPENING_PHOTO_INTERACTION.onInteract({
      flags: createOpeningRoomNarrativeFlags(),
    }).message;
    assert.match(
      photoCopy,
      /عندما تشعر بالخوف، عُدّ حتى أحد عشر\./,
    );
    assert.match(
      photoCopy,
      /لا أتذكر الوجه… فقط أنني لم أكن وحدي\./,
    );
  });

  it('uses one reachable spatial contract for every canonical room clue', () => {
    const expectedAnchors = [
      OPENING_ROOM_ANCHORS.clock,
      OPENING_ROOM_ANCHORS.photo,
      OPENING_ROOM_ANCHORS.door,
    ];
    assert.deepEqual(
      OPENING_ROOM_INTERACTIONS.map(({ position }) => position),
      expectedAnchors,
    );

    const approachPoints = [
      { x: 3.4, y: 0.88, z: 2 },
      { x: 6, y: 0.88, z: 6.5 },
      { x: 0, y: 0.88, z: -12.8 },
    ];
    for (const point of approachPoints) {
      assert.equal(
        collidesWithObstacle(
          point,
          OPENING_ROOM_CONFIG.movement.halfExtents,
          OPENING_ROOM_CONFIG.obstacles,
        ),
        false,
      );
    }

    for (let index = 0; index < approachPoints.length; index += 1) {
      const interaction = OPENING_ROOM_INTERACTIONS[index];
      const distance = Math.hypot(
        approachPoints[index].x - interaction.position.x,
        approachPoints[index].y - interaction.position.y,
        approachPoints[index].z - interaction.position.z,
      );
      assert.ok(distance <= interaction.interactionDistance);
    }
  });
});

describe('Opening room camera containment', () => {
  const bounds = {
    minX: -4.5,
    maxX: 13.5,
    minZ: -14,
    maxZ: 16,
    minY: 0.5,
    maxY: 5.5,
  };

  it('selects the authored corridor and chamber bounds from player position', () => {
    assert.equal(resolveCameraRegionBounds({ x: 0, y: 1, z: 0 }, bounds).maxX, 4.7);
    const alpha = resolveCameraRegionBounds({ x: 7, y: 1, z: 7 }, bounds);
    assert.equal(alpha.minX, 5.2);
    assert.equal(alpha.minZ, 4.3);
    assert.equal(alpha.maxZ, 10.7);
    const vault = resolveCameraRegionBounds({ x: 10, y: 1, z: -8 }, bounds);
    assert.equal(vault.maxZ, -4.3);
  });

  it('pulls the camera arm inside a wall and restores full distance in open space', () => {
    const region = resolveCameraRegionBounds({ x: 0, y: 1, z: 0 }, bounds);
    const blocked = resolveCameraArmScale(
      { x: 4, y: 2, z: 0 },
      { x: 3, y: 1, z: 0 },
      region,
    );
    assert.ok(blocked < 1);
    assert.ok(blocked >= 0.35);
    assert.equal(resolveCameraArmScale(
      { x: 0, y: 2, z: 0 },
      { x: 1, y: 1, z: 1 },
      region,
    ), 1);
  });
});

describe('Echo locomotion feedback', () => {
  it('repairs leaked idle and stand hip offsets without changing the other clips', () => {
    const clip = (name: string, times: number[], values: number[]) => new AnimationClip(
      name,
      times[times.length - 1] ?? 0,
      [new VectorKeyframeTrack('hips.position', times, values)],
    );
    const source = [
      clip('IDLE', [0, 1], [0.3335, 0.22, 0.3367, 0.3335, 0.22, 0.3367]),
      clip('WAKEUP', [0, 1], [0, 0, 0.543, 0, 0.1, 0.4]),
      clip('WALK', [0, 1], [0, 0.22, 0.3367, 0.0225, 0.22, 0.3367]),
      clip('STANDUP', [0, 1], [0, 0, 0.3367, 0.3335, 0.22, 0.543]),
    ];

    const normalized = normalizeImportedHipTranslation(source, [0, 0, 0.543]);
    const values = (name: string) => normalized
      .find((entry) => entry.name === name)!.tracks[0].values;

    assert.ok(Math.abs(values('IDLE')[0]) < 1e-6);
    assert.ok(Math.abs(values('IDLE')[1]) < 1e-6);
    assert.ok(Math.abs(values('IDLE')[2] - 0.543) < 1e-6);
    assert.ok(Math.abs(values('WAKEUP')[0]) < 1e-6);
    assert.ok(Math.abs(values('WAKEUP')[3]) < 1e-6);
    assert.ok(Math.abs(values('WAKEUP')[2] - 0.543) < 1e-6);
    assert.ok(Math.abs(values('WALK')[3] - 0.0225) < 1e-6);
    assert.ok(Math.abs(values('STANDUP')[0]) < 1e-6);
    assert.ok(Math.abs(values('STANDUP')[1]) < 1e-6);
    assert.ok(Math.abs(values('STANDUP')[3]) < 1e-6);
    assert.ok(Math.abs(values('STANDUP')[4]) < 1e-6);
    assert.ok(Math.abs(values('STANDUP')[5] - 0.543) < 1e-6);
    assert.equal(source[1].tracks[0].values[0], 0);
  });

  it('emits footsteps from travelled distance instead of elapsed time', () => {
    const partial = advanceFootstepPhase(0, 0.52, false);
    assert.equal(partial.emittedSteps, 0);
    assert.ok(partial.phase > 0.5);

    const contact = advanceFootstepPhase(partial.phase, 0.52, false);
    assert.equal(contact.emittedSteps, 1);
    assert.ok(contact.phase < 0.02);

    const blocked = advanceFootstepPhase(contact.phase, 0, false);
    assert.equal(blocked.emittedSteps, 0);
    assert.equal(blocked.phase, contact.phase);
  });

  it('keeps gait phase stable while changing to the longer sprint step', () => {
    const walk = advanceFootstepPhase(0, 0.5, false);
    const sprint = advanceFootstepPhase(walk.phase, 0.75, true);
    assert.equal(sprint.emittedSteps, 0);
    assert.ok(sprint.phase > walk.phase);
    assert.ok(sprint.phase < 1);
  });

  it('matches playback rate to the audited walk and run cycles', () => {
    const walkScale = resolveLocomotionPlaybackScale(2.4, 'walk');
    const runScale = resolveLocomotionPlaybackScale(5.2, 'run');
    assert.ok(walkScale > 1.45 && walkScale < 1.55);
    assert.ok(runScale > 1.35 && runScale < 1.45);
    assert.equal(resolveLocomotionPlaybackScale(Number.NaN, 'walk'), 0.65);
  });
});

describe('Echo model fit', () => {
  it('centres an offset asset, plants its lowest point, and fits target height', () => {
    const fit = resolveCharacterModelFit({
      min: { x: 0.174, y: -0.123, z: -0.29 },
      max: { x: 0.507, y: 0.76, z: 0.08 },
    }, 1.78);
    assert.ok(fit.scale > 2 && fit.scale < 2.02);
    assert.equal(fit.offset.y, 0.123);
    assert.ok(fit.offset.x < -0.34 && fit.offset.x > -0.341);
  });

  it('falls back safely for invalid bounds', () => {
    assert.deepEqual(resolveCharacterModelFit({
      min: { x: 0, y: 0, z: 0 },
      max: { x: 0, y: 0, z: 0 },
    }, 1.78), {
      scale: 1,
      offset: { x: 0, y: 0, z: 0 },
    });
  });
});

describe('Opening room puzzle state', () => {
  it('moves through every stage in the required order', () => {
    let flags = createOpeningRoomNarrativeFlags();
    assert.equal(
      transitionOpeningRoomPuzzle(flags, {
        type: 'roomEntered',
      }).previousState.stage,
      'locked',
    );

    let transition = transitionOpeningRoomPuzzle(flags, {
      type: 'clockInspected',
    });
    flags = transition.state.flags;
    assert.equal(transition.state.stage, 'clueFound');

    transition = transitionOpeningRoomPuzzle(flags, {
      type: 'photoInspected',
    });
    flags = transition.state.flags;

    transition = transitionOpeningRoomPuzzle(flags, {
      type: 'memoryRecovered',
      memoryId: OPENING_ROOM_MEMORY_ID,
    });
    flags = transition.state.flags;
    assert.equal(transition.state.stage, 'memoryRecovered');

    transition = transitionOpeningRoomPuzzle(flags, {
      type: 'puzzleSolved',
    });
    flags = transition.state.flags;
    assert.equal(transition.state.stage, 'solved');

    transition = transitionOpeningRoomPuzzle(flags, {
      type: 'doorUnlocked',
    });
    assert.equal(transition.state.stage, 'exitUnlocked');
  });

  it('keeps the door locked until solved, then emits its unlock event', () => {
    const initialFlags = createOpeningRoomNarrativeFlags();
    assert.equal(canUnlockOpeningDoor(initialFlags), false);
    assert.equal(
      OPENING_DOOR_INTERACTION.onInteract({
        flags: initialFlags,
      }).outcome,
      'locked',
    );

    const readyFlags = solvedFlags();
    assert.equal(canUnlockOpeningDoor(readyFlags), true);
    const result = OPENING_DOOR_INTERACTION.onInteract({
      flags: readyFlags,
    });
    assert.equal(result.outcome, 'unlocked');
    assert.deepEqual(result.effects, [{
      type: 'openingRoomEvent',
      event: { type: 'doorUnlocked' },
    }]);
  });

  it('grants the recovered memory only once for repeated events', () => {
    const cluesFound = createOpeningRoomNarrativeFlags({
      openingClockInspected: true,
      openingPhotoInspected: true,
    });
    const event = {
      type: 'memoryRecovered',
      memoryId: OPENING_ROOM_MEMORY_ID,
    } as const;

    const first = transitionOpeningRoomPuzzle(cluesFound, event);
    const repeated = transitionOpeningRoomPuzzle(
      first.state.flags,
      event,
    );

    assert.equal(first.changed, true);
    assert.deepEqual(first.effects, [{
      type: 'grantMemory',
      memoryId: OPENING_ROOM_MEMORY_ID,
    }]);
    assert.equal(repeated.changed, false);
    assert.deepEqual(repeated.effects, []);
    assert.equal(
      repeated.state.flags.openingMemoryRecovered,
      true,
    );
  });
});
