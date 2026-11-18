---
name: echo-unity-art-motion
description: Direct, build, and verify 11.11 Unity scenes where manhwa atmosphere, authored camera and locomotion, water, wind, fire, electricity, readable encounters, or Tripo PBR integration matter. Use for playable chapters, art upgrades, and migration of verified Godot assets into Unity URP.
---

# 11.11 · Unity art and motion

Start with `Migration/CURRENT_CONTEXT_CACHE.json`, the named card, and the live Unity scene. Read only the Godot assets/behavior and narrative beats the current work touches. Keep source meshes, original animation keys, material maps and provenance. Port behavior and story dependencies, and redesign pacing, exploration, geometry or presentation when the player experience improves. Keep School65 before the explicit Zero pact. Confirm story changes in the project handoff.

## Playable composition

- Define a room's silhouette, first question, observable objective, reveal and safe return. Give useful landmarks a distinct silhouette, color and sound. Every major vista should hint at a reachable place or a question that pays off.
- Use deep indigo shadows, petrol-blue/cyan navigation, amber physical hazards and violet memory anomalies. Keep character skin, white shirts and clue surfaces separable from the background. Use saturation selectively so signals still read in grayscale and lowered graphics quality.
- Keep an authored lighting hierarchy: key, motivated bounce, practical emitters, and depth atmosphere. Capture entrance, reverse, lateral and hero-detail views once the route works. Compare using matching exposure, lens and player location.
- Favor editable structural modules, separate visual surfaces/colliders and preserved UVs. Check material channels, import-scale, pivots, front/back shape, silhouette, bounds and GPU cost on the actual Unity renderer.

## Motion and feedback

- Ground movement may use the exact exponential blend `1-exp(-k*dt)`. Measure capsule speed and drive animation from contact. Verify acceleration, braking, foot slide, ground grace, wall collision and jump reach at 30 and 60 fps. Keep authored hand/foot contacts authoritative.
- Use a collision-bounded camera with fast obstruction contraction and damped release. Blend position and target during a cinematic takeover and hand control back on skip, finish and scene unload. Reduced Motion keeps the readable state, static water cues, and original gameplay timing.
- For water use scale-aware phase waves, roughness variation and bounded damped impact ripples. Advect vapor and banners with a shared gust field. Use fixed or capped simulation substeps for spring-driven props. Derive arc brightness and pressure feedback from the same state that drives interaction. Fire and electricity should have an identified emitter and stable gameplay meaning.
- Pair directional light and motion with spatial SFX: air hiss, drops, platform impact, relay engagement, wind through openings. Make cues readable on mute, keep voice space clear, and respect pause. Log field measurements before adding complexity.

## Asset and cinematic reuse

Check cached tasks and hashes before sending references to Tripo or Flow. For a missing prop, submit an isolated approved image, inspect the cost and reuse one PBR source to derive distance meshes. Review actual Unity appearance, tangents, texture packing, colliders and animation binding before promoting it. Use Flow for shots requiring a continuous performance or geometry-matched transition. Record the exact references, actual output and review result.

## Evidence

Exercise the route through its normal scene, with fresh and restored progress. Check native shader rendering, readable cues, camera clearance, safe retry, pause, Reduced Motion and mute. Keep evidence and measurements compact. Have fresh players explain the next objective unaided and measure what they choose, where they hesitate and whether they want to continue. Compare visual craft, responsiveness, audio and frame time separately. Benchmarks and headless checks are different forms of evidence.

