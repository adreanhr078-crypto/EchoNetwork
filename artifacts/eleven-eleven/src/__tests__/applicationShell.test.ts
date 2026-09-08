import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, it } from 'node:test';
import {
  createDashboardReadModel,
  createDialogueScreenReadModel,
  createMemoryScreenReadModel,
  createPuzzleScreenReadModel,
} from '../application/ui/gameUiReadModels';
import {
  createPsychologicalStateReadModel,
} from '../application/ui/psychologicalStateReadModel';
import {
  createEchoPresentationReadModel,
} from '../application/ui/echoPresentationReadModel';
import {
  GAME_SCREEN_DEFINITIONS,
  GAME_SCREEN_REGISTRY,
} from '../app/shell/screenRegistry';
import { useShellStore } from '../app/shell/shellStore';
import {
  AWAKENING_WARD_ENABLED,
  OPENING_ROOM_3D_ENABLED,
  resolveFeatureGatedScreen,
} from '../app/config/featureFlags';
import {
  getCategoryScreens,
  NAVIGATION_CATEGORIES,
  PRIMARY_NAVIGATION_CATEGORIES,
} from '../app/shell/navigationRegistry';
import { useGameStore } from '../stores/gameStore';
import {
  GAME_ICON_REGISTRY,
} from '../ui/icons';
import { PUZZLE_HUB_MODES } from '../features/puzzle-hub/puzzleHubModes';
import {
  ECHO_PRESENTATION_ASSETS,
  ENVIRONMENT_PRESENTATION_ASSETS,
} from '../ui/presentation/visualAssets';

describe('Application Shell', () => {
  it('registers each screen once and keeps the priority flow available', () => {
    const screens = Object.values(GAME_SCREEN_REGISTRY);
    assert.equal(
      new Set(screens.map((screen) => screen.id)).size,
      screens.length,
    );
    assert.equal(screens.length, GAME_SCREEN_DEFINITIONS.length);
  });

  it('uses four primary navigation categories and keeps secondary systems reachable', () => {
    assert.deepEqual(
      PRIMARY_NAVIGATION_CATEGORIES.map(({ id }) => id),
      [
        'story',
        'memory',
        'puzzles',
        'network',
      ],
    );

    assert.equal(
      NAVIGATION_CATEGORIES.some(
        (category) => category.id === 'settings' && category.primary === false,
      ),
      true,
    );

    const navigableScreens = PRIMARY_NAVIGATION_CATEGORIES.flatMap((category) => (
      getCategoryScreens(category.id).map(({ id }) => id)
    ));
    assert.equal(
      new Set(navigableScreens).size,
      navigableScreens.length,
    );
    assert.equal(
      navigableScreens.includes('main-menu'),
      false,
    );
    assert.deepEqual(
      getCategoryScreens('story').map(({ id }) => id),
      ['psychological-state'],
    );
    assert.equal(
      NAVIGATION_CATEGORIES.find(({ id }) => id === 'memory')?.label,
      'المانهوا',
    );
    assert.equal(GAME_SCREEN_REGISTRY.memories.label, 'المانهوا');
    assert.match(
      GAME_SCREEN_REGISTRY.memories.description,
      /Manhwa/,
    );
    assert.equal(
      NAVIGATION_CATEGORIES.find(({ id }) => id === 'network')
        ?.landingScreenId,
      'echo-network',
    );
    assert.equal(GAME_SCREEN_REGISTRY['echo-network'].navigation, 'landing');
    assert.equal(
      NAVIGATION_CATEGORIES.find(({ id }) => id === 'progress')
        ?.landingScreenId,
      'leaderboard',
    );
    assert.equal(GAME_SCREEN_REGISTRY.leaderboard.navigation, 'landing');
    assert.equal(GAME_SCREEN_REGISTRY.progress.navigation, 'secondary');
    assert.deepEqual(
      getCategoryScreens('progress').map(({ id }) => id),
      ['leaderboard', 'progress'],
    );
    assert.equal(
      NAVIGATION_CATEGORIES.find(({ id }) => id === 'echo-mind')?.primary,
      false,
    );
    assert.equal(
      NAVIGATION_CATEGORIES.find(({ id }) => id === 'characters')?.primary,
      false,
    );
  });

  it('keeps one Puzzle Hub with three approved Part 1 modes and protects its deep link', () => {
    assert.deepEqual(
      PUZZLE_HUB_MODES.map(({ id }) => id),
      ['story', 'daily', 'weekly'],
    );
    assert.equal(GAME_SCREEN_REGISTRY.puzzles.navigation, 'landing');
    assert.match(GAME_SCREEN_REGISTRY.puzzles.label, /مركز الألغاز/);

    useShellStore.setState({ currentScreen: 'psychological-state' });
    useShellStore.getState().navigate('live-challenges');
    assert.equal(resolveFeatureGatedScreen('live-challenges'), 'puzzles');
    assert.equal(useShellStore.getState().currentScreen, 'main-menu');
    assert.equal(useShellStore.getState().routeAccessNotice?.reason, 'progress-syncing');

    const hubSource = readFileSync(
      resolve(
        process.cwd(),
        'src',
        'features',
        'puzzle-hub',
        'PuzzleHubScreen.tsx',
      ),
      'utf8',
    );
    assert.ok(hubSource.includes('tabIndex={active ? 0 : -1}'));
    assert.ok(hubSource.includes("event.key === 'ArrowLeft'"));
    assert.ok(hubSource.includes("event.key === 'Home'"));
    assert.ok(hubSource.includes("event.key === 'End'"));
  });

  it('keeps live hint purchases sequential and transparent per active stage', () => {
    const source = readFileSync(
      resolve(
        process.cwd(),
        'src',
        'features',
        'live-challenges',
        'LiveChallengesScreen.tsx',
      ),
      'utf8',
    );
    assert.ok(source.includes('index > daily.hintsUsed'));
    assert.ok(source.includes('index > weekly.currentStageHintsUsed'));
    assert.ok(source.includes('LIVE_HINT_COSTS[index]'));
    const networkSource = readFileSync(
      resolve(process.cwd(), 'src', 'features', 'echo-network', 'EchoNetworkScreen.tsx'),
      'utf8',
    );
    assert.ok(networkSource.includes('experienceEntitlements.networkModes'));
    assert.equal(networkSource.includes('ActivityDirectorPanel'), false);
    assert.equal(networkSource.includes('setRequestedPuzzleMode'), false);
  });

  it('reads Manhwa badges and player counters from canonical progression', () => {
    const shellSource = readFileSync(
      resolve(
        process.cwd(),
        'src',
        'app',
        'shell',
        'ApplicationShell.tsx',
      ),
      'utf8',
    );
    const countersSource = readFileSync(
      resolve(
        process.cwd(),
        'src',
        'app',
        'shell',
        'PlayerResourceCounters.tsx',
      ),
      'utf8',
    );

    assert.ok(shellSource.includes('getCanonicalManhwaBadgeCount'));
    assert.ok(shellSource.includes('state.progressionState'));
    assert.equal(shellSource.includes('state.unlockedManhwaPageIds'), false);
    assert.equal(shellSource.includes('state.viewedManhwaPageIds'), false);
    assert.ok(countersSource.includes(
      'state.progressionState.resources.coins',
    ));
    assert.ok(countersSource.includes(
      'state.progressionState.resources.memoryShards.spendableBalance',
    ));
    assert.equal(countersSource.includes('state.currency'), false);
    assert.equal(
      countersSource.includes('state.collectedMemoryFragments'),
      false,
    );
  });

  it('keeps the legacy night runtime out of the active application boot path', () => {
    const appSource = readFileSync(
      resolve(process.cwd(), 'src', 'App.tsx'),
      'utf8',
    );
    const runtimeSource = readFileSync(
      resolve(
        process.cwd(),
        'src',
        'app',
        'shell',
        'GameRuntimeBridge.tsx',
      ),
      'utf8',
    );

    for (const legacyImport of [
      'eleven-theme.css',
      'dashboard.css',
      'backgrounds.css',
      'EchoPortrait.css',
    ]) {
      assert.equal(appSource.includes(legacyImport), false);
    }
    for (const legacyRuntime of [
      'AnimationSystem',
      'AchievementToast',
      'CinematicMode',
      'advanceTime()',
      'useAudioSystem',
    ]) {
      assert.equal(runtimeSource.includes(legacyRuntime), false);
    }
  });

  it('derives the psychological state screen from canonical Echo values', () => {
    const state = useGameStore.getState();
    const model = createPsychologicalStateReadModel(state, 'trust');

    assert.equal(model.dominantLabel, 'الثقة');
    assert.equal(model.channels.length, 6);
    assert.equal(
      model.channels.find(({ id }) => id === 'trust')?.value,
      state.echo.personality.trust,
    );
  });

  it('reveals Echo presentation only from server-issued Canon receipts', () => {
    const state = useGameStore.getState();
    assert.equal(createEchoPresentationReadModel(state).form, 'normal');

    const transformedState = {
      ...state,
      progressionState: structuredClone(state.progressionState),
    };
    transformedState.progressionState.story.authoritative.completedChapterIds = [
      'chapter_3',
    ];
    transformedState.progressionState.story.authoritative.canonEventReceipts = [{
      eventId: 'manhwa_chapter_04_black_coronation',
      eventVersion: 1,
      sourceType: 'manhwa',
      sourceId: 'chapter_4',
      sourcePageId: 'manhwa_ch04_page_02',
      sourcePageNumber: 56,
      reachedAt: '2026-08-09T11:11:00.000Z',
    }];
    // The receipt belongs to a retired, unpublished event and must not turn
    // into a presentation state in the current Part 1 runtime.
    assert.equal(createEchoPresentationReadModel(transformedState).form, 'normal');

    const tamperedState = {
      ...state,
      narrative: {
        ...state.narrative,
        activeFlags: {
          ...state.narrative.activeFlags,
          'echo.form.corrupted': true,
        },
      },
    };
    assert.equal(createEchoPresentationReadModel(tamperedState).form, 'normal');
  });

  it('keeps the compact mission dock in phone document flow so it cannot cover a puzzle', () => {
    const shellSource = readFileSync(
      resolve(process.cwd(), 'src', 'app', 'shell', 'ApplicationShell.tsx'),
      'utf8',
    );
    const shellStyles = readFileSync(
      resolve(process.cwd(), 'src', 'app', 'shell', 'application-shell.css'),
      'utf8',
    ).replace(/\r\n/g, '\n');
    const objectiveStyles = readFileSync(
      resolve(process.cwd(), 'src', 'features', 'player-journey', 'core-objective-card.css'),
      'utf8',
    ).replace(/\r\n/g, '\n');

    assert.ok(shellSource.indexOf('<CoreObjectiveCard') < shellSource.indexOf('<Suspense'));
    assert.ok(objectiveStyles.includes('.core-objective-card[data-compact] {\n    position: relative;'));
    assert.ok(shellStyles.includes('.application-shell__stage[data-has-objective="true"] {'));
    assert.ok(shellStyles.includes('padding-block-start: 0;'));
  });

  it('maps every screen icon to a system, action, and label', () => {
    for (const screen of GAME_SCREEN_DEFINITIONS) {
      const icon = GAME_ICON_REGISTRY[screen.iconId];
      assert.ok(icon, `Missing icon ${screen.iconId}`);
      assert.ok(icon.systemId);
      assert.ok(icon.actionId);
      assert.ok(icon.label.ar);
      assert.ok(icon.description.ar);
      assert.ok(icon.tooltip.ar);
      assert.equal(
        (icon.screenIds as readonly string[]).includes(screen.id),
        true,
        `${screen.iconId} is not linked to ${screen.id}`,
      );
    }

    const categoryActions = NAVIGATION_CATEGORIES.map((category) => (
      GAME_ICON_REGISTRY[category.iconId].actionId
    ));
    assert.equal(
      new Set(categoryActions).size,
      categoryActions.length,
      'Primary navigation actions must be unique',
    );
  });

  it('derives the dashboard from canonical domain state', () => {
    const state = useGameStore.getState();
    const model = createDashboardReadModel(state);

    assert.equal(model.chapter.id, state.progression.currentChapterId);
    assert.equal(
      model.echoStatus.metrics.humanity,
      state.progressionState.echo.humanity,
    );
    assert.equal(
      model.echoStatus.metrics.memoryStability,
      state.progressionState.echo.memoryStability,
    );
    assert.equal(
      model.decisions.length,
      state.narrative.decisionHistory.slice(-5).length,
    );
    assert.equal(
      model.cinematic.completedEpisodes,
      state.cinematic.completedEpisodeIds.length,
    );
  });

  it('keeps puzzle and memory registries empty and editor-ready', () => {
    const state = useGameStore.getState();
    const memories = createMemoryScreenReadModel(state);
    const dialogue = createDialogueScreenReadModel(state);

    assert.equal(memories.isAuthoredContentEmpty, true);
    assert.deepEqual(memories.items, []);
    assert.equal(memories.totalFragmentCount, 0);
    assert.deepEqual(dialogue.availableDefinitions, []);
    assert.equal(dialogue.node, null);
    assert.equal(dialogue.hasAuthoredContent, false);
    assert.equal(dialogue.speakerName, 'Echo');
  });

  it('adapts the existing puzzle runtime without creating content in UI', () => {
    const state = useGameStore.getState();
    const puzzlesBefore = state.puzzles.length;
    const model = createPuzzleScreenReadModel(state);

    assert.equal(useGameStore.getState().puzzles.length, puzzlesBefore);
    assert.equal(
      model.chapterPuzzles.every(
        (puzzle) => puzzle.chapterId === state.progression.currentChapterId,
      ),
      true,
    );
  });

  it('keeps Echo artwork as a replaceable presentation asset', () => {
    for (const asset of [
      ECHO_PRESENTATION_ASSETS.portrait,
      ECHO_PRESENTATION_ASSETS.fullBodyNormal,
      ECHO_PRESENTATION_ASSETS.fullBodyCorrupted,
    ]) {
      assert.equal(
        existsSync(resolve(
          process.cwd(),
          'public',
          asset.replace(/^\//, ''),
        )),
        true,
      );
    }
    assert.equal(ECHO_PRESENTATION_ASSETS.fallbackLabel, 'Echo');
  });

  it('keeps cinematic environments outside narrative content data', () => {
    for (const asset of Object.values(ENVIRONMENT_PRESENTATION_ASSETS)) {
      assert.equal(
        existsSync(resolve(
          process.cwd(),
          'public',
          asset.replace(/^\//, ''),
        )),
        true,
      );
    }
  });

  it('keeps the legacy ward dormant while the authoritative opening room owns Play', () => {
    assert.equal(OPENING_ROOM_3D_ENABLED, false);
    assert.equal(AWAKENING_WARD_ENABLED, false);
    useShellStore.setState({
      currentScreen: 'psychological-state',
      previousScreen: null,
      navigationCategory: null,
      pauseOpen: false,
    });

    useShellStore.getState().navigate('play');
    assert.equal(resolveFeatureGatedScreen('play'), 'play');
    assert.equal(useShellStore.getState().currentScreen, 'main-menu');
    assert.equal(useShellStore.getState().routeAccessNotice?.reason, 'progress-syncing');
  });
});
