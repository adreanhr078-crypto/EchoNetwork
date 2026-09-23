import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  SECTOR_11_STORY_TASKS,
  INITIAL_SECTOR_COMBAT_STATE,
  getActiveSectorTask,
  calculateSector11Progress,
  type SectorCombatState,
} from '../features/gameplay/domain/sectorStoryTasks';
import {
  createOpeningRoomNarrativeFlags,
  type OpeningRoomNarrativeFlags,
} from '../features/gameplay/systems/puzzleSystem';

describe('Sector 11 Story-Driven Tasks & Containment Encounter', () => {
  it('defines the 6 canonical Sector 11 stages with complete bilingual copy and threat ratings', () => {
    assert.equal(SECTOR_11_STORY_TASKS.length, 6);

    const expectedIds = [
      '11.1-wake-stasis',
      '11.2-digital-clock',
      '11.3-torn-photo',
      '11.4-substation-reroute',
      '11.5-containment-breach',
      '11.6-quarantine-escape',
    ];
    assert.deepEqual(
      SECTOR_11_STORY_TASKS.map((t) => t.id),
      expectedIds,
    );

    for (const task of SECTOR_11_STORY_TASKS) {
      assert.equal(task.sector, 11);
      assert.ok(task.stageCode.startsWith('SEC11-STG'));
      assert.ok(task.titleAr.length > 3);
      assert.ok(task.titleEn.length > 3);
      assert.ok(task.objectiveAr.length > 10);
      assert.ok(task.objectiveEn.length > 10);
      assert.ok(task.loreContextAr.length > 10);
      assert.ok(task.loreContextEn.length > 10);
      assert.ok(
        ['exploration', 'forensic', 'technical', 'survival_combat', 'escape'].includes(
          task.category,
        ),
      );
      assert.ok(
        ['safe', 'caution', 'critical', 'extreme', 'resolved'].includes(
          task.threatLevel,
        ),
      );
    }
  });

  it('progresses chronologically from Stasis Awakening to Quarantine Escape', () => {
    let flags: OpeningRoomNarrativeFlags = createOpeningRoomNarrativeFlags();
    let combat: SectorCombatState = { ...INITIAL_SECTOR_COMBAT_STATE };

    // Stage 1: Initial state -> 11.1 active
    assert.equal(calculateSector11Progress(flags, combat), 0);
    let activeTask = getActiveSectorTask(flags, combat);
    assert.equal(activeTask.id, '11.1-wake-stasis');
    assert.equal(activeTask.threatLevel, 'safe');
    assert.equal(activeTask.requiredCompanionEmotion, 'observing');

    // Awaken & enter room
    flags = { ...flags, openingRoomEntered: true };
    assert.equal(calculateSector11Progress(flags, combat), 17);
    activeTask = getActiveSectorTask(flags, combat);
    assert.equal(activeTask.id, '11.2-digital-clock');
    assert.equal(activeTask.threatLevel, 'caution');
    assert.equal(activeTask.requiredCompanionEmotion, 'scanning');

    // Inspect clock
    flags = { ...flags, openingClockInspected: true };
    assert.equal(calculateSector11Progress(flags, combat), 33);
    activeTask = getActiveSectorTask(flags, combat);
    assert.equal(activeTask.id, '11.3-torn-photo');

    // Inspect photo & recover memory
    flags = {
      ...flags,
      openingPhotoInspected: true,
      openingMemoryRecovered: true,
    };
    assert.equal(calculateSector11Progress(flags, combat), 50);
    activeTask = getActiveSectorTask(flags, combat);
    assert.equal(activeTask.id, '11.4-substation-reroute');
    assert.equal(activeTask.threatLevel, 'critical');
    assert.equal(activeTask.requiredCompanionEmotion, 'alert');

    // Emergency power reroute / breach initiated
    combat = {
      ...combat,
      breachTriggered: true,
      bossActive: true,
      substationOverridden: true,
    };
    assert.equal(calculateSector11Progress(flags, combat), 67);
    activeTask = getActiveSectorTask(flags, combat);
    assert.equal(activeTask.id, '11.5-containment-breach');
    assert.equal(activeTask.threatLevel, 'extreme');
    assert.equal(activeTask.category, 'survival_combat');
    assert.equal(activeTask.requiredCompanionEmotion, 'distressed');

    // Defeat aberrant specimen EX-004
    combat = {
      ...combat,
      bossActive: false,
      monsterHp: 0,
      monsterDefeated: true,
    };
    assert.equal(calculateSector11Progress(flags, combat), 83);
    activeTask = getActiveSectorTask(flags, combat);
    assert.equal(activeTask.id, '11.6-quarantine-escape');
    assert.equal(activeTask.threatLevel, 'resolved');
    assert.equal(activeTask.category, 'escape');
    assert.equal(activeTask.requiredCompanionEmotion, 'celebrating');

    // Decompress and complete room
    flags = {
      ...flags,
      openingDoorUnlocked: true,
      openingRoomCompleted: true,
    };
    assert.equal(calculateSector11Progress(flags, combat), 100);
  });

  it('maps companion emotional states synchronously to combat threat escalation', () => {
    const flags: OpeningRoomNarrativeFlags = {
      ...createOpeningRoomNarrativeFlags(),
      openingRoomEntered: true,
      openingClockInspected: true,
      openingPhotoInspected: true,
      openingMemoryRecovered: true,
    };

    // Pre-breach: Alert companion during technical override
    const preBreachCombat = { ...INITIAL_SECTOR_COMBAT_STATE };
    const taskPreBreach = getActiveSectorTask(flags, preBreachCombat);
    assert.equal(taskPreBreach.requiredCompanionEmotion, 'alert');

    // Mid-combat: Distressed companion during entity assault
    const midCombat = {
      ...INITIAL_SECTOR_COMBAT_STATE,
      breachTriggered: true,
      bossActive: true,
      monsterHp: 500,
    };
    const taskMidCombat = getActiveSectorTask(flags, midCombat);
    assert.equal(taskMidCombat.requiredCompanionEmotion, 'distressed');

    // Post-combat: Celebrating companion during escape
    const postCombat = {
      ...midCombat,
      bossActive: false,
      monsterHp: 0,
      monsterDefeated: true,
    };
    const taskPostCombat = getActiveSectorTask(flags, postCombat);
    assert.equal(taskPostCombat.requiredCompanionEmotion, 'celebrating');
  });
});
