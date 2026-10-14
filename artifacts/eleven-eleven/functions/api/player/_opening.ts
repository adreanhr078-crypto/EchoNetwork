import {
  OPENING_COVER_PUZZLE_ID,
  OPENING_MANHWA_PACKET_ID,
  OPENING_MANHWA_PACKET_PAGE_IDS,
  OPENING_ROOM_EVENT_SEQUENCE,
  OPENING_ROOM_ID,
  isOpeningRoomEventId,
  type OpeningRoomEventId,
} from '../../../src/domain/opening/openingProgress';
import type {
  PlayerDatabase,
} from './_database';
import {
  PlayerApiError,
  type FirebaseAccount,
} from './_shared';

const OPENING_VERSION = 1;

export interface OpeningRecoveryReceipt {
  receiptId: string;
  puzzleId: typeof OPENING_COVER_PUZZLE_ID;
  puzzleVersion: number;
  awarded: boolean;
  completedAt: string;
}

export interface OpeningRoomReceipt {
  receiptId: string;
  roomId: typeof OPENING_ROOM_ID;
  roomVersion: number;
  packetId: typeof OPENING_MANHWA_PACKET_ID;
  pageIds: readonly string[];
  awarded: boolean;
  completedAt: string;
}

interface RecoveryRow {
  receipt_id: string;
  puzzle_id: string;
  puzzle_version: number | string;
  completed_at: string;
}

interface RoomRow {
  receipt_id: string;
  room_id: string;
  room_version: number | string;
  packet_id: string;
  page_ids_json: string;
  completed_at: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function readRecoveryRow(row: RecoveryRow): OpeningRecoveryReceipt {
  return {
    receiptId: row.receipt_id,
    puzzleId: OPENING_COVER_PUZZLE_ID,
    puzzleVersion: Number(row.puzzle_version),
    awarded: false,
    completedAt: row.completed_at,
  };
}

function readRoomRow(row: RoomRow): OpeningRoomReceipt {
  let pageIds: string[] = [];
  try {
    const parsed: unknown = JSON.parse(row.page_ids_json);
    if (Array.isArray(parsed)) {
      pageIds = parsed.filter((pageId): pageId is string => (
        typeof pageId === 'string'
      ));
    }
  } catch {
    pageIds = [];
  }
  return {
    receiptId: row.receipt_id,
    roomId: OPENING_ROOM_ID,
    roomVersion: Number(row.room_version),
    packetId: OPENING_MANHWA_PACKET_ID,
    pageIds,
    awarded: false,
    completedAt: row.completed_at,
  };
}

function parseCorrectImageOrder(value: unknown): number[] {
  if (!Array.isArray(value) || (value.length !== 12 && value.length !== 16)) {
    throw new PlayerApiError(
      400,
      'invalid_opening_solution',
      'The opening image reconstruction is invalid.',
    );
  }
  const order = value.map((piece) => (
    typeof piece === 'number' && Number.isInteger(piece) ? piece : -1
  ));
  const expected = Array.from({ length: order.length }, (_, index) => index);
  if (
    order.some((piece, index) => piece !== expected[index])
    || new Set(order).size !== order.length
  ) {
    throw new PlayerApiError(
      422,
      'opening_solution_not_verified',
      'The reconstructed cover is not aligned yet.',
    );
  }
  return order;
}

export function parseOpeningRecoveryBody(value: unknown): { imageOrder: number[] } {
  if (!isRecord(value) || Object.keys(value).some((key) => key !== 'imageOrder')) {
    throw new PlayerApiError(400, 'invalid_request', 'Opening recovery is invalid.');
  }
  return { imageOrder: parseCorrectImageOrder(value.imageOrder) };
}

export function parseOpeningRoomBody(value: unknown): {
  eventIds: OpeningRoomEventId[];
} {
  if (!isRecord(value) || Object.keys(value).some((key) => key !== 'eventIds')) {
    throw new PlayerApiError(400, 'invalid_request', 'Opening room completion is invalid.');
  }
  const eventIds = value.eventIds;
  if (
    !Array.isArray(eventIds)
    || eventIds.length !== OPENING_ROOM_EVENT_SEQUENCE.length
    || !eventIds.every(isOpeningRoomEventId)
    || eventIds.some((eventId, index) => (
      eventId !== OPENING_ROOM_EVENT_SEQUENCE[index]
    ))
  ) {
    throw new PlayerApiError(
      422,
      'opening_room_requirements_missing',
      'The opening room sequence is not complete.',
    );
  }
  return { eventIds };
}

export async function completeOpeningRecovery(
  database: PlayerDatabase,
  account: FirebaseAccount,
  imageOrder: readonly number[],
): Promise<OpeningRecoveryReceipt> {
  parseCorrectImageOrder(imageOrder);
  const existing = await database.prepare(`
    SELECT receipt_id, puzzle_id, puzzle_version, completed_at
    FROM player_opening_recovery_receipts
    WHERE user_id = ? AND puzzle_id = ?
  `).bind(account.uid, OPENING_COVER_PUZZLE_ID).first<RecoveryRow>();
  if (existing) return readRecoveryRow(existing);

  const completedAt = new Date().toISOString();
  const attemptedReceiptId = crypto.randomUUID();
  await database.prepare(`
    INSERT OR IGNORE INTO player_opening_recovery_receipts (
      user_id, receipt_id, puzzle_id, puzzle_version, completed_at
    ) VALUES (?, ?, ?, ?, ?)
  `).bind(
    account.uid,
    attemptedReceiptId,
    OPENING_COVER_PUZZLE_ID,
    OPENING_VERSION,
    completedAt,
  ).run();
  const receipt = await database.prepare(`
    SELECT receipt_id, puzzle_id, puzzle_version, completed_at
    FROM player_opening_recovery_receipts
    WHERE user_id = ? AND puzzle_id = ?
  `).bind(account.uid, OPENING_COVER_PUZZLE_ID).first<RecoveryRow>();
  if (!receipt) {
    throw new PlayerApiError(503, 'receipt_unavailable', 'Opening receipt could not be stored.');
  }
  return {
    ...readRecoveryRow(receipt),
    // INSERT OR IGNORE may lose to another request after the empty precheck.
    // The stored server-generated ID proves ownership even without run metadata.
    awarded: receipt.receipt_id === attemptedReceiptId,
  };
}

export async function completeOpeningRoom(
  database: PlayerDatabase,
  account: FirebaseAccount,
  eventIds: readonly string[],
): Promise<OpeningRoomReceipt> {
  parseOpeningRoomBody({ eventIds });
  const recovery = await database.prepare(`
    SELECT receipt_id
    FROM player_opening_recovery_receipts
    WHERE user_id = ? AND puzzle_id = ?
  `).bind(account.uid, OPENING_COVER_PUZZLE_ID).first<{ receipt_id: string }>();
  if (!recovery) {
    throw new PlayerApiError(
      409,
      'opening_recovery_required',
      'Complete the opening cover reconstruction first.',
    );
  }

  const existing = await database.prepare(`
    SELECT receipt_id, room_id, room_version, packet_id, page_ids_json, completed_at
    FROM player_opening_room_receipts
    WHERE user_id = ? AND room_id = ?
  `).bind(account.uid, OPENING_ROOM_ID).first<RoomRow>();
  if (existing) return readRoomRow(existing);

  const completedAt = new Date().toISOString();
  const attemptedReceiptId = crypto.randomUUID();
  await database.prepare(`
    INSERT OR IGNORE INTO player_opening_room_receipts (
      user_id, receipt_id, room_id, room_version, packet_id, page_ids_json, completed_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
  `).bind(
    account.uid,
    attemptedReceiptId,
    OPENING_ROOM_ID,
    OPENING_VERSION,
    OPENING_MANHWA_PACKET_ID,
    JSON.stringify(OPENING_MANHWA_PACKET_PAGE_IDS),
    completedAt,
  ).run();
  const receipt = await database.prepare(`
    SELECT receipt_id, room_id, room_version, packet_id, page_ids_json, completed_at
    FROM player_opening_room_receipts
    WHERE user_id = ? AND room_id = ?
  `).bind(account.uid, OPENING_ROOM_ID).first<RoomRow>();
  if (!receipt) {
    throw new PlayerApiError(503, 'receipt_unavailable', 'Room receipt could not be stored.');
  }
  return {
    ...readRoomRow(receipt),
    awarded: receipt.receipt_id === attemptedReceiptId,
  };
}
