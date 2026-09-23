import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  createOpeningRoomNarrativeFlags,
  canUnlockOpeningDoor,
  deriveOpeningRoomPuzzleStage,
  transitionOpeningRoomPuzzle,
  type OpeningRoomNarrativeFlags,
} from '../features/gameplay/systems/puzzleSystem';
import {
  OPENING_CLOCK_INTERACTION,
  OPENING_PHOTO_INTERACTION,
  OPENING_DOOR_INTERACTION,
  OPENING_ROOM_INTERACTIONS,
} from '../features/gameplay/data/openingRoom.interactions';
import { OPENING_ROOM_MEMORY_ID } from '../features/gameplay/data/openingRoom.puzzles';

describe('Story-Driven Task System — Sector 11 Mission Progression', () => {
  it('enforces multi-step exploration rather than immediate door opening', () => {
    const initialFlags = createOpeningRoomNarrativeFlags();

    // Step 1: Inspecting the door while unpowered reports locked status
    const doorInspectInitial = OPENING_DOOR_INTERACTION.onInteract({ flags: initialFlags });
    assert.equal(doorInspectInitial.outcome, 'locked');
    assert.match(doorInspectInitial.message, /الباب مقفل/);
    assert.equal(canUnlockOpeningDoor(initialFlags), false);
    assert.equal(deriveOpeningRoomPuzzleStage(initialFlags), 'locked');
  });

  it('progresses through contextual clues in any order before unlocking the exit', () => {
    let flags: OpeningRoomNarrativeFlags = createOpeningRoomNarrativeFlags();

    // Step 2a: Discover first environmental trace (stopped clock at 11:11)
    const clockInspect = OPENING_CLOCK_INTERACTION.onInteract({ flags });
    assert.equal(clockInspect.outcome, 'narration');
    assert.match(clockInspect.message, /11:11/);

    const t1 = transitionOpeningRoomPuzzle(flags, { type: 'clockInspected' });
    flags = t1.state.flags;
    assert.equal(t1.state.stage, 'clueFound');
    assert.equal(canUnlockOpeningDoor(flags), false);

    // Step 2b: Discover second environmental trace (torn photo with memory anchor)
    const photoInspect = OPENING_PHOTO_INTERACTION.onInteract({ flags });
    assert.equal(photoInspect.outcome, 'memory');
    assert.match(photoInspect.message, /صورة ممزقة/);

    const t2 = transitionOpeningRoomPuzzle(flags, { type: 'photoInspected' });
    flags = t2.state.flags;

    // Transition memory recovered and puzzle solved
    const t3 = transitionOpeningRoomPuzzle(flags, {
      type: 'memoryRecovered',
      memoryId: OPENING_ROOM_MEMORY_ID,
    });
    flags = t3.state.flags;
    assert.equal(t3.state.stage, 'memoryRecovered');

    const t4 = transitionOpeningRoomPuzzle(flags, { type: 'puzzleSolved' });
    flags = t4.state.flags;
    assert.equal(t4.state.stage, 'solved');
    assert.equal(canUnlockOpeningDoor(flags), true);

    // Step 3: Now the exit responds to hydraulic unlocking
    const doorInspectFinal = OPENING_DOOR_INTERACTION.onInteract({ flags });
    assert.equal(doorInspectFinal.outcome, 'unlocked');
    assert.match(doorInspectFinal.message, /استجاب القفل/);

    const t5 = transitionOpeningRoomPuzzle(flags, { type: 'doorUnlocked' });
    flags = t5.state.flags;
    assert.equal(t5.state.stage, 'exitUnlocked');
  });

  it('validates that all interactive entities have defined spatial positions and collision margins', () => {
    for (const interaction of OPENING_ROOM_INTERACTIONS) {
      assert.ok(interaction.position);
      assert.equal(typeof interaction.position.x, 'number');
      assert.equal(typeof interaction.position.y, 'number');
      assert.equal(typeof interaction.position.z, 'number');
      assert.ok(interaction.interactionDistance > 1.0);
      assert.ok(interaction.interactionDistance < 3.0);
    }
  });
});
