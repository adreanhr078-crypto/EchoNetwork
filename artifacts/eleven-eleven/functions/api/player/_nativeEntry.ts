import { OPENING_COVER_PUZZLE_ID } from '../../../src/domain/opening/openingProgress';
import type { PlayerDatabase } from './_database';
import { PlayerApiError } from './_shared';

const FIVE_MINUTES = 300_000;
const BASE64URL_256 = /^[A-Za-z0-9_-]{43}$/;
const VERIFIER = /^[A-Za-z0-9._~-]{43,128}$/;

function invalidGrant(): never {
  // Same result for nonexistent, wrong device, used and expired grants.
  throw new PlayerApiError(400, 'native_entry_invalid', 'Open a new connection from the game and try again.');
}

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return invalidGrant();
  return value as Record<string, unknown>;
}

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export async function nativeEntryDigest(value: string): Promise<string> {
  return base64url(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))));
}

export async function issueNativeEntry(database: PlayerDatabase, uid: string, body: unknown, now = Date.now()) {
  const challenge = object(body).challenge;
  if (typeof challenge !== 'string' || !BASE64URL_256.test(challenge)) return invalidGrant();
  const code = base64url(crypto.getRandomValues(new Uint8Array(32)));
  const hash = await nativeEntryDigest(code);
  // At most five unexpired rows per account; inactive accounts retain at most
  // their last five expired rows. Never prune authoritative cover receipts.
  await database.prepare('DELETE FROM player_native_entry_grants WHERE user_id=? AND expires_at<=?')
    .bind(uid, now).run();
  // The receipt prerequisite and per-account issuance bound live in the same
  // atomic statement. A caller cannot substitute a client-authored receipt.
  const grant = await database.prepare(`
    INSERT INTO player_native_entry_grants
      (code_hash,user_id,receipt_id,challenge,created_at,expires_at)
    SELECT ?,r.user_id,r.receipt_id,?,?,? FROM player_opening_recovery_receipts r
    WHERE r.user_id=? AND r.puzzle_id=? AND r.puzzle_version=1
      AND (SELECT COUNT(*) FROM player_native_entry_grants WHERE user_id=? AND created_at>?)<5
    RETURNING expires_at
  `).bind(hash, challenge, now, now + FIVE_MINUTES, uid, OPENING_COVER_PUZZLE_ID, uid, now - FIVE_MINUTES)
    .first<{ expires_at: number }>();
  if (!grant) throw new PlayerApiError(409, 'native_entry_unavailable', 'Complete the cover first, or wait before opening another connection.');
  return { code, expiresAt: grant.expires_at, scope: 'native-chapter-entry' as const };
}

export async function exchangeNativeEntry(database: PlayerDatabase, body: unknown, now = Date.now()) {
  const input = object(body);
  if (typeof input.code !== 'string' || !BASE64URL_256.test(input.code)
    || typeof input.verifier !== 'string' || !VERIFIER.test(input.verifier)) return invalidGrant();
  const [hash, challenge] = await Promise.all([nativeEntryDigest(input.code), nativeEntryDigest(input.verifier)]);
  const row = await database.prepare(`
    UPDATE player_native_entry_grants SET consumed_at=?
    WHERE code_hash=? AND challenge=? AND consumed_at IS NULL AND expires_at>?
      AND EXISTS (SELECT 1 FROM player_opening_recovery_receipts r
        WHERE r.user_id=player_native_entry_grants.user_id
          AND r.receipt_id=player_native_entry_grants.receipt_id
          AND r.puzzle_id=? AND r.puzzle_version=1)
    RETURNING receipt_id
  `).bind(now, hash, challenge, now, OPENING_COVER_PUZZLE_ID).first<{ receipt_id: string }>();
  if (!row) return invalidGrant();
  // Deliberately no uid, account token, currency, reward or entitlement grant.
  return { scope: 'native-chapter-entry' as const, coverReceiptId: row.receipt_id, entryConfirmed: true as const };
}
