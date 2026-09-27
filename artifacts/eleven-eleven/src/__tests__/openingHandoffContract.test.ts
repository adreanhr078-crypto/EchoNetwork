import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { advanceOpeningRoomTrace, hasConfirmedOpeningCoverReceipt, openingResumeDestination } from '../domain/opening/openingHandoff';
import { OPENING_COVER_PUZZLE_ID, OPENING_ROOM_EVENT_SEQUENCE, type OpeningRoomEventId } from '../domain/opening/openingProgress';
import type { OpeningRecoveryApiResponse } from '../infrastructure/player-progression/playerProgressionApi';

const response: OpeningRecoveryApiResponse = {
  storyState: {
    canonEventReceipts: [],
    completedChapterIds: [],
    discoveredMemoryFragmentIds: [],
    openingCoverPuzzleCompleted: true,
    openingRoomCompleted: false,
    syncedAt: '2026-09-27T00:00:00.000Z',
  },
  receipt: {
    receiptId: 'server-receipt-1',
    puzzleId: OPENING_COVER_PUZZLE_ID,
    puzzleVersion: 1,
    awarded: true,
    completedAt: '2026-09-27T00:00:00.000Z',
  },
};

describe('opening handoff authority', () => {
  it('requires the server cover receipt and accepts an idempotent existing receipt', () => {
    assert.equal(hasConfirmedOpeningCoverReceipt(response), true);
    assert.equal(hasConfirmedOpeningCoverReceipt({
      ...response,
      receipt: { ...response.receipt, awarded: false },
    }), true);
    assert.equal(hasConfirmedOpeningCoverReceipt({
      ...response,
      receipt: { ...response.receipt, puzzleId: 'unrelated-puzzle' },
    }), false);
    assert.equal(hasConfirmedOpeningCoverReceipt({
      ...response,
      storyState: { ...response.storyState, openingCoverPuzzleCompleted: false },
    }), false);
  });

  it('resumes from verified server state without asking to submit the cover again', () => {
    assert.equal(openingResumeDestination(null), 'cover');
    assert.equal(openingResumeDestination({
      openingCoverPuzzleCompleted: false,
      openingRoomCompleted: true,
    }), 'cover');
    assert.equal(openingResumeDestination(response.storyState), 'room');
    assert.equal(openingResumeDestination({
      openingCoverPuzzleCompleted: true,
      openingRoomCompleted: true,
    }), 'completed');
  });

  it('accepts only played room events in canonical order, while ignoring presentation cues', () => {
    let trace: readonly OpeningRoomEventId[] = [];
    for (const eventId of OPENING_ROOM_EVENT_SEQUENCE) {
      assert.equal(advanceOpeningRoomTrace(trace, 'gate_revealed'), trace);
      const next = advanceOpeningRoomTrace(trace, eventId);
      assert.ok(next);
      trace = next;
      assert.equal(advanceOpeningRoomTrace(trace, eventId), trace);
    }
    assert.deepEqual(trace, OPENING_ROOM_EVENT_SEQUENCE);
    assert.equal(advanceOpeningRoomTrace([], 'photo_inspected'), null);
    assert.equal(advanceOpeningRoomTrace(['room_entered'], 'puzzle_solved'), null);
  });
});
