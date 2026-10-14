import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync, type SQLInputValue } from 'node:sqlite';
import { describe, it } from 'node:test';
import {
  completeOpeningRecovery,
  completeOpeningRoom,
} from '../../functions/api/player/_opening';
import type {
  PlayerDatabase,
  PlayerDatabaseResult,
  PlayerDatabaseStatement,
} from '../../functions/api/player/_database';
import { PlayerApiError, type FirebaseAccount } from '../../functions/api/player/_shared';
import { OPENING_ROOM_EVENT_SEQUENCE } from '../domain/opening/openingProgress';

const imageOrder = Array.from({ length: 12 }, (_, index) => index);
const migration = readFileSync(new URL('../../migrations/0027_opening_gateway_receipts.sql', import.meta.url), 'utf8');
type MetadataMode = 'normal' | 'omitted' | 'malformed';
type ReceiptKind = 'recovery' | 'room';

function account(uid: string): FirebaseAccount {
  return {
    uid, displayName: null, email: null, photoURL: null,
    providerId: 'test', createdAt: '2026-10-09T00:00:00.000Z', lastLoginAt: '2026-10-09T00:00:00.000Z',
  };
}

/** Hold the two actual empty SQL results, rather than fabricating prechecks. */
class PrecheckBarrier {
  arrivals = 0;
  private release: (() => void) | undefined;
  private readonly bothRead = new Promise<void>((resolve) => { this.release = resolve; });

  async wait(): Promise<void> {
    this.arrivals += 1;
    if (this.arrivals === 2) this.release?.();
    await this.bothRead;
  }
}

/** Real SQLite SQL/constraints/triggers. Only the async D1-shaped adapter and
 * transport metadata/fault modes are simulated; this is not a deployed D1 test. */
class SqlitePlayerDatabase implements PlayerDatabase {
  readonly sqlite = new DatabaseSync(':memory:');
  readonly barrier = new PrecheckBarrier();
  throwAfterNextInsert = false;
  rejectNextInsert = false;

  constructor(private readonly receiptKind: ReceiptKind, private readonly metadata: MetadataMode) {
    this.sqlite.exec(migration);
  }

  prepare(query: string): PlayerDatabaseStatement {
    let values: SQLInputValue[] = [];
    const prepared = this.sqlite.prepare(query);
    const statement: PlayerDatabaseStatement = {
      bind: (...bound: unknown[]) => {
        values = bound as SQLInputValue[];
        return statement;
      },
      first: async <T = unknown>() => {
        const row = prepared.get(...values) as T | undefined;
        const isPrecheck = this.receiptKind === 'recovery'
          ? /SELECT receipt_id, puzzle_id, puzzle_version, completed_at/.test(query)
          : /SELECT receipt_id, room_id, room_version, packet_id, page_ids_json, completed_at/.test(query);
        if (isPrecheck && row === undefined && this.barrier.arrivals < 2) await this.barrier.wait();
        return row ?? null;
      },
      all: async <T = unknown>() => ({ results: prepared.all(...values) as T[], success: true }),
      run: async <T = unknown>() => {
        if (this.rejectNextInsert && /INSERT OR IGNORE/.test(query)) {
          this.rejectNextInsert = false;
          throw new Error('synthetic failure before SQLite write');
        }
        const result = prepared.run(...values);
        if (this.throwAfterNextInsert && /INSERT OR IGNORE/.test(query)) {
          this.throwAfterNextInsert = false;
          throw new Error('synthetic response loss after SQLite write');
        }
        if (this.metadata === 'omitted') return { success: true } satisfies PlayerDatabaseResult<T>;
        if (this.metadata === 'malformed') {
          return { success: true, meta: { changes: 'unknown' } } as unknown as PlayerDatabaseResult<T>;
        }
        return { success: true, meta: { changes: Number(result.changes) } } satisfies PlayerDatabaseResult<T>;
      },
    };
    return statement;
  }

  async batch<T = unknown>(statements: PlayerDatabaseStatement[]): Promise<PlayerDatabaseResult<T>[]> {
    return Promise.all(statements.map((statement) => statement.run<T>()));
  }

  count(kind: ReceiptKind): number {
    const table = kind === 'recovery' ? 'player_opening_recovery_receipts' : 'player_opening_room_receipts';
    return Number((this.sqlite.prepare(`SELECT COUNT(*) AS count FROM ${table}`).get() as { count: number }).count);
  }
}

async function complete(kind: ReceiptKind, database: PlayerDatabase, owner: FirebaseAccount) {
  return kind === 'recovery'
    ? completeOpeningRecovery(database, owner, imageOrder)
    : completeOpeningRoom(database, owner, OPENING_ROOM_EVENT_SEQUENCE);
}

async function seedCover(database: SqlitePlayerDatabase, owner: FirebaseAccount) {
  // Use the actual server function; the room barrier does not hold cover reads.
  await completeOpeningRecovery(database, owner, imageOrder);
}

describe('opening receipts: actual SQLite concurrent insertion ownership', () => {
  for (const kind of ['recovery', 'room'] as const) {
    for (const metadata of ['normal', 'omitted', 'malformed'] as const) {
      it(`${kind}: exactly one concurrent winner, repeat false and isolated account (${metadata} metadata)`, async () => {
        const database = new SqlitePlayerDatabase(kind, metadata);
        try {
          const owner = account('concurrent-owner');
          if (kind === 'room') await seedCover(database, owner);
          const receipts = await Promise.all([
            complete(kind, database, owner), complete(kind, database, owner),
          ]);
          assert.equal(database.barrier.arrivals, 2, 'both real empty SELECTs preceded INSERT');
          assert.equal(receipts.filter((receipt) => receipt.awarded).length, 1);
          assert.equal(receipts[0]!.receiptId, receipts[1]!.receiptId);
          assert.equal(receipts[0]!.completedAt, receipts[1]!.completedAt);
          assert.equal(database.count(kind), 1);
          const replay = await complete(kind, database, owner);
          assert.equal(replay.awarded, false);
          assert.equal(replay.receiptId, receipts[0]!.receiptId);
          const other = account('other-owner');
          if (kind === 'room') await seedCover(database, other);
          const isolated = await complete(kind, database, other);
          assert.equal(isolated.awarded, true);
          assert.notEqual(isolated.receiptId, replay.receiptId);
          assert.equal(database.count(kind), 2);
        } finally { database.sqlite.close(); }
      });
    }
  }

  it('room requires the same account cover receipt and rejects incomplete events', async () => {
    const database = new SqlitePlayerDatabase('room', 'normal');
    try {
      await seedCover(database, account('covered-owner'));
      await assert.rejects(completeOpeningRoom(database, account('uncovered-owner'), OPENING_ROOM_EVENT_SEQUENCE),
        (error: unknown) => error instanceof PlayerApiError && error.status === 409 && error.code === 'opening_recovery_required');
      await assert.rejects(completeOpeningRoom(database, account('covered-owner'), ['room_entered']),
        (error: unknown) => error instanceof PlayerApiError && error.status === 422);
      assert.equal(database.count('room'), 0);
    } finally { database.sqlite.close(); }
  });

  for (const kind of ['recovery', 'room'] as const) {
    it(`${kind}: a lost post-write response throws, stored receipt retries false`, async () => {
      const database = new SqlitePlayerDatabase(kind, 'omitted');
      try {
        const owner = account('lost-response-owner');
        if (kind === 'room') await seedCover(database, owner);
        // Release the concurrency-only barrier for this intentionally single call.
        await Promise.all([database.barrier.wait(), database.barrier.wait()]);
        database.throwAfterNextInsert = true;
        await assert.rejects(complete(kind, database, owner), /response loss after SQLite write/);
        assert.equal(database.count(kind), 1);
        assert.equal((await complete(kind, database, owner)).awarded, false);
      } finally { database.sqlite.close(); }
    });

    it(`${kind}: failed write cannot claim an award, subsequent legitimate insertion can`, async () => {
      const database = new SqlitePlayerDatabase(kind, 'normal');
      try {
        const owner = account('failed-write-owner');
        if (kind === 'room') await seedCover(database, owner);
        await Promise.all([database.barrier.wait(), database.barrier.wait()]);
        database.rejectNextInsert = true;
        await assert.rejects(complete(kind, database, owner), /failure before SQLite write/);
        assert.equal(database.count(kind), 0);
        assert.equal((await complete(kind, database, owner)).awarded, true);
        assert.equal((await complete(kind, database, owner)).awarded, false);
      } finally { database.sqlite.close(); }
    });

    it(`${kind}: SQLite ignoring the insertion without a stored receipt returns 503`, async () => {
      const database = new SqlitePlayerDatabase(kind, 'normal');
      try {
        const owner = account('ignored-write-owner');
        if (kind === 'room') await seedCover(database, owner);
        await Promise.all([database.barrier.wait(), database.barrier.wait()]);
        const table = kind === 'recovery' ? 'player_opening_recovery_receipts' : 'player_opening_room_receipts';
        database.sqlite.exec(`CREATE TRIGGER ignore_test_insert BEFORE INSERT ON ${table} BEGIN SELECT RAISE(IGNORE); END;`);
        await assert.rejects(complete(kind, database, owner),
          (error: unknown) => error instanceof PlayerApiError && error.status === 503 && error.code === 'receipt_unavailable');
        assert.equal(database.count(kind), 0);
      } finally { database.sqlite.close(); }
    });
  }
});
