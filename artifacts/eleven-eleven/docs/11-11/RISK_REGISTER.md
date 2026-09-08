# Risk Register

This document tracks known architectural and production risks. Mitigate these before proceeding to advanced phases.

## 1. LCP & Bundle Size (Severity: HIGH)
- **Risk**: The current application bundles are massive. `phaser-runtime` is 588KB, `three-runtime` is 555KB, and `AwakeningWard` is 1,251KB. Combined, this will likely fail the $< 2.5s$ Largest Contentful Paint target on 3G/4G mobile networks.
- **Mitigation**: 
  - Deprecate Phaser completely if 3D is the path forward.
  - Audit Vite manual chunks to ensure `@react-three/drei` and `three` are rigorously tree-shaken.
  - Do not load the Three.js canvas until the player has passed the Main Menu and Psychological State screens.

## 2. 3D Asset Production Bottleneck (Severity: CRITICAL)
- **Risk**: A cinematic anime 3D game requires dozens of custom environments, rigged characters, and animations. Currently, none exist. Relying on an AI agent or a single creator to manually model, rig, and texture an entire game in Blender is a massive scope risk.
- **Mitigation**:
  - Implement the Phase 3.4 Vertical Slice (Room 1 ONLY) before committing to 10+ rooms.
  - Rely on AI generation only for concept reference, not final topology. Final GLBs must be highly optimized.
  - Use modular, reusable environment kits rather than bespoke modeling for every room.

## 3. Mobile Performance of Post-Processing (Severity: HIGH)
- **Risk**: The existing `GameWorld` uses complex R3F post-processing (`MemoryGlitchEffect`, Volumetric lighting, AdditiveBlending shards). These drop frames dramatically on mid-tier mobile devices.
- **Mitigation**:
  - Enforce `dpr={ [1, 2] }` limits in the Canvas.
  - Gate volumetric lighting behind the `quality` settings (currently partially implemented in Phaser, needs porting to R3F).
  - Test the Screen Break on an actual low-end Android device.

## 4. Test Suite Fragility (Severity: MEDIUM)
- **Risk**: End-to-end tests fail intermittently, leading developers to bypass the `agent:postflight` quality gate.
- **Mitigation**: 
  - Fix the `devFullStack.test.ts` failure where 3 services are running instead of the expected 2.
  - Fix `campaignAccessibility.test.ts` CSS queries.
  - Implement a zero-tolerance policy for failing tests.
