# Opening recovery execution audit

Status: IN PROGRESS — not a release approval.

## Acceptance journey

Real player login → composition puzzle → authoritative receipt → visible fracture → playable cinematic → controllable Echo → room evidence → verified escape.

## Architecture decisions

- Keep the existing server as sole progression/reward authority and Three/R3F as the gameplay runtime.
- Keep one submission trigger; a failed submission must wait for explicit retry.
- Cinematic playback must end through media completion or explicit player choice, never a wall-clock timeout or a silently swallowed playback error.
- Presentation and asset replacement must preserve named room interactions and collision.
- Authored character fidelity, animation, and room production remain separate gates; a running prototype does not satisfy them.

## Visual design review

The current transition contains an oversized central HUD over the character and no actual fracture. Use bounded 2.5D fragments of the approved cover with React/CSS, followed by the existing cinematic media. Preserve the established dark/violet visual contract, keep controls in live HTML, preserve image aspect ratios, and provide a static reduced-motion path. This repair reuses existing approved artwork; no new concept image or icon is needed.

## Execution order

1. Repair duplicate verification and resize-induced puzzle resets; test errors and retry.
2. Implement visible fracture and recoverable, accessible playback; inspect in Edge.
3. Audit/re-edit source video chronology and actual final decoded frames.
4. Audit the live Echo rig, animations, camera, collisions, and escape bindings; author replacement assets only against inspected Manhwa references.
5. Play the complete server-backed journey; verify bilingual layouts, reduced motion, mute, loading failures, refresh, and performance.
6. Run quality gate, correct defects, repeat affected checks, and record remaining limitations honestly.

## Evidence at start

- Worktree clean at commit 4731772.
- Puzzle has LTR board, but two auto-submit effects; the second also submits in error state.
- ScreenBreakRuntime has no rendered shards, uses unrelated Echo Mind sound preference, and auto-finishes after 28 seconds or a media error.
- No current-turn proof of completed room escape or Manhwa-quality 3D assets.

No entire-game quality claim may be inferred from a passing code test.

## First repair pass

- Removed the duplicate auto-submit effect that retried errors without user action.
- Kept piece count stable across viewport changes; retained the existing LTR image board.
- Distinguished server alignment/session rejection from generic request failure.
- Replaced internal receipt terminology with player-facing memory language.
- Added 24 bounded animated cover fragments, preserved video aspect ratio, removed the central text overlay and forced 28-second completion, and made media errors explicitly retryable.
- Used the shell audio preference and native media controls; reduced motion offers an explicit continue action.

### Observed evidence

Isolated Edge component test (not a server-backed journey): 24 fragments mounted; media reached time 2.080182 with decoded dimensions 1920×1080 and reported duration 24.25; skip invoked completion once. Inspected fracture and video screenshots. Full ffprobe frame read found 582 frames. This proves neither shot continuity nor correct final awakening/stand-up content.

### Outstanding acceptance gaps

- Fracture now reads the live board rectangle; this refinement needs an actual puzzle-route screenshot comparison.
- Added a 20-second loading error fallback (no automatic completion). Complete dialog focus containment, media failure and reduced-motion browser cases still need verification.
- Full account → puzzle → movie → room → verified escape test remains unverified.
- Final montage continuity, live Echo fidelity, authored animation, room art, and target-device performance remain incomplete.
- No claim of Genshin-equivalent quality or completed game is made.

## 2026-09-10 continuation: cinematic interaction gate

Visual design: retain the existing artwork, fracture, palette, and native video controls. Use an HTML modal dialog to make background controls inert and preserve keyboard focus. Add an explicit localized play/resume control and keep retry visible for media failures. No new decorative asset is needed for this interaction repair.

- Replaced the ARIA-only modal with a native modal dialog; Escape/skip still complete presentation once. Restore the previous connected focus target on cleanup.
- Guard pending play rejections across retries, timeout, completion, and unmount so a stale promise cannot overwrite the current error state.
- Keep the Reduced Motion path static and make the skip target at least 44 pixels high.
- Added an isolated browser fixture and eight Edge behavior tests. These do not seed authentication, rewards, or progression, and do not represent a complete gameplay test.
- First Edge run found focus restoration broken by React autofocus. Removed that premature autofocus and explicitly restore the prior target; rerun passed all eight tests.
- Updated the older source-format assertion; actual missing-media/retry behavior is now tested in Edge.

Observed commands and evidence:

- `npm run agent:preflight`: PASS.
- `npm run agent:postflight`: PASS after repair; 587 foundation tests, content, TypeScript, and production build passed. Existing build warnings remain for chunks above 500 kB and plugin timings.
- `npx playwright test --project=edge e2e/screen-break.spec.ts`: 8 PASS, including Arabic/English at 1440x900, 844x390, 390x844; Reduced Motion, modal focus, Escape, error/retry, muted video decode, pause/resume, and natural completion. This is Edge viewport coverage, not physical phone performance.
- Interactive Edge inspection displayed the Arabic skip control and the actual laboratory footage inside the modal.
- `npm run blender:doctor`: Blender 5.2.1 LTS available. Blender re-import of `public/assets/characters/echo.glb` succeeded structurally but reported **2 meshes and 0 actions**. The live asset fails the required animated-character acceptance bar.
- `npm run godot:doctor` and `npm run godot:smoke`: PASS, Godot 4.7.2. This remains an isolated engine proof, not a runtime migration.
- FFprobe reports the current movie as VP9/Opus, 1920x1080, 24 fps, 24.25 seconds, 7,392,202 bytes. Full FFmpeg decode succeeded. Inspected sampled frames and the final decoded frame: it ends on the fractured-glass reference, not an authored awakening/stand-up. Source imagery includes embedded E-01 labels, which are not the approved EX-011 skin mark. No new final movie has been approved.

Overall production status remains IN PROGRESS. Antigravity's character candidate, the missing cinematic shot, authored live awakening, full server-backed escape, and target-device performance are not accepted by these results.
