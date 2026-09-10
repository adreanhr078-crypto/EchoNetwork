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
