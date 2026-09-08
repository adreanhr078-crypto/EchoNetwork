# Current State Audit (September 2026)

## System Status Matrix

| System / Area | Status | Score (0-10) | Key Gaps |
|---------------|--------|--------------|----------|
| **Server Infrastructure** | Production | 9 | Excellent D1, Durable Objects, Queue, and Receipt validation. |
| **State Management** | Production | 9 | Zustand stores cleanly separate domain, UI, and external synchronization. |
| **Story & Canon Rules** | Solid | 8 | Good representation of Manhwa rules. Missing final asset integration. |
| **Authentication & Saves** | Solid | 8 | Firebase Auth + Firestore cloud saves are stable. |
| **UI & Puzzle Hub** | Stable | 7 | 20+ puzzles implemented, but UI bundle sizes are growing. |
| **Rendering Engine** | Conflicted | 4 | Split between Phaser 3 (A-01 Ward) and Three.js/R3F (GameWorld). |
| **3D Gameplay** | Prototypal | 3 | Primitive geometry rooms. No character controller. No collision framework. |
| **Cinematic / Animation** | Missing | 2 | No skeletal meshes, rig, or animation state machines. |
| **World Building** | Missing | 2 | No zone loading, spatial partitioning, or NPC systems. |

## Major Deficits & Technical Debt

1. **The Phaser vs R3F Engine Split**
   - *Problem*: The Awakening Ward was built using Phaser (2D Isometric). The actual vision requires R3F (3D Third-person).
   - *Action*: Deprecate the Phaser implementation. Unify all future gameplay around `@react-three/fiber` and `@react-three/drei`.

2. **The 3D Asset Bottleneck**
   - *Problem*: The game relies on procedural Three.js shapes (boxes/planes) because no Blender GLB assets have been produced.
   - *Action*: Establish the Blender `export_glb.py` pipeline. Do not write massive manual Three.js scenes; load `.glb` files.

3. **Bundle Size Risks**
   - *Problem*: Current gameplay chunks exceed 2.3MB gzipped (`phaser-runtime` + `three-runtime` + `AwakeningWard`).
   - *Action*: Strict lazy-loading via `React.lazy` and `Suspense`. Ensure Three.js is NEVER loaded on the `MainMenuScreen` or `PsychologicalStateScreen`.

4. **Test Suite Fragility**
   - *Problem*: End-to-end and component tests have intermittent failures (e.g., `campaignAccessibility.test.ts` CSS assertions, `devFullStack.test.ts` realtime mismatches).
   - *Action*: Stabilize test environments. Do not ignore failing tests to push features.
