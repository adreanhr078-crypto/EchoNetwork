import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
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
  findEchoAnimationClip,
  resolveEchoAnimationState,
} from '../features/gameplay/systems/echoAnimationSystem';
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
