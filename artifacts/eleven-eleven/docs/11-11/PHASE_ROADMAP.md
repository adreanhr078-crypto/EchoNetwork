# Production Phase Roadmap

Do not skip phases. Do not build Phase 5 features until Phase 3 is proven.

## Phase 2.1 — Stabilization (Current Phase)
**Objective**: Fix the existing codebase to pass the Phase 2 quality gate.
- [ ] Fix `devFullStack.test.ts` realtime expectation failure.
- [ ] Fix `campaignAccessibility.test.ts` CSS assertion failure.
- [x] Fix UTF-8 mojibake in `playerExperienceEntitlements.ts` (Done).
- [ ] Ensure full `npm run check` and `agent:postflight` pass cleanly.

## Phase 3.0 — R3F Engine Proof & First Environment
**Objective**: Validate Three/R3F as the final 3D runtime.
- Design modular `RoomDefinition` system with lazy GLB loading.
- Create the "Opening Lab" environment in Blender (based on Manhwa reference).
- Wire the Screen Break transition to seamlessly enter the 3D room.
- Profile and optimize performance.

## Phase 3.1 — Echo Character Production
**Objective**: Create the premium anime protagonist.
- Model, rig, and texture Echo in Blender.
- Implement idle, walk, run, and interaction animations.
- Integrate into R3F with a state-machine `AnimationController`.

## Phase 3.2 — Movement & Interactions
**Objective**: Make the 3D space playable.
- Third-person character controller (touch/keyboard/gamepad).
- Advanced camera system (wall occlusion, follow, orbit).
- Interaction system (raycasting, proximity UI).

## Phase 3.3 — The Guide Character
**Objective**: Companion system.
- Model, rig, and animate the floating Guide.
- Wire to `eleven-eleven-echo-agent` WebSocket for deterministic behavior.

## Phase 3.4 — Room 1 Vertical Slice
**Objective**: The first complete gameplay loop.
- Explore Room 1 -> Inspect Clues -> Recover Memory -> Solve Environmental Puzzle -> Unlock Door -> Trigger Cinematic.

## Phase 4.0 — Cinematic Framework
**Objective**: Story delivery.
- Build `CinematicDirector` to play data-driven sequences.
- Produce Blender-rendered MP4/WebM sequences for major beats.

## Phase 5.0 — Pre-Contract Combat
**Objective**: Human survival gameplay.
- Basic human combat/evasion.
- Enemy AI patrol/chase logic.
- Kinja laboratory sequence.

## Phase 6.0 — Zero Contract
**Objective**: The emotional climax.
- Interactive Zero transformation sequence.
- Power system unlock and post-contract abilities.

## Phase 7.0 — System Exit
**Objective**: Tonal shift to reality.
- Hospital awakening.
- Yuki and Shizuka interactions.

## Phase 8.0+ — Open World Architecture
**Objective**: Scale the game.
- Zone loading, NPC frameworks, side quests.
