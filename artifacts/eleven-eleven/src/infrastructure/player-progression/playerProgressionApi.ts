import {
  AuthSessionError,
  getCurrentAuthSession,
} from '../../features/auth/authService';
import { playerApiRoot } from '../player-api/apiRoot';
import {
  fetchPlayerRequest,
  PlayerTransportError,
} from '../player-api/playerRequest';
import type {
  LeaderboardPlayer,
} from '../../domain/player-progression/playerProgression';
import type {
  PlayerAvatarId,
  PlayerProfile,
} from '../../domain/player-profile/playerProfile';
import type {
  AuthoritativeStoryState,
} from '../../domain/story/storyState';
import type {
  CollectionSnapshot,
} from '../../domain/collection/collectionContracts';
import type {
  StoryPuzzleDraft,
  StoryPuzzleRewardReceipt,
  StoryPuzzleSnapshot,
} from '../../domain/story-puzzles/storyPuzzleContracts';
import type {
  LiveChallengesSnapshot,
  LiveCompletionReceipt,
} from '../../domain/live-challenges/liveChallengeContracts';
import type {
  PlayerTelemetryEvent,
} from '../../domain/telemetry/telemetryContracts';
import type {
  OpeningRoomEventId,
} from '../../domain/opening/openingProgress';

export interface LeaderboardApiSnapshot {
  entries: LeaderboardPlayer[];
  currentPlayer: LeaderboardPlayer;
  totalPlayers: number;
  generatedAt: string;
}

interface LeaderboardApiResponse {
  leaderboard: LeaderboardApiSnapshot;
  rankingMetric: 'total_xp';
}

export interface XpClaimApiResponse {
  reward: {
    sourceType: 'manhwa';
    sourceId: string;
    rewardKey: string;
    awarded: boolean;
    xpGranted: number;
  };
  progression: LeaderboardPlayer;
}

export function claimManhwaChapterXpReward(
  chapterId: string,
  finalPageNumber: number,
): Promise<XpClaimApiResponse> {
  return authorizedRequest<XpClaimApiResponse>('/xp/claim', {
    method: 'POST',
    body: JSON.stringify({
      sourceType: 'manhwa',
      sourceId: chapterId,
      proof: { finalPageNumber },
    }),
  });
}

interface PlayerProfileApiResponse {
  profile: PlayerProfile;
}

interface StoryStateApiResponse {
  storyState: AuthoritativeStoryState;
}

interface StoryCheckpointApiResponse extends StoryStateApiResponse {
  claimedEventIds: string[];
}

export interface OpeningRecoveryApiResponse extends StoryStateApiResponse {
  receipt: {
    receiptId: string;
    puzzleId: string;
    puzzleVersion: number;
    awarded: boolean;
    completedAt: string;
  };
}

export interface OpeningRoomApiResponse extends StoryStateApiResponse {
  receipt: {
    receiptId: string;
    roomId: string;
    roomVersion: number;
    packetId: string;
    pageIds: string[];
    awarded: boolean;
    completedAt: string;
  };
}

interface ApiErrorBody {
  error?: unknown;
  code?: unknown;
}

export class PlayerProgressionApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly endpoint: string | null = null,
  ) {
    super(message);
    this.name = 'PlayerProgressionApiError';
  }
}

function apiRoot(): string {
  const runtimeEnv = (import.meta as ImportMeta & {
    env?: ImportMetaEnv;
  }).env;
  const configured = runtimeEnv?.VITE_PLAYER_API_URL?.trim();
  return playerApiRoot(configured);
}

function invalidResponse(endpoint: string): PlayerProgressionApiError {
  return new PlayerProgressionApiError(
    502,
    'invalid_response',
    'Player service returned an invalid response.',
    endpoint,
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

async function parseResponse<T>(
  response: Response,
  endpoint: string,
): Promise<T> {
  let payload: unknown = null;
  let parsed = false;
  try {
    payload = await response.json();
    parsed = true;
  } catch {
    // A stable API error is produced below.
  }
  const payloadRecord: ApiErrorBody & Partial<T> = isRecord(payload)
    ? payload as ApiErrorBody & Partial<T>
    : {};
  if (!response.ok) {
    throw new PlayerProgressionApiError(
      response.status,
      typeof payloadRecord.code === 'string' ? payloadRecord.code : 'request_failed',
      typeof payloadRecord.error === 'string'
        ? payloadRecord.error
        : 'Player progression request failed.',
      endpoint,
    );
  }
  const contentType = response.headers.get('content-type') ?? '';
  if (!parsed) throw invalidResponse(endpoint);
  if (contentType && !contentType.toLowerCase().includes('json')) {
    throw invalidResponse(endpoint);
  }
  if (!isRecord(payload)) throw invalidResponse(endpoint);
  return payload as T;
}

async function authorizedRequest<T>(
  path: string,
  init?: RequestInit,
  expectedUid?: string,
): Promise<T> {
  let token: string;
  try {
    const session = await getCurrentAuthSession(expectedUid);
    token = session.token;
  } catch (error) {
    const authError = error instanceof AuthSessionError
      ? error
      : new AuthSessionError('token_failed', 'Authentication failed.');
    const status = authError.code === 'auth_timeout'
      || authError.code === 'token_timeout'
      ? 504
      : authError.code === 'uid_changed' ? 409 : 401;
    throw new PlayerProgressionApiError(
      status,
      authError.code,
      authError.message,
      path,
    );
  }
  try {
    const response = await fetchPlayerRequest(`${apiRoot()}${path}`, {
      ...init,
      headers: {
        Authorization: `Bearer ${token}`,
        ...(init?.body ? { 'Content-Type': 'application/json' } : {}),
        ...init?.headers,
      },
    });
    return parseResponse<T>(response, path);
  } catch (error) {
    if (error instanceof PlayerProgressionApiError) throw error;
    if (error instanceof PlayerTransportError) {
      throw new PlayerProgressionApiError(
        error.code === 'request_timeout' ? 504 : 503,
        error.code,
        error.message,
        path,
      );
    }
    throw new PlayerProgressionApiError(
      503,
      'network_failure',
      'Player service could not be reached.',
      path,
    );
  }
}

export async function fetchGlobalLeaderboard(
  limit = 25,
  expectedUid?: string,
): Promise<LeaderboardApiSnapshot> {
  const response = await authorizedRequest<LeaderboardApiResponse>(
    `/leaderboard?limit=${encodeURIComponent(limit)}`,
    undefined,
    expectedUid,
  );
  if (!isRecord(response.leaderboard)) {
    throw invalidResponse('/leaderboard');
  }
  return response.leaderboard;
}

export async function fetchPlayerProfile(
  expectedUid?: string,
): Promise<PlayerProfile> {
  const response = await authorizedRequest<PlayerProfileApiResponse>(
    '/profile',
    undefined,
    expectedUid,
  );
  if (!isRecord(response.profile) || typeof response.profile.uid !== 'string') {
    throw invalidResponse('/profile');
  }
  if (expectedUid && response.profile.uid !== expectedUid) {
    throw new PlayerProgressionApiError(
      409,
      'uid_mismatch',
      'Player profile belongs to a different account.',
      '/profile',
    );
  }
  return response.profile;
}

export function updatePlayerProfile(input: {
  username: string;
  bio: string;
  avatarId: PlayerAvatarId;
  featuredAchievementIds?: string[];
}): Promise<PlayerProfile> {
  return authorizedRequest<PlayerProfileApiResponse>('/profile', {
    method: 'PUT',
    body: JSON.stringify(input),
  }).then((response) => response.profile);
}

export async function fetchAuthoritativeStoryState(
  expectedUid?: string,
): Promise<AuthoritativeStoryState> {
  const response = await authorizedRequest<StoryStateApiResponse>(
    '/story-state',
    undefined,
    expectedUid,
  );
  if (!isRecord(response.storyState)) throw invalidResponse('/story-state');
  return response.storyState;
}

/**
 * The client reports only a Manhwa reader coordinate. The server owns Canon
 * event lookup, prerequisite checks, receipts, and every resulting state.
 */
export function claimManhwaStoryCheckpoint(input: {
  chapterId: string;
  pageId: string;
  globalPageNumber: number;
}): Promise<StoryCheckpointApiResponse> {
  return authorizedRequest<StoryCheckpointApiResponse>(
    '/story-state/checkpoint',
    {
      method: 'POST',
      body: JSON.stringify(input),
    },
  );
}

interface StoryPuzzleStateResponse {
  puzzleState: StoryPuzzleSnapshot;
}

interface StoryPuzzleRewardResponse {
  reward: StoryPuzzleRewardReceipt;
}

export function fetchStoryPuzzleState(
  expectedUid?: string,
): Promise<StoryPuzzleSnapshot> {
  return authorizedRequest<StoryPuzzleStateResponse>(
    '/puzzles',
    undefined,
    expectedUid,
  ).then((response) => {
    if (!isRecord(response.puzzleState)) throw invalidResponse('/puzzles');
    return response.puzzleState;
  });
}

export function saveStoryPuzzleProgress(
  puzzleId: string,
  draft: StoryPuzzleDraft,
): Promise<StoryPuzzleSnapshot> {
  return authorizedRequest<StoryPuzzleStateResponse>('/puzzles/progress', {
    method: 'POST',
    body: JSON.stringify({ puzzleId, draft }),
  }).then((response) => response.puzzleState);
}

export function completeStoryPuzzle(
  puzzleId: string,
  draft: StoryPuzzleDraft,
): Promise<StoryPuzzleRewardReceipt> {
  return authorizedRequest<StoryPuzzleRewardResponse>('/puzzles/complete', {
    method: 'POST',
    body: JSON.stringify({ puzzleId, draft }),
  }).then((response) => response.reward);
}

export async function issueNativeEntryGrant(challenge: string, expectedUid: string): Promise<{code:string;expiresAt:number}> {
  const result=await authorizedRequest<{code:string;expiresAt:number;scope:string}>('/native-entry/issue',{
    method:'POST',body:JSON.stringify({challenge}),
  },expectedUid);
  if(result.scope!=='native-chapter-entry'||!/^[A-Za-z0-9_-]{43}$/.test(result.code)||!Number.isFinite(result.expiresAt)) throw invalidResponse('/native-entry/issue');
  return result;
}

export function completeOpeningRecovery(
  imageOrder: readonly number[],
): Promise<OpeningRecoveryApiResponse> {
  return authorizedRequest<OpeningRecoveryApiResponse>('/opening-recovery/complete', {
    method: 'POST',
    body: JSON.stringify({ imageOrder }),
  });
}

export function completeOpeningRoom(
  eventIds: readonly OpeningRoomEventId[],
): Promise<OpeningRoomApiResponse> {
  return authorizedRequest<OpeningRoomApiResponse>('/opening-room/complete', {
    method: 'POST',
    body: JSON.stringify({ eventIds }),
  });
}

export function discoverStoryPuzzle(puzzleId: string): Promise<StoryPuzzleSnapshot> {
  return authorizedRequest<StoryPuzzleStateResponse>('/puzzles/discover', {
    method: 'POST',
    body: JSON.stringify({ puzzleId }),
  }).then((response) => response.puzzleState);
}

export function unlockStoryPuzzleHint(
  puzzleId: string,
  hintIndex: number,
): Promise<{ alreadyUnlocked: boolean; puzzleState: StoryPuzzleSnapshot }> {
  return authorizedRequest<{ alreadyUnlocked: boolean; puzzleState: StoryPuzzleSnapshot }>('/puzzles/hints', {
    method: 'POST',
    body: JSON.stringify({ puzzleId, hintIndex }),
  });
}

interface CollectionApiResponse {
  collection: CollectionSnapshot;
}

export function fetchPlayerCollection(
  expectedUid?: string,
): Promise<CollectionSnapshot> {
  return authorizedRequest<CollectionApiResponse>(
    '/collection',
    undefined,
    expectedUid,
  ).then((response) => {
    if (!isRecord(response.collection)) throw invalidResponse('/collection');
    return response.collection;
  });
}

export function reconstructPlayerMemory(
  chapterId: string,
): Promise<CollectionSnapshot> {
  return authorizedRequest<CollectionApiResponse>('/collection/reconstruct', {
    method: 'POST',
    body: JSON.stringify({ chapterId }),
  }).then((response) => response.collection);
}

export function equipPlayerCosmetic(
  cosmeticId: string,
): Promise<CollectionSnapshot> {
  return authorizedRequest<CollectionApiResponse>('/collection/equip', {
    method: 'POST',
    body: JSON.stringify({ cosmeticId }),
  }).then((response) => response.collection);
}

interface LiveApiResponse {
  live: LiveChallengesSnapshot;
}

interface LiveReceiptResponse {
  receipt: LiveCompletionReceipt;
}

export function fetchLiveChallenges(
  expectedUid?: string,
): Promise<LiveChallengesSnapshot> {
  return authorizedRequest<LiveApiResponse>('/live', undefined, expectedUid)
    .then((response) => {
      if (!isRecord(response.live)) throw invalidResponse('/live');
      return response.live;
    });
}

function liveAction<T>(action: string, body: Record<string, unknown> = {}): Promise<T> {
  return authorizedRequest<T>('/live/action', {
    method: 'POST',
    body: JSON.stringify({ action, ...body }),
  });
}

export function startDailySignal(): Promise<LiveChallengesSnapshot> {
  return liveAction<LiveApiResponse>('start-daily').then((response) => response.live);
}

export function saveDailySignalDraft(draft: { answer?: string }): Promise<LiveChallengesSnapshot> {
  return liveAction<LiveApiResponse>('save-daily', { draft }).then((response) => response.live);
}

export function useDailySignalHint(hintIndex: number): Promise<{
  alreadyUnlocked: boolean;
  hint: string;
  live: LiveChallengesSnapshot;
}> {
  return liveAction('use-daily-hint', { hintIndex });
}

export function completeDailySignal(answer: string): Promise<LiveCompletionReceipt> {
  return liveAction<LiveReceiptResponse>('complete-daily', { answer })
    .then((response) => response.receipt);
}

export function startWeeklySystemTrial(): Promise<LiveChallengesSnapshot> {
  return liveAction<LiveApiResponse>('start-weekly').then((response) => response.live);
}

export function saveWeeklySystemTrialDraft(draft: { answer?: string }): Promise<LiveChallengesSnapshot> {
  return liveAction<LiveApiResponse>('save-weekly', { draft }).then((response) => response.live);
}

export function completeWeeklySystemTrialStage(
  stageIndex: number,
  answer: string,
): Promise<LiveCompletionReceipt> {
  return liveAction<LiveReceiptResponse>('complete-weekly-stage', { stageIndex, answer })
    .then((response) => response.receipt);
}

export function useWeeklySystemTrialHint(hintIndex: number): Promise<{
  alreadyUnlocked: boolean;
  hint: string;
  live: LiveChallengesSnapshot;
}> {
  return liveAction('use-weekly-hint', { hintIndex });
}

/**
 * Optional product measurement never changes player state. Failures are
 * intentionally silent to the player and must not interrupt gameplay.
 */
export async function submitPlayerTelemetry(
  event: PlayerTelemetryEvent,
  expectedUid?: string,
): Promise<boolean> {
  try {
    const session = await getCurrentAuthSession(expectedUid);
    const response = await fetchPlayerRequest(`${apiRoot()}/telemetry`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${session.token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(event),
    });
    return response.status === 204;
  } catch {
    return false;
  }
}
