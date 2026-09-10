import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, it } from 'node:test';
import { enqueueSerializedDraftSave } from '../features/story-puzzles/storyPuzzleDraftQueue';

function source(relativePath: string): string {
  return readFileSync(resolve(process.cwd(), relativePath), 'utf8');
}

describe('Story puzzle visual asset accessibility', () => {
  it('keeps image reconstruction recoverable when its visual source cannot load', () => {
    const screen = source('src/features/screens/PuzzleScreen.tsx');
    const stylesheet = source('src/features/screens/story-puzzle-experience.css');

    assert.match(screen, /function usePuzzleVisualAsset\(source\?: string\)/);
    assert.match(screen, /const probe = new Image\(\);/);
    assert.match(screen, /probe\.onload = \(\) =>/);
    assert.match(screen, /probe\.onerror = \(\) =>/);
    assert.match(screen, /assetStatus === 'failed'/);
    assert.match(screen, /Memory record unavailable/);
    assert.match(screen, /No attempt can be sent until the record returns/);
    assert.match(screen, /disabled=\{interactionDisabled\}/);
    assert.match(screen, /assetStatus === 'failed'\s*\? imageCopy\.unavailableDetail/);
    assert.match(screen, /!actionReadiness\.ready/);
    assert.match(screen, /onVisualAssetStateChange=\{visualAssetContext \? reportVisualAssetState : undefined\}/);
    assert.match(stylesheet, /\.story-puzzle-visual-fallback \{ display: grid;/);
    assert.match(stylesheet, /\.story-puzzle-visual-fallback button \{[\s\S]*?min-block-size: 3rem;/);
  });

  it('maps visual-forensics points by their named grid coordinates and provides a text evidence view', () => {
    const screen = source('src/features/screens/PuzzleScreen.tsx');
    const stylesheet = source('src/features/screens/story-puzzle-experience.css');

    assert.match(screen, /function forensicPointPosition\(id: string, index: number\)/);
    assert.match(screen, /\^\(\[xyz\]\)\(\[123\]\)\$\/i/);
    assert.match(screen, /style=\{\{ '--point-x': position\.x, '--point-y': position\.y \} as CSSProperties\}/);
    assert.match(screen, /story-forensics-board__view-toggle/);
    assert.match(screen, /Show text evidence cards/);
    assert.match(screen, /data-view=\{usesEvidenceList \? 'evidence' : 'map'\}/);
    assert.match(screen, /Text evidence cards remain available/);
    assert.match(stylesheet, /\.story-forensics-board__record\[data-view="map"\] \.story-forensics-board__points > button \{ position: absolute; top: var\(--point-y\); left: var\(--point-x\);/);
    assert.match(stylesheet, /\.story-forensics-board__record\[data-view="evidence"\] \.story-forensics-board__points \{ display: grid;/);
    assert.match(stylesheet, /\.story-forensics-board__record\[data-view="evidence"\] \.story-forensics-board__points > button \{[\s\S]*?min-block-size: 4\.15rem;/);
  });

  it('keeps the non-drag click path and does not import server-side puzzle answers', () => {
    const screen = source('src/features/screens/PuzzleScreen.tsx');

    assert.match(screen, /Dragging is an optional desktop enhancement\./);
    assert.match(screen, /aria-pressed=\{selectedPiece === pieceId\}/);
    assert.doesNotMatch(screen, /_storyPuzzleDefinitions/);
    assert.doesNotMatch(screen, /correctAnswer|rawSolution|targetFrequency|targetChannel/);
  });

  it('makes the opening cover a real touch/mouse drag puzzle with a reduced-motion fallback', () => {
    const screen = source('src/features/opening-recovery/OpeningRecoveryScreen.tsx');
    const stylesheet = source('src/features/opening-recovery/opening-recovery.css');

    assert.match(screen, /onPointerDown=\{\(event\) => handlePiecePointerDown\(event, slot\)\}/);
    assert.match(screen, /document\.elementFromPoint\(clientX, clientY\)/);
    assert.match(screen, /data-opening-piece-slot=\{slot\}/);
    assert.match(screen, /data-drag-over=\{/);
    assert.match(screen, /completeOpeningRecovery\(order\)/);
    assert.match(screen, /const verifyDisabled =/);
    assert.doesNotMatch(screen, /if \(!solved \|\| status === 'verifying'/);
    assert.match(stylesheet, /touch-action: none;/);
    assert.match(stylesheet, /opening-piece-drop-target/);
    assert.match(stylesheet, /\[data-motion="reduced"\] \.opening-recovery__piece/);
  });

  it('hands the verified composition into one recoverable cinematic and the authored room', () => {
    const transition = source('src/features/opening-recovery/ScreenBreakRuntime.tsx');
    const recovery = source('src/features/opening-recovery/OpeningRecoveryScreen.tsx');
    const roomLoader = source('src/features/gameplay/components/RoomLoader.tsx');
    const director = source('src/features/cinematics/components/CinematicDirector.tsx');

    assert.match(transition, /part-1-opening-v2\.webm/);
    assert.match(transition, /part-1-opening-v2-poster\.webp/);
    assert.match(transition, /onError=\{\(\) => setPlayback\('error'\)\}/);
    assert.doesNotMatch(transition, /setTimeout\(finish, 28000\)/);
    assert.match(transition, /screen-break-runtime__fracture/);
    assert.match(recovery, /opening_room_cinematic_seen/);
    assert.match(roomLoader, /A decorative GLB cannot replace it/);
    assert.doesNotMatch(roomLoader, /useGLTF\(/);
    assert.match(director, /completionRef\.current\(\), 2000/);
    assert.doesNotMatch(director, /onError=\{onComplete\}/);
    assert.doesNotMatch(director, /!videoRef\.current\?\.src/);
  });

  it('automatically requests opening verification without fabricating a development receipt', () => {
    const recovery = source('src/features/opening-recovery/OpeningRecoveryScreen.tsx');
    assert.match(recovery, /if \(submissionPendingRef\.current\) return/);
    assert.match(recovery, /response\.storyState\.openingCoverPuzzleCompleted !== true/);
    assert.match(recovery, /if \(solved && status === 'idle' && !storyState\?\.openingCoverPuzzleCompleted\)/);
    assert.doesNotMatch(recovery, /Simulating success|mockState|import\.meta\.env\.DEV/);
    assert.doesNotMatch(recovery, /if \(solved && puzzleInteractive\)/);
    assert.doesNotMatch(recovery, /media\.addEventListener\('change'/);
  });

  it('flushes a local draft before a confirmed hint purchase and does not rehydrate the active puzzle on its snapshot response', () => {
    const screen = source('src/features/screens/PuzzleScreen.tsx');
    const openHint = screen.slice(
      screen.indexOf('const openHint = async'),
      screen.indexOf('const complete = async'),
    );

    assert.match(screen, /const hydratedPuzzleId = useRef<string \| null>\(null\);/);
    assert.match(screen, /if \(hydratedPuzzleId\.current === selectedPuzzle\.id\) return;/);
    assert.match(screen, /hydratedPuzzleId\.current = selectedPuzzle\.id;/);
    assert.match(openHint, /const persistedDraft = normalizePuzzleDraft\(selectedPuzzle, draft\);[\s\S]*?await enqueueDraftSave\(selectedPuzzle\.id, persistedDraft\);[\s\S]*?await actions\.unlockHint\(selectedPuzzle\.id, index, locale\);/);
    assert.doesNotMatch(openHint, /defaultDraft\(|setDraftResetVersion/);
    assert.match(screen, /function HintPurchaseDialog\(/);
    assert.match(screen, /role="dialog"/);
    assert.match(screen, /aria-modal="true"/);
    assert.match(screen, /onClick=\{\(\) => setPendingHintIndex\(index\)\}/);
    assert.doesNotMatch(screen, /onClick=\{\(\) => void openHint\(index\)\}/);
  });

  it('never presents a malformed hint price as free or lets it reset the current draft', () => {
    const screen = source('src/features/screens/PuzzleScreen.tsx');

    assert.match(screen, /const priced = Number\.isSafeInteger\(cost\) && cost > 0;/);
    // The unavailable label is localized through screenCopy; verify the
    // player-facing branch rather than pinning the surrounding JSX shape.
    assert.ok(screen.includes('screenCopy.hint(index + 1)'));
    assert.ok(screen.includes('priced ? `${cost} ◉` : screenCopy.unavailable'));
    assert.match(screen, /unavailable: 'UNAVAILABLE',/);
    assert.match(screen, /unavailable: 'غير متاح',/);
    assert.match(screen, /selectedEntry\.status === 'completed' \? <p className="story-puzzle-hints__state">\{screenCopy\.hintCompleted\}<\/p>/);
    assert.match(screen, /const insufficientCoins = priced && cost > balance;/);
    assert.match(screen, /screenCopy\.hintNeedCoins\(cost - balance\)/);
    assert.match(screen, /onClick=\{\(\) => continueToObjective\(nextObjective\)\}/);
    assert.doesNotMatch(screen, /cost === 0 \? 'FREE'/);
  });

  it('states base verified coins in the reward moment, not only a perfect bonus', () => {
    const screen = source('src/features/screens/PuzzleScreen.tsx');
    assert.match(screen, /coins: 'Verified coins'/);
    assert.match(screen, /<div><dt>\{copy\.coins\}<\/dt><dd>\+\{reward\.coinsGranted\} ◉<\/dd><\/div>/);
    assert.match(screen, /Server-verified receipt/);
  });

  it('serializes autosave, hint, and completion writes so a stale draft cannot replace a receipt', () => {
    const screen = source('src/features/screens/PuzzleScreen.tsx');
    const openHint = screen.slice(
      screen.indexOf('const openHint = async'),
      screen.indexOf('const complete = async'),
    );
    const complete = screen.slice(
      screen.indexOf('const complete = async'),
      screen.indexOf('const advanceStage = async'),
    );

    assert.match(screen, /const draftSaveChain = useRef<Promise<unknown>>\(Promise\.resolve\(\)\);/);
    assert.match(screen, /enqueueSerializedDraftSave\(\s*draftSaveChain,\s*\(\) => actions\.saveDraft\(puzzleId, persistedDraft, locale\),\s*\)/);
    assert.match(screen, /saveTimer\.current = window\.setTimeout\(\(\) => \{\s*saveTimer\.current = null;\s*void enqueueDraftSave\(puzzleId, normalizedDraft\);/);
    assert.match(openHint, /terminalPuzzleAction\.current = true;[\s\S]*?await enqueueDraftSave\(selectedPuzzle\.id, persistedDraft\);[\s\S]*?await actions\.unlockHint\(selectedPuzzle\.id, index, locale\);/);
    assert.match(complete, /terminalPuzzleAction\.current = true;[\s\S]*?await enqueueDraftSave\(selectedPuzzle\.id, submissionDraft\);[\s\S]*?await actions\.complete\(selectedPuzzle\.id, submissionDraft, locale\);/);
    assert.match(complete, /finally \{\s*terminalPuzzleAction\.current = false;\s*setBusy\(false\);\s*\}/);
  });

  it('keeps a deferred autosave ahead of the current draft and terminal receipt', async () => {
    const chain: { current: Promise<unknown> } = { current: Promise.resolve() };
    const order: string[] = [];
    let releaseAutosave: (value: string) => void = () => undefined;
    const deferredAutosave = new Promise<string>((resolveAutosave) => {
      releaseAutosave = resolveAutosave;
    });

    const autosave = enqueueSerializedDraftSave(chain, async () => {
      order.push('autosave');
      return deferredAutosave;
    });
    const currentDraft = enqueueSerializedDraftSave(chain, async () => {
      order.push('current-draft');
      return 'current-draft';
    });
    const receipt = currentDraft.then(async (saved) => {
      if (!saved) return null;
      order.push('completion');
      return 'receipt';
    });

    await new Promise<void>((resolveTick) => setTimeout(resolveTick, 0));
    assert.deepEqual(order, ['autosave']);
    releaseAutosave('old-draft');
    assert.equal(await autosave, 'old-draft');
    assert.equal(await currentDraft, 'current-draft');
    assert.equal(await receipt, 'receipt');
    assert.deepEqual(order, ['autosave', 'current-draft', 'completion']);
  });
});
