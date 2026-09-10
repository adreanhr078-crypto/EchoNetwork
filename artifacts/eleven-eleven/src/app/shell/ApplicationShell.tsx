import { Suspense, useEffect, useMemo, useRef, useState } from 'react';
import { useGameStore } from '../../stores/gameStore';
import {
  GameButton,
  GameDrawer,
  GameLoadingScreen,
  GameModal,
  GameProgress,
  GameSafeArea,
  GameTooltip,
  GameViewport,
} from '../../ui/design-system';
import {
  GameIcon,
  GameIconLabel,
} from '../../ui/icons';
import { createDashboardReadModel } from '../../application/ui/gameUiReadModels';
import {
  getCanonicalManhwaBadgeCount,
} from '../../application/ui/manhwaArchiveReadModel';
import {
  PremiumAtmosphere,
  ScreenTransition,
  AchievementPresentationOverlay,
  EchoTransformationCinematic,
} from '../../ui/presentation';
import {
  GAME_SCREEN_REGISTRY,
} from './screenRegistry';
import {
  getCategoryScreens,
  getNavigationCategoryForScreen,
  NAVIGATION_CATEGORY_REGISTRY,
  PRIMARY_NAVIGATION_CATEGORIES,
} from './navigationRegistry';
import {
  useShellStore,
  useUiPreferencesStore,
} from './shellStore';
import { PlayerResourceCounters } from './PlayerResourceCounters';
import { DemoExperienceLayer } from '../demo/DemoExperienceLayer';
import { AuthStatusButton } from '../../features/auth/AuthStatusButton';
import { useStoryPuzzleStore } from '../../features/story-puzzles/storyPuzzleStore';
import { CoreObjectiveCard } from '../../features/player-journey/CoreObjectiveCard';
import { useAuthStore } from '../../features/auth/authStore';
import { usePlayerProgressionStore } from '../../features/player-progression/playerProgressionStore';
import {
  deriveExperienceEntitlements,
  experienceLockCopy,
  type AuthoritativeNetworkProgress,
  type RolloutPolicy,
} from '../../application/player-journey/playerExperienceEntitlements';
import { fetchPlayerRolloutPolicy } from '../../infrastructure/player-experience/rolloutPolicyApi';
import {
  fetchEchoNetwork,
  type NetworkEligibilitySnapshot,
} from '../../infrastructure/echo-network/echoNetworkApi';

const ENGLISH_CATEGORY_COPY: Record<string, { label: string; shortLabel: string; description: string }> = {
  story: {
    label: 'Home',
    shortLabel: 'Home',
    description: 'One clear objective, its story evidence, and the next verified action.',
  },
  memory: {
    label: 'Manhwa',
    shortLabel: 'Manhwa',
    description: 'Read the Manhwa archive and unlock pages with memory shards.',
  },
  puzzles: {
    label: 'Puzzles',
    shortLabel: 'Puzzles',
    description: 'Solve story nodes and reconstruct missing events.',
  },
  network: {
    label: 'Echo Network',
    shortLabel: 'Network',
    description: 'Chess, co-op, seasons, and the signal community in one place.',
  },
};

const ENGLISH_SCREEN_COPY: Record<string, { label: string; description: string }> = {
  'psychological-state': {
    label: 'Mission Control',
    description: 'Your current objective and the verified route forward.',
  },
  memories: {
    label: 'Manhwa archive',
    description: 'Manhwa Archive // open and locked pages.',
  },
  puzzles: {
    label: '11:11 Puzzle Hub',
    description: 'Story path, Daily Signal, and Weekly System Trial.',
  },
};

const ARABIC_SCREEN_COPY: Record<string, { label: string; description: string }> = {
  'psychological-state': {
    label: 'مركز المهمة',
    description: 'هدفك الحالي والطريق الموثّق للخطوة التالية.',
  },
};

function localizedCategory(
  locale: 'ar' | 'en',
  category: { id: string; label: string; shortLabel: string; description: string },
) {
  return locale === 'en'
    ? ENGLISH_CATEGORY_COPY[category.id] ?? category
    : category;
}

function localizedScreen(
  locale: 'ar' | 'en',
  screen: { id: string; label: string; description: string },
) {
  return locale === 'en'
    ? ENGLISH_SCREEN_COPY[screen.id] ?? screen
    : ARABIC_SCREEN_COPY[screen.id] ?? screen;
}

function useBrowserOnline(): boolean {
  const [online, setOnline] = useState(() => (
    typeof navigator !== 'undefined' ? navigator.onLine : false
  ));

  useEffect(() => {
    const update = () => setOnline(navigator.onLine);
    window.addEventListener('online', update);
    window.addEventListener('offline', update);
    return () => {
      window.removeEventListener('online', update);
      window.removeEventListener('offline', update);
    };
  }, []);

  return online;
}

export function ApplicationShell() {
  const shell = useShellStore();
  const preferences = useUiPreferencesStore();
  const storyPuzzleSnapshot = useStoryPuzzleStore((state) => state.snapshot);
  const authStatus = useAuthStore((state) => state.status);
  const authUser = useAuthStore((state) => state.user);
  const storyStatus = usePlayerProgressionStore((state) => state.storyStatus);
  const authoritativeStoryState = usePlayerProgressionStore((state) => state.storyState);
  const online = useBrowserOnline();
  const [rolloutPolicy, setRolloutPolicy] = useState<RolloutPolicy | null>(null);
  const [networkProgress, setNetworkProgress] = useState<AuthoritativeNetworkProgress | null>(null);
  const rolloutRequestSequence = useRef(0);
  const networkRequestSequence = useRef(0);
  const networkProgressUidRef = useRef<string | null>(null);
  const networkRefreshEpoch = useShellStore((state) => state.experienceNetworkRefreshEpoch);
  useEffect(() => {
    const sequence = ++rolloutRequestSequence.current;
    if (authStatus !== 'signed-in' || !authUser?.uid) {
      setRolloutPolicy(null);
      return undefined;
    }
    // Do not keep an old account's policy visible while an ID token changes.
    setRolloutPolicy(null);
    void fetchPlayerRolloutPolicy(authUser.uid)
      .then((policy) => {
        if (sequence === rolloutRequestSequence.current) setRolloutPolicy(policy);
      })
      .catch(() => {
        if (sequence === rolloutRequestSequence.current) setRolloutPolicy(null);
      });
    return () => {
      // The sequence guard, rather than an AbortController, also protects a
      // late Firebase token resolution for a signed-out or switched account.
    };
  }, [authStatus, authUser?.uid]);
  useEffect(() => {
    const sequence = ++networkRequestSequence.current;
    const rolloutIsCurrent = rolloutPolicy?.networkEnabled === true
      && (!rolloutPolicy.expiresAt || Date.parse(rolloutPolicy.expiresAt) > Date.now());
    if (authStatus !== 'signed-in' || !authUser?.uid || !rolloutIsCurrent) {
      setNetworkProgress(null);
      networkProgressUidRef.current = null;
      return undefined;
    }
    // This read is solely a display projection of the Network-owned record.
    // Failure leaves Ranked closed; it never falls back to a local duel flag.
    // Preserve the previous server-issued projection for this same identity
    // while refreshing it.  Clearing it first would bounce an already
    // admitted player away from Ranked during a harmless refresh; account or
    // rollout changes still clear it above.
    if (networkProgressUidRef.current !== authUser.uid) {
      setNetworkProgress(null);
      networkProgressUidRef.current = null;
    }
    void fetchEchoNetwork()
      .then((snapshot) => {
        if (sequence !== networkRequestSequence.current) return;
        const eligibility: NetworkEligibilitySnapshot = snapshot.eligibility;
        setNetworkProgress({
          chessTrainingCompleted: eligibility.chessTrainingCompleted === true,
          casualChessCompleted: eligibility.casualChessCompleted,
          rankedChessUnlocked: eligibility.rankedChessUnlocked === true,
        });
        networkProgressUidRef.current = authUser.uid;
      })
      .catch(() => {
        if (sequence === networkRequestSequence.current && networkProgressUidRef.current !== authUser.uid) {
          setNetworkProgress(null);
          networkProgressUidRef.current = null;
        }
      });
    return undefined;
  }, [authStatus, authUser?.uid, networkRefreshEpoch, rolloutPolicy]);
  const entitlements = useMemo(() => deriveExperienceEntitlements({
    authStatus,
    storyPuzzleSnapshot,
    storyStatus,
    authoritativeStoryState,
    authoritativeNetworkProgress: networkProgressUidRef.current === authUser?.uid
      ? networkProgress
      : null,
    online,
    rollout: rolloutPolicy ?? undefined,
  }), [
    authStatus,
    authoritativeStoryState,
    online,
    networkProgress,
    rolloutPolicy,
    storyPuzzleSnapshot,
    storyStatus,
  ]);
  useEffect(() => {
    shell.setExperienceEntitlements(entitlements);
  }, [entitlements, shell.setExperienceEntitlements]);
  const chapterTitle = useGameStore(
    (state) => createDashboardReadModel(
      state,
      storyPuzzleSnapshot,
      preferences.locale,
    ).chapter.title,
  );
  const campaignProgress = useGameStore(
    (state) => createDashboardReadModel(
      state,
      storyPuzzleSnapshot,
      preferences.locale,
    ).puzzleProgress.progress,
  );
  const unviewedManhwaPages = useGameStore((state) => (
    getCanonicalManhwaBadgeCount(state.progressionState)
  ));
  const definition = GAME_SCREEN_REGISTRY[shell.currentScreen];
  const currentCategory = getNavigationCategoryForScreen(
    shell.currentScreen,
  );
  const requestedOpenCategory = shell.navigationCategory
    ? NAVIGATION_CATEGORY_REGISTRY[shell.navigationCategory]
    : currentCategory;
  const openCategory = entitlements.visibleNavigation.includes(requestedOpenCategory.id)
    ? requestedOpenCategory
    : currentCategory;
  const categoryScreens = getCategoryScreens(openCategory.id)
    .filter((screen) => entitlements.accessibleScreens.includes(screen.id));
  const currentCategoryScreens = getCategoryScreens(currentCategory.id)
    .filter((screen) => entitlements.accessibleScreens.includes(screen.id));
  const visiblePrimaryNavigation = PRIMARY_NAVIGATION_CATEGORIES.filter((category) => (
    entitlements.visibleNavigation.includes(category.id)
  ));
  const currentCategoryHasMenu = currentCategoryScreens.length > 1;
  const currentCategoryCopy = localizedCategory(preferences.locale, currentCategory);
  const currentScreenCopy = localizedScreen(preferences.locale, definition);
  const openCategoryCopy = localizedCategory(preferences.locale, openCategory);
  const Screen = definition.component;
  const isMainMenu = shell.currentScreen === 'main-menu';
  const isGameplay = shell.currentScreen === 'play'
    || shell.currentScreen === 'awakening-ward';
  const isImmersive = isMainMenu
    || isGameplay
    || shell.currentScreen === 'cinematic';
  const showCoreObjective = !isMainMenu
    && !isGameplay
    && shell.currentScreen !== 'psychological-state'
    // The opening puzzle already presents its objective and controls in-flow.
    && shell.currentScreen !== 'opening-recovery'
    && shell.currentScreen !== 'echo-network'
    && shell.currentScreen !== 'settings'
    && shell.currentScreen !== 'profile';

  return (
    <GameViewport
      id="app"
      className="app-root application-shell echo-runtime"
      dir={preferences.locale === 'ar' ? 'rtl' : 'ltr'}
      quality={preferences.quality}
      motion={preferences.motion}
      landscapeRequired={false}
      data-ui-system="cinematic-shell-v2"
    >
      <PremiumAtmosphere />
      <a className="application-shell__skip-link" href="#player-content">
        {preferences.locale === 'en'
          ? 'Skip interface controls to content'
          : 'تجاوز عناصر الواجهة إلى المحتوى'}
      </a>
      <GameSafeArea className="application-shell__safe">
        {!isMainMenu && !isGameplay && (
          <header className="application-shell__topbar">
            {currentCategoryHasMenu ? (
              <button
                type="button"
                className="application-shell__screen-title"
                onClick={() => shell.openNavigation(currentCategory.id)}
                aria-label={preferences.locale === 'en'
                  ? `Open ${currentCategoryCopy.label} menu`
                  : `فتح قائمة ${currentCategoryCopy.label}`}
                title={currentCategoryCopy.description}
              >
                <i data-tone={definition.tone}>
                  <GameIcon id={definition.iconId} />
                  <small>{definition.code}</small>
                </i>
                <span>
                  <small>{currentCategoryCopy.label}</small>
                  <strong>{currentScreenCopy.label}</strong>
                </span>
              </button>
            ) : (
              <div
                className="application-shell__screen-title application-shell__screen-title--static"
                role="group"
                aria-label={currentScreenCopy.description}
              >
                <i data-tone={definition.tone}>
                  <GameIcon id={definition.iconId} />
                  <small>{definition.code}</small>
                </i>
                <span>
                  <small>{currentCategoryCopy.label}</small>
                  <strong>{currentScreenCopy.label}</strong>
                </span>
              </div>
            )}

            <div className="application-shell__chapter">
              <span>{chapterTitle}</span>
              <GameProgress
                value={campaignProgress}
                tone="danger"
                showValue={false}
              />
              <small>{campaignProgress}%</small>
            </div>

            <div className="application-shell__utility">
              {entitlements.snapshot.firstRewardReceived && (
                <PlayerResourceCounters />
              )}
              <AuthStatusButton
                variant="ghost"
                className="application-shell__auth-control"
              />
              <GameTooltip label={preferences.locale === 'en' ? 'Settings' : 'الإعدادات'}>
                <GameButton
                  className="application-shell__utility-control"
                  variant="secondary"
                  leadingIcon={<GameIcon id="screen-settings" />}
                  aria-label={preferences.locale === 'en' ? 'Settings' : 'الإعدادات'}
                  onClick={() => shell.navigate('settings')}
                >
                  {preferences.locale === 'en' ? 'Settings' : 'الإعدادات'}
                </GameButton>
              </GameTooltip>
              <GameTooltip label={preferences.locale === 'en' ? 'Pause menu' : 'قائمة الإيقاف'}>
                <GameButton
                  className="application-shell__utility-control"
                  variant="ghost"
                  leadingIcon={<GameIcon id="utility-pause" />}
                  aria-label={preferences.locale === 'en' ? 'Pause menu' : 'قائمة الإيقاف'}
                  onClick={shell.openPause}
                >
                  {preferences.locale === 'en' ? 'Pause' : 'إيقاف'}
                </GameButton>
              </GameTooltip>
            </div>
          </header>
        )}

        <main
          id="player-content"
          className="application-shell__stage"
          data-fullscreen={isImmersive}
          data-gameplay={isGameplay}
          data-has-objective={showCoreObjective}
        >
          {showCoreObjective && (
            <CoreObjectiveCard
              compact={shell.currentScreen === 'puzzles' || shell.currentScreen === 'memories'}
            />
          )}
          <Suspense
            fallback={(
              <GameLoadingScreen
                fullscreen={false}
                title="11:11"
                 message={preferences.locale === 'en' ? 'Preparing the display channel' : 'تهيئة قناة العرض'}
              />
            )}
          >
            <ScreenTransition screenId={shell.currentScreen}>
              <Screen />
            </ScreenTransition>
          </Suspense>
        </main>

        {!isMainMenu && !isGameplay && visiblePrimaryNavigation.length > 0 && (
          <nav
            className="application-shell__navigation"
             aria-label={preferences.locale === 'en' ? 'Primary navigation' : 'التنقل الرئيسي'}
          >
             {visiblePrimaryNavigation.map((category) => {
               const categoryCopy = localizedCategory(preferences.locale, category);
               return (
               <button
                key={category.id}
                type="button"
                data-navigation-category={category.id}
                data-active={currentCategory.id === category.id}
                data-tone={category.tone}
                onClick={() => {
                  const screens = getCategoryScreens(category.id)
                    .filter((screen) => entitlements.accessibleScreens.includes(screen.id));
                  if (
                    currentCategory.id === category.id
                    && screens.length > 1
                  ) {
                    shell.openNavigation(category.id);
                    return;
                  }
                  shell.navigate(category.landingScreenId);
                }}
                 aria-label={`${categoryCopy.label}: ${categoryCopy.description}${
                   category.id === 'memory' && unviewedManhwaPages > 0
                     ? preferences.locale === 'en'
                       ? `, ${unviewedManhwaPages} new Manhwa page${unviewedManhwaPages === 1 ? '' : 's'}`
                       : `، ${unviewedManhwaPages} صفحة مانهوا جديدة`
                     : ''
                 }`}
                 title={categoryCopy.description}
              >
                <GameIcon id={category.iconId} />
                 <span>{categoryCopy.shortLabel}</span>
                {category.id === 'memory' && unviewedManhwaPages > 0 && (
                  <i
                    className="application-shell__navigation-badge"
                    aria-hidden="true"
                  >
                    {unviewedManhwaPages}
                  </i>
                )}
               </button>
               );
             })}
          </nav>
        )}
      </GameSafeArea>

      <GameDrawer
        open={shell.navigationCategory !== null}
        onClose={shell.closeNavigation}
         title={openCategoryCopy.label}
        side="end"
        tone={openCategory.tone}
      >
        <div className="application-shell__drawer-intro">
          <GameIconLabel
            iconId={openCategory.iconId}
             label={openCategoryCopy.label}
             description={openCategoryCopy.description}
          />
        </div>
        <div className="application-shell__drawer-list">
           {categoryScreens.map((screen) => {
             const screenCopy = localizedScreen(preferences.locale, screen);
             return (
             <GameButton
              key={screen.id}
              variant={
                shell.currentScreen === screen.id
                  ? 'secondary'
                  : 'ghost'
              }
              fullWidth
              leadingIcon={<GameIcon id={screen.iconId} />}
              onClick={() => shell.navigate(screen.id)}
            >
              <span className="application-shell__drawer-item-copy">
                 <strong>{screenCopy.label}</strong>
                 <small>{screenCopy.description}</small>
              </span>
             </GameButton>
             );
           })}
        </div>
      </GameDrawer>

      {shell.routeAccessNotice && (() => {
        const copy = experienceLockCopy(
          shell.routeAccessNotice.reason,
          preferences.locale,
        );
        return (
          <GameModal
            open
            onClose={shell.dismissRouteAccessNotice}
            eyebrow={copy.eyebrow}
            title={copy.title}
            description={copy.detail}
            tone="memory"
            footer={(
              <GameButton onClick={shell.dismissRouteAccessNotice}>
                {copy.action}
              </GameButton>
            )}
          />
        );
      })()}

      <EchoTransformationCinematic />

      <GameModal
        open={shell.pauseOpen}
        onClose={shell.closePause}
        eyebrow={isGameplay
          ? 'AWAKENING WARD // AUTO-SAVED'
          : 'GAME STATE // AUTO-SAVED'}
        title="قائمة الإيقاف"
        tone="danger"
      >
        <div className="application-shell__pause-actions">
          <GameButton
            size="lg"
            fullWidth
            leadingIcon={<GameIcon id="utility-resume" />}
            onClick={shell.closePause}
          >
            <span className="application-shell__pause-copy">
              <strong>استمرار اللعبة</strong>
              <small>العودة مباشرة إلى التجربة</small>
            </span>
          </GameButton>
          {isGameplay && (
            <GameButton
              variant="secondary"
              fullWidth
              leadingIcon={<GameIcon id="category-story" />}
              onClick={shell.goBack}
            >
              <span className="application-shell__pause-copy">
                <strong>العودة إلى واجهة القصة</strong>
                <small>حفظ تقدم الغرفة ومغادرة المشهد</small>
              </span>
            </GameButton>
          )}
          <GameButton
            variant="secondary"
            fullWidth
            leadingIcon={<GameIcon id="screen-settings" />}
            onClick={() => shell.navigate('settings')}
          >
            <span className="application-shell__pause-copy">
              <strong>الإعدادات</strong>
              <small>الصوت والجودة وإمكانية الوصول</small>
            </span>
          </GameButton>
          {!isGameplay && entitlements.accessibleScreens.includes('leaderboard') && <GameButton
            variant="ghost"
            fullWidth
            leadingIcon={<GameIcon id="screen-leaderboard" />}
            onClick={() => shell.navigate('leaderboard')}
          >
            <span className="application-shell__pause-copy">
              <strong>الترتيب العالمي</strong>
              <small>عرض ترتيبك ومستواك وإجمالي نقاط الخبرة</small>
              </span>
            </GameButton>
          }
          <GameButton
            variant="ghost"
            fullWidth
            leadingIcon={<GameIcon id="screen-main-menu" />}
            onClick={() => shell.navigate('main-menu')}
          >
            <span className="application-shell__pause-copy">
              <strong>{isGameplay
                ? 'العودة إلى القائمة الرئيسية'
                : 'القائمة الرئيسية'}</strong>
              <small>{isGameplay
                ? 'سيبقى تقدم الغرفة محفوظًا'
                : 'العودة إلى نقطة بدء الرحلة'}</small>
            </span>
          </GameButton>
        </div>
      </GameModal>
      <AchievementPresentationOverlay />
      <DemoExperienceLayer />
    </GameViewport>
  );
}
