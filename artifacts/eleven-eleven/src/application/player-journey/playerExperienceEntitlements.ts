import type { GameScreenId } from '../../app/shell/screenRegistry';
import type { NavigationCategoryId } from '../../app/shell/navigationTypes';
import type { AuthRuntimeStatus } from '../../features/auth/authStore';
import type { PlayerProgressionStatus } from '../../features/player-progression/playerProgressionStore';
import type { StoryPuzzleSnapshot } from '../../domain/story-puzzles/storyPuzzleContracts';
import type { AuthoritativeStoryState } from '../../domain/story/storyState';

export type ExperienceAuthority = 'signed-out' | 'syncing' | 'verified';

export type ExperienceLockReason =
  | 'sign-in-required'
  | 'progress-syncing'
  | 'first-clue-required'
  | 'first-reward-required'
  | 'chapter-one-required'
  | 'chapter-two-required'
  | 'chapter-three-required'
  | 'verified-chess-training-required'
  | 'rollout-disabled'
  | 'part-two-required'
  | 'opening-recovery-required'
  | 'opening-room-required';

export interface PlayerExperienceSnapshot {
  version: 1;
  authority: ExperienceAuthority;
  mainPuzzleCount: number;
  totalPuzzleCount: number;
  completedChapterIds: readonly string[];
  canonReceiptIds: readonly string[];
  /** Derived from a server-issued puzzle status, never browser history. */
  storyPuzzleAvailable: boolean;
  firstRewardReceived: boolean;
  /** Not projected from browser state until an authoritative API publishes it. */
  chessTrainingCompleted: boolean;
  /** Not projected from browser state until an authoritative API publishes it. */
  casualChessCompleted: number;
  /** The Network service, not a local training screen, grants Ranked admission. */
  rankedChessUnlocked: boolean;
  openingCoverPuzzleCompleted: boolean;
  openingRoomCompleted: boolean;
  manhwaPacketIds: readonly string[];
  chessHobbyUnlocked: boolean;
  /** Compatibility marker for pre-opening snapshots during migration only. */
  openingGatewayPublished: boolean;
}

/**
 * A deliberately small projection of the Network service's authoritative
 * eligibility record.  It is kept separate from story state so a browser
 * cannot unlock Ranked by completing a local Echo duel or altering history.
 */
export interface AuthoritativeNetworkProgress {
  chessTrainingCompleted: boolean;
  casualChessCompleted: number;
  rankedChessUnlocked: boolean;
}

export interface RolloutPolicy {
  /** Deployment-owned policy revisions are intentionally not player state. */
  version: number;
  expiresAt: string | null;
  dailyEnabled: boolean;
  weeklyEnabled: boolean;
  networkEnabled: boolean;
  communityEnabled: boolean;
  forgeSubmissionEnabled: boolean;
  echoAgentEnabled: boolean;
  part2WorldEnabled: boolean;
}

export interface ExperienceEntitlements {
  version: 1;
  snapshot: PlayerExperienceSnapshot;
  rollout: RolloutPolicy;
  visibleNavigation: readonly NavigationCategoryId[];
  accessibleScreens: readonly GameScreenId[];
  puzzleModes: readonly ('story' | 'daily' | 'weekly')[];
  networkModes: readonly ('casual-chess' | 'coop-training' | 'ranked')[];
  lockedReasonByScreen: Readonly<Partial<Record<GameScreenId, ExperienceLockReason>>>;
  part2Eligible: boolean;
}

export interface ExperienceEntitlementInput {
  authStatus: AuthRuntimeStatus;
  storyPuzzleSnapshot: StoryPuzzleSnapshot | null;
  storyStatus: PlayerProgressionStatus;
  authoritativeStoryState: AuthoritativeStoryState | null;
  authoritativeNetworkProgress?: AuthoritativeNetworkProgress | null;
  online: boolean;
  rollout?: Partial<RolloutPolicy>;
}

export interface ExperienceRouteResolution {
  requestedScreen: GameScreenId;
  screen: GameScreenId;
  allowed: boolean;
  reason: ExperienceLockReason | null;
}

const BASE_SIGNED_IN_SCREENS: readonly GameScreenId[] = [
  'main-menu',
  'psychological-state',
  'memories',
  'settings',
  'profile',
];

const BASE_SIGNED_OUT_SCREENS: readonly GameScreenId[] = [
  'main-menu',
  'settings',
];

/** A signed-in player may keep reading while the authoritative record loads. */
const BASE_SYNCING_SCREENS: readonly GameScreenId[] = [
  'main-menu',
  'psychological-state',
  'memories',
  'settings',
];

const BASE_NAVIGATION: readonly NavigationCategoryId[] = ['story'];

const VERIFICATION_REQUIRED_SCREENS: readonly GameScreenId[] = [
  'psychological-state',
  'memories',
  'puzzles',
  'progress',
  'echo-mind',
  'characters',
  'echo-network',
  'leaderboard',
  'play',
  'opening-recovery',
  'cinematic',
  'awakening-ward',
  'profile',
];

const PROGRESS_SYNC_REQUIRED_SCREENS: readonly GameScreenId[] = [
  'puzzles',
  'progress',
  'echo-mind',
  'characters',
  'echo-network',
  'leaderboard',
  'play',
  'opening-recovery',
  'cinematic',
  'awakening-ward',
  'profile',
];

const DEFAULT_ROLLOUT_POLICY: RolloutPolicy = Object.freeze({
  version: 1,
  expiresAt: null,
  // Optional systems never become visible just because a browser holds an
  // old bundle. ApplicationShell supplies a validated server policy after
  // authentication; until then, the journey stays on its safe core route.
  dailyEnabled: false,
  weeklyEnabled: false,
  networkEnabled: false,
  communityEnabled: false,
  forgeSubmissionEnabled: false,
  echoAgentEnabled: false,
  part2WorldEnabled: false,
});

function unique<T>(values: readonly T[]): T[] {
  return [...new Set(values)];
}

function isRolloutCurrent(policy: RolloutPolicy): boolean {
  if (!policy.expiresAt) return true;
  const expiry = Date.parse(policy.expiresAt);
  return Number.isFinite(expiry) && expiry > Date.now();
}

function createSnapshot(input: ExperienceEntitlementInput): PlayerExperienceSnapshot {
  const authenticated = input.authStatus === 'signed-in';
  const identityKnownSignedOut = input.authStatus === 'signed-out'
    || input.authStatus === 'unavailable';
  const verified = authenticated
    && input.storyStatus === 'ready'
    && input.storyPuzzleSnapshot !== null
    && input.authoritativeStoryState !== null;
  // Auth boot is intentionally treated as a bounded read-only state: it keeps
  // the onboarding/Home/Manhwa route intact while all gated systems remain
  // closed. Once Firebase reports an actual signed-out state, only identity
  // surfaces remain available.
  const authority: ExperienceAuthority = identityKnownSignedOut
    ? 'signed-out'
    : verified && input.online ? 'verified' : 'syncing';
  const puzzles = verified ? input.storyPuzzleSnapshot : null;
  const story = verified ? input.authoritativeStoryState : null;
  const network = verified ? input.authoritativeNetworkProgress : null;
  const casualChessCompleted = Number.isSafeInteger(network?.casualChessCompleted)
    && (network?.casualChessCompleted ?? 0) >= 0
    ? network!.casualChessCompleted
    : 0;
  const chessTrainingCompleted = network?.chessTrainingCompleted === true;
  // A server record may never claim Ranked admission without the two
  // prerequisites.  This redundant client-side check is presentation safety,
  // not admission authority; the ticket endpoint checks again.
  const rankedChessUnlocked = network?.rankedChessUnlocked === true
    && chessTrainingCompleted
    && casualChessCompleted >= 3;

  return {
    version: 1,
    authority,
    mainPuzzleCount: puzzles?.mainCompletedCount ?? 0,
    totalPuzzleCount: puzzles?.totalCompletedCount ?? 0,
    completedChapterIds: story?.completedChapterIds ?? [],
    canonReceiptIds: story?.canonEventReceipts.map((receipt) => receipt.eventId) ?? [],
    storyPuzzleAvailable: Boolean(puzzles?.entries.some((entry) => (
      entry.status === 'available'
      || entry.status === 'in_progress'
      || entry.status === 'completed'
    ))),
    firstRewardReceived: (puzzles?.totalCompletedCount ?? 0) > 0,
    chessTrainingCompleted,
    casualChessCompleted,
    rankedChessUnlocked,
    openingCoverPuzzleCompleted: story?.openingCoverPuzzleCompleted === true,
    openingRoomCompleted: story?.openingRoomCompleted === true,
    manhwaPacketIds: story?.manhwaPacketIds ?? [],
    chessHobbyUnlocked: story?.chessHobbyUnlocked === true,
    openingGatewayPublished: story !== null
      && Object.prototype.hasOwnProperty.call(
        story,
        'openingCoverPuzzleCompleted',
      ),
  };
}

function lockedScreens(
  snapshot: PlayerExperienceSnapshot,
  rollout: RolloutPolicy,
): Partial<Record<GameScreenId, ExperienceLockReason>> {
  const locked: Partial<Record<GameScreenId, ExperienceLockReason>> = {};
  const chapterOneComplete = snapshot.completedChapterIds.includes('chapter_1');
  const chapterTwoComplete = snapshot.completedChapterIds.includes('chapter_2');
  const chapterThreeComplete = snapshot.completedChapterIds.includes('chapter_3');

  if (snapshot.authority === 'signed-out') {
    for (const screen of VERIFICATION_REQUIRED_SCREENS) locked[screen] = 'sign-in-required';
    return locked;
  }
  if (snapshot.authority !== 'verified') {
    for (const screen of PROGRESS_SYNC_REQUIRED_SCREENS) locked[screen] = 'progress-syncing';
    return locked;
  }

  if (!snapshot.openingGatewayPublished) {
    locked.play = 'part-two-required';
  } else if (!snapshot.openingCoverPuzzleCompleted) {
    locked.play = 'opening-recovery-required';
    locked.puzzles = 'opening-recovery-required';
    locked.memories = 'opening-recovery-required';
  } else if (snapshot.openingGatewayPublished && !snapshot.openingRoomCompleted) {
    locked.puzzles = 'opening-room-required';
    locked.memories = 'opening-room-required';
  }

  if (!snapshot.storyPuzzleAvailable) {
    locked.puzzles = 'first-clue-required';
  }
  if (!snapshot.firstRewardReceived) locked.progress = 'first-reward-required';
  if (!chapterOneComplete) {
    locked['echo-mind'] = 'chapter-one-required';
    locked.characters = 'chapter-one-required';
  }
  if (!chapterTwoComplete || !rollout.networkEnabled) {
    locked['echo-network'] = !rollout.networkEnabled
      ? 'rollout-disabled'
      : 'chapter-two-required';
  }
  if (!rollout.networkEnabled || !chapterThreeComplete || !snapshot.rankedChessUnlocked) {
    locked.leaderboard = !rollout.networkEnabled
      ? 'rollout-disabled'
      : !chapterThreeComplete
        ? 'chapter-three-required'
        : 'verified-chess-training-required';
  }
  // The Part 2 route is intentionally not published in Stage 3. Eligibility
  // is exposed for a future server-backed world release, never as permission
  // to enter the dormant prototype screens.
  if (snapshot.openingGatewayPublished && !snapshot.openingCoverPuzzleCompleted) {
    locked.play = 'opening-recovery-required';
  }
  locked.cinematic = 'part-two-required';
  return locked;
}

/**
 * Presentation-only route access derived from server-issued puzzle and Canon
 * snapshots. Missing, expired, offline, or unsigned data closes extra
 * surfaces instead of granting access from browser state.
 */
export function deriveExperienceEntitlements(
  input: ExperienceEntitlementInput,
): ExperienceEntitlements {
  const snapshot = createSnapshot(input);
  const rollout: RolloutPolicy = {
    ...DEFAULT_ROLLOUT_POLICY,
    ...input.rollout,
    version: 1,
  };
  const rolloutCurrent = snapshot.authority === 'verified'
    && isRolloutCurrent(rollout);
  const effectiveRollout: RolloutPolicy = rolloutCurrent
    ? rollout
    : {
      ...rollout,
      dailyEnabled: false,
      weeklyEnabled: false,
      networkEnabled: false,
      communityEnabled: false,
      forgeSubmissionEnabled: false,
      echoAgentEnabled: false,
      part2WorldEnabled: false,
    };
  const lockedReasonByScreen = lockedScreens(snapshot, effectiveRollout);
  const legacyBaseScreens = snapshot.authority === 'signed-out'
    ? BASE_SIGNED_OUT_SCREENS
    : snapshot.authority === 'verified'
      ? BASE_SIGNED_IN_SCREENS
      : BASE_SYNCING_SCREENS;
  const baseScreens = snapshot.openingGatewayPublished
    ? legacyBaseScreens.filter((screen) => screen !== 'memories')
    : legacyBaseScreens;
  const chapterOneComplete = snapshot.completedChapterIds.includes('chapter_1');
  const chapterTwoComplete = snapshot.completedChapterIds.includes('chapter_2');
  const chapterThreeComplete = snapshot.completedChapterIds.includes('chapter_3');
  const part2Eligible = snapshot.totalPuzzleCount >= 20
    && snapshot.completedChapterIds.length >= 4
    && effectiveRollout.part2WorldEnabled;
  const accessibleScreens = unique([
    ...baseScreens,
    ...(snapshot.openingGatewayPublished && !snapshot.openingRoomCompleted
      ? ['opening-recovery' as const]
      : []),
    ...(snapshot.openingGatewayPublished && snapshot.openingCoverPuzzleCompleted
      ? ['play' as const]
      : []),
    ...(snapshot.openingGatewayPublished && snapshot.openingRoomCompleted
      ? ['memories' as const]
      : []),
    ...(snapshot.storyPuzzleAvailable
      && (!snapshot.openingGatewayPublished || snapshot.openingRoomCompleted)
      ? ['puzzles' as const]
      : []),
    ...(snapshot.firstRewardReceived
      && (!snapshot.openingGatewayPublished || snapshot.openingRoomCompleted)
      ? ['progress' as const]
      : []),
    ...(chapterOneComplete ? ['echo-mind' as const, 'characters' as const] : []),
    ...(chapterTwoComplete && effectiveRollout.networkEnabled
      ? ['echo-network' as const]
      : []),
    ...(chapterThreeComplete && snapshot.rankedChessUnlocked && effectiveRollout.networkEnabled
      ? ['leaderboard' as const]
      : []),
  ]).filter((screen) => !lockedReasonByScreen[screen]);
  const visibleNavigation = unique([
    ...(snapshot.authority === 'verified' ? BASE_NAVIGATION : []),
    ...(snapshot.storyPuzzleAvailable
      && (!snapshot.openingGatewayPublished || snapshot.openingRoomCompleted)
      ? ['puzzles' as const]
      : []),
    ...(snapshot.firstRewardReceived
      && (!snapshot.openingGatewayPublished || snapshot.openingRoomCompleted)
      ? ['memory' as const]
      : []),
    ...(chapterTwoComplete && effectiveRollout.networkEnabled
      ? ['network' as const]
      : []),
  ]);
  const puzzleModes: Array<'story' | 'daily' | 'weekly'> = ['story'];
  if (chapterOneComplete && effectiveRollout.dailyEnabled) puzzleModes.push('daily');
  if (chapterTwoComplete && effectiveRollout.weeklyEnabled) puzzleModes.push('weekly');
  const networkModes: Array<'casual-chess' | 'coop-training' | 'ranked'> = [];
  if (chapterTwoComplete && effectiveRollout.networkEnabled) {
    networkModes.push('casual-chess', 'coop-training');
  }
  if (chapterThreeComplete && snapshot.rankedChessUnlocked && effectiveRollout.networkEnabled) {
    networkModes.push('ranked');
  }

  return {
    version: 1,
    snapshot,
    rollout: effectiveRollout,
    visibleNavigation,
    accessibleScreens,
    puzzleModes,
    networkModes,
    lockedReasonByScreen,
    part2Eligible,
  };
}

export function createInitialExperienceEntitlements(): ExperienceEntitlements {
  return deriveExperienceEntitlements({
    authStatus: 'checking',
    storyPuzzleSnapshot: null,
    storyStatus: 'idle',
    authoritativeStoryState: null,
    online: false,
  });
}

export function resolveExperienceRoute(
  requestedScreen: GameScreenId,
  entitlements: ExperienceEntitlements,
): ExperienceRouteResolution {
  if (entitlements.accessibleScreens.includes(requestedScreen)) {
    return { requestedScreen, screen: requestedScreen, allowed: true, reason: null };
  }
  const fallback = entitlements.snapshot.authority === 'verified'
    ? 'psychological-state'
    : 'main-menu';
  const reason = entitlements.lockedReasonByScreen[requestedScreen]
    ?? (entitlements.snapshot.authority === 'signed-out'
      ? 'sign-in-required'
      : 'progress-syncing');
  return { requestedScreen, screen: fallback, allowed: false, reason };
}

export function experienceLockCopy(
  reason: ExperienceLockReason,
  locale: 'ar' | 'en',
): { eyebrow: string; title: string; detail: string; action: string } {
  const english = locale === 'en';
  const copy: Record<ExperienceLockReason, { eyebrow: string; title: string; detail: string; action: string }> = {
    'first-clue-required': english
      ? { eyebrow: 'STORY CLUE REQUIRED', title: 'Read the next Manhwa page first', detail: 'The puzzle channel opens after the next story clue is verified.', action: 'Return to the mission' }
      : { eyebrow: 'الدليل القصصي مطلوب', title: 'اقرأ صفحة المانهوا التالية أولًا', detail: 'تُفتح قناة الألغاز بعد توثيق الدليل القصصي التالي.', action: 'العودة إلى المهمة' },
    'sign-in-required': english
      ? { eyebrow: 'IDENTITY REQUIRED', title: 'Secure your identity first', detail: 'Sign in before opening a verified journey surface.', action: 'Return to the main menu' }
      : { eyebrow: 'الهوية مطلوبة', title: 'ثبّت هويتك أولًا', detail: 'سجّل الدخول قبل فتح أي سطح مرتبط بتقدم موثّق.', action: 'العودة إلى القائمة الرئيسية' },
    'progress-syncing': english
      ? { eyebrow: 'VERIFYING PROGRESS', title: 'Your journey is still synchronizing', detail: 'We kept this surface closed until the server record is ready.', action: 'Stay on the mission' }
      : { eyebrow: 'جارٍ التحقق من التقدم', title: 'رحلتك ما زالت تتزامن', detail: 'أبقينا هذا السطح مغلقًا حتى يصبح السجل الخادمي جاهزًا.', action: 'البقاء في المهمة' },
    'first-reward-required': english
      ? { eyebrow: 'FIRST RECEIPT', title: 'Earn your first verified reward', detail: 'Complete the first story puzzle to unlock this record.', action: 'Continue the mission' }
      : { eyebrow: 'أول إيصال', title: 'اكسب أول مكافأة موثّقة', detail: 'أكمل أول لغز قصصي لفتح هذا السجل.', action: 'متابعة المهمة' },
    'chapter-one-required': english
      ? { eyebrow: 'CHAPTER 01', title: 'Complete Chapter 1 first', detail: 'The story has not introduced this file safely yet.', action: 'Continue the mission' }
      : { eyebrow: 'الفصل 01', title: 'أكمل الفصل الأول أولًا', detail: 'لم تقدّم القصة هذا الملف بصورة آمنة بعد.', action: 'متابعة المهمة' },
    'chapter-two-required': english
      ? { eyebrow: 'CHAPTER 02', title: 'Complete Chapter 2 first', detail: 'Play Together opens after the next verified story chapter.', action: 'Continue the mission' }
      : { eyebrow: 'الفصل 02', title: 'أكمل الفصل الثاني أولًا', detail: 'يفتح اللعب المشترك بعد الفصل القصصي الموثّق التالي.', action: 'متابعة المهمة' },
    'chapter-three-required': english
      ? { eyebrow: 'CHAPTER 03', title: 'Complete Chapter 3 first', detail: 'This competitive record stays closed until the story reaches it.', action: 'Continue the mission' }
      : { eyebrow: 'الفصل 03', title: 'أكمل الفصل الثالث أولًا', detail: 'يبقى هذا السجل التنافسي مغلقًا حتى تصل إليه القصة.', action: 'متابعة المهمة' },
    'verified-chess-training-required': english
      ? { eyebrow: 'CHESS VERIFICATION', title: 'Complete verified chess training', detail: 'Ranked play opens only after the server confirms the training path.', action: 'Continue the mission' }
      : { eyebrow: 'تحقق الشطرنج', title: 'أكمل تدريب الشطرنج الموثّق', detail: 'يفتح اللعب المصنف فقط بعد أن يؤكد الخادم مسار التدريب.', action: 'متابعة المهمة' },
    'rollout-disabled': english
      ? { eyebrow: 'CHANNEL OFFLINE', title: 'This channel is not available yet', detail: 'The service is intentionally held closed while we prepare it.', action: 'Continue the mission' }
      : { eyebrow: 'القناة غير متاحة', title: 'هذه القناة غير متاحة بعد', detail: 'تبقى مغلقة عمدًا بينما نجهزها.', action: 'متابعة المهمة' },
    'part-two-required': english
      ? { eyebrow: 'PART 2 LOCKED', title: 'Restore the full record first', detail: 'Outside the System begins after all 20 puzzles and four chapters are verified.', action: 'Continue the mission' }
      : { eyebrow: 'الجزء الثاني مقفل', title: 'استعد السجل كاملًا أولًا', detail: 'يبدأ خارج النظام بعد توثيق الألغاز العشرين والفصول الأربعة.', action: 'متابعة المهمة' },
    'opening-recovery-required': english
      ? { eyebrow: 'OPENING GATEWAY', title: 'Reconstruct the first signal', detail: 'Align the cover to wake the room beyond the interface.', action: 'Open the reconstruction' }
      : { eyebrow: 'بوابة الافتتاح', title: 'أعد بناء الإشارة الأولى', detail: 'رتّب الغلاف لإيقاظ الغرفة خلف الواجهة.', action: 'فتح تركيب الغلاف' },
    'opening-room-required': english
      ? { eyebrow: 'ROOM REQUIRED', title: 'Enter the opening room', detail: 'The old puzzle channels stay quiet until the first room and memory beat are complete.', action: 'Enter the room' }
      : { eyebrow: 'الغرفة مطلوبة', title: 'ادخل الغرفة الافتتاحية', detail: 'تبقى قنوات الألغاز هادئة حتى يكتمل المشهد الأول.', action: 'ادخل الغرفة' },
  };
  return copy[reason];
}
