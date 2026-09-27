import type { AuthoritativeStoryState } from '../story/storyState';
import type { OpeningRecoveryApiResponse } from '../../infrastructure/player-progression/playerProgressionApi';
import { OPENING_COVER_PUZZLE_ID, OPENING_ROOM_EVENT_SEQUENCE, isOpeningRoomEventId, type OpeningRoomEventId } from './openingProgress';

/** Presentation routing only. The server remains the owner of each receipt. */
export function openingResumeDestination(
  storyState: Pick<AuthoritativeStoryState, 'openingCoverPuzzleCompleted' | 'openingRoomCompleted'> | null,
): 'cover' | 'room' | 'completed' {
  if (storyState?.openingCoverPuzzleCompleted !== true) return 'cover';
  return storyState.openingRoomCompleted === true ? 'completed' : 'room';
}

/** A successful POST must identify the same cover that was played. */
export function hasConfirmedOpeningCoverReceipt(
  response: OpeningRecoveryApiResponse,
): boolean {
  const { receipt, storyState } = response;
  return storyState.openingCoverPuzzleCompleted === true
    && receipt.puzzleId === OPENING_COVER_PUZZLE_ID
    && typeof receipt.receiptId === 'string'
    && receipt.receiptId.trim().length > 0
    && Number.isInteger(receipt.puzzleVersion)
    && receipt.puzzleVersion > 0
    && typeof receipt.completedAt === 'string'
    && Number.isFinite(Date.parse(receipt.completedAt));
}

/** Reject a claimed room chronology that differs from the played event order. */
export function advanceOpeningRoomTrace(
  trace: readonly OpeningRoomEventId[],
  milestone: unknown,
): readonly OpeningRoomEventId[] | null {
  if (!isOpeningRoomEventId(milestone)) return trace;
  if (trace.includes(milestone)) return trace;
  if (OPENING_ROOM_EVENT_SEQUENCE[trace.length] !== milestone) return null;
  return [...trace, milestone];
}
