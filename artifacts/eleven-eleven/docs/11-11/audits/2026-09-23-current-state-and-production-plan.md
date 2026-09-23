# 11.11 — Current-State Audit and Production Plan

**Priority update, 2026-09-23:** The player's reported bad walking and falling led to a direct animation/collision audit. The current controller selects a run clip during ordinary 4.2 m/s walking, the Sector 11 visual corridor continues beyond the main floor collider, and the street road/sidewalk have no walkable collision. The centered System window and disconnected cinematic/story hooks are also confirmed. The revised short first phase and complete sequence are in `2026-09-23-quality-reset-plan.ar.md`; its movement, collision, and UI gate supersedes the art-only immediate-next-action paragraph below. The new ceiling tile is an intermediate reviewed asset, not a quality sign-off.

Date: 2026-09-23  
Scope: approved Part 1 Manhwa, the two supplied production prompts, current Godot project, and the user's new living-world/crime-system direction.

## Authority and evidence

- The 70-page approved Part 1 Manhwa is narrative canon. The attached prompts are production references, not permission to contradict canon or skip the current product gate.
- The user has now explicitly directed work in Godot. The web application remains present; this audit does not claim a completed web-to-Godot migration.
- Current source code can be audited, but checked-in history does not reliably identify Antigravity as the author of each feature. Feature attribution to Antigravity is therefore **unverified**.
- The latest continuation (CP-20260922-06) claims combat/story gates and life-simulation features passed automated checks. Those are historical claims; this audit does not rerun tests or treat them as artistic acceptance.

## What is already in the project

| Area | Evidence in Godot project | Current assessment |
|---|---|---|
| 3D gameplay foundation | Godot 4.7 player, camera, movement, dodge, combat scripts, shaders, HUD, floating pod | Prototype systems exist; visual and progression quality are not release-ready |
| Sector 11 content | Capsule, facility, terminal, gate, Specimen EX-000, one Kinja/torture sequence | Content exists, but the default entry and order contradict the approved opening |
| Minato-Kasumi life slice | Residential street, houses, NPC schedules, needs, konbini, clock, save data, vehicles, domestic interactions | Meaningful prototype coverage; not evidence of a fully built or polished city |
| Cinematic tooling | Camera director and one long Kinja/torture sequence | Pipeline exists, but the required story beats are missing or bundled together |
| Visual direction | Cel/outline shaders, emissive cyan/red details, atmosphere controls | A style attempt exists; current capture is too dark, empty, over-glowing, and dominated by generic geometry/UI |
| Wanted/crime loop | No implemented witness/evidence/police/arrest/prison system found | New user-requested feature; schedule after the story and world foundations are repaired |

## Baseline blockers and current state

These were present in the first runtime capture for this audit. M00 has since corrected the opening flow and several presentation/runtime defects; the residual issues below remain open.

1. **Fixed in M00:** the default entry no longer spawns the boss fight or gives Echo a weapon. It now opens on “Find a way out of Sector 11,” with combat and boss presentation disabled until a later encounter is activated.
2. **Improved, still open:** the pre-uniform 1920×1080 capture used the tactical `echo_tripo_native.glb` outfit, which did not match the opening’s school-uniform panels. The scene now points to a Manhwa-derived full-body uniform asset with 72,507 triangles and four clips. A Godot movie capture confirms the model renders and the reversed fall clip now plays as an interim recovery beat. Godot normalizes the imported animation names (`preset:fall` becomes `preset_fall`); the first lookup missed that import name and left the recovery objective stuck. The lookup is now corrected, and a 4-second capture shows the objective and first dialogue line. The corridor remains a dark, repeated blockout with sparse dressing. This is not Genshin-level art yet.
3. **Still open:** a new `opening_awakening_cinematic.tscn` now supplies a short skippable camera move during the recovery, but the body uses the uniform asset's fall clip in reverse as an interim stand-up; it is not the authored Manhwa awakening performance. Opening fracture, experiment, transfer, false exit, Zero/contract, interactive revenge, extraction, and hospital awakening still lack separate connected cinematic scenes. Some later beats remain compressed into one procedural sequence.
4. **Partially fixed:** the world streamer now reports missing scenes instead of claiming success, separates portal positions, reuses the existing alley, and starts in Sector 11 so a reality-world portal cannot skip the System arc. A decompression-ward scene now exists for the later hospital return; its story activation is not connected yet.
5. **Fixed for entry; broader story remains open:** premature katana unlock and automatic jump to the torture sequence were removed from the opening callback. The full exploration/false-exit/stealth/encounter/Kinja/Zero order still needs to be authored as connected progression.
6. **Still open:** the present street slice and simulated NPC schedules are a foundation, not yet the responsive, consequence-bearing city requested by the user.
7. **Canon consistency issue:** player-facing lines now use **Kinja**, matching the production mandate. Older internal script, scene, asset, and checkpoint identifiers still say `Kinga`; consolidate those names before finalizing voice assets and cinematic credits.

## Ordered production phases

### M00 — Correct the existing entry and visual baseline (implemented first pass; not a quality sign-off)

- Remove the accidental boss-first default and supernatural weapon from the opening; provide a clear, canon-safe wake/escape objective and keep later combat content available behind progression.
- Correct the immediate scene composition, lighting, material response, character framing/readability, and HUD hierarchy using Manhwa fidelity as the art check.
- Repair missing-scene/portal failure behavior and separate zone transition positions.
- Capture and inspect a new in-engine frame; report residual model/asset limitations honestly.

Current evidence: the 1280×720 Godot capture shows the new school-uniform Echo, containment corridor, aligned terminal, smaller guide core, hidden boss HUD, no desktop touch controls, and no early weapon. The reversed recovery animation is visible; by 4 seconds the objective and opening dialogue appear. No script parse error or missing-scene warning appeared; Godot still reports one ObjectDB instance leaked at shutdown. The terminal display was previously hidden behind its pedestal; its screen and readout now sit on the front face. The puzzle callback opens the blast gate in code. The room and character still need a full production review.

### M01 — Establish production-quality character and environment art (underway; not approved)

- Lock a Manhwa-matched Echo everyday design, recognizable face/silhouette, rig, skin/hair/clothing materials, and readable locomotion/acting.
- Replace placeholder arena construction with authored modular Sector 11 art; set a restrained anime palette, deliberate key/fill/rim lighting, readable values, controlled bloom/fog, and quality tiers.
- Rework HUD scale, typography, spacing, combat visibility, and contextual System/companion presentation.
- Use Blender/Tripo only for identified asset gaps; retain source provenance and validate imports and collisions.

Work completed so far: a source audit found that `echo_player.tscn` had been using `echo_tripo_native.glb`, not the separate V3 candidate. The native asset has 41 bones and four actions named `preset:biped:idle.001`, `preset:biped:look_around.001`, `preset:biped:run.001`, and `preset:biped:walk.001`; the player’s old underscore aliases did not resolve those names, and it had no `WAKEUP`/`STANDUP` clips. The V3 candidate remains a separate 75,081-triangle, 41-bone asset with six authored actions, but it is not the opening scene’s prior asset.

The opening player now references `godot/assets/characters/echo_opening_uniform_v1.glb`, a full-body school-uniform candidate derived from Manhwa pages 3 and 5. The project retains the original Tripo model and a four-view reference sheet; the final Blender derivative is 72,507 triangles, 22 bones, 54,730 vertices, a 5.26 MB GLB, and four clips (`preset:idle`, `preset:walk`, `preset:run`, `preset:fall`). Blender decimated the source mesh. Godot imports those clip names as `preset_idle`, `preset_walk`, `preset_run`, and `preset_fall`; player animation routing now supports the normalized names. The reversed fall clip visibly plays as a temporary recovery motion. Page 5 shows the backpack at the experiment-gate approach, so the current outfit keeps it pending a precise check of whether a later capsule panel removes it. Added a replaceable, bone-attached `EX-011` direct-skin neck mark layer; its close-up placement and readability still require a dedicated review. No bespoke WAKEUP/STANDUP acting clip is authored.

The first Tripo attempt used cropped page panels and produced a torso-only, 1.45-million-triangle mesh; it remains under `art/production/tripo-out/` for provenance and is not the shipped candidate. The corrected full-body turnaround cost 40 credits, rigging 25, idle/walk/run retargeting 30, and a fall recovery clip 10. Before the latest environment asset, 210 credits had been spent from the stated 460-credit balance. A stylized Sector 11 cryogenic pod then cost 40; the current balance is 210 with zero frozen, confirmed by the Tripo CLI. The guide-core and pod source/provenance remain under `art/production/tripo-out/`. The aligned terminal, contained corridor, ceiling keys, and smaller guide-core framing remain in place. Repeated blockout geometry, close-up face/skin/tattoo review, combat animation, and HUD polish remain open. Google Flow was not used because browser control timed out; no Flow credits were spent.

Environment art step: generated a single-person cryogenic pod at an 18,000-face target with P1 and integrated it through `godot/scenes/props/sector11_cryo_pod.tscn`. The wrapper turns the glass bay toward the opening camera and adds a simple collision body; the prior capsule scene and mesh remain preserved. The in-engine review image is `art/production/sector11-cryo-pod-v1/godot-opening-cryopod-review-v3.png`. The pod gives the opening a clear hero prop, but does not provide the awakening animation or interaction.

Environment pass: tightened the Sector 11 shell to an 18×7.2 m playable space, routed utility lines overhead, and moved the side pipes above Echo. Added a Blender-authored modular kit with two observation-bay GLBs and one service-hatch GLB; ten modules now break up the side-wall silhouette, with structural ribs moved behind them. Added an open-frame Blender cryo docking dais with synchronization rings, anchors, caution inlays, and `EX-011` bay engraving under the pod. Blender sources/renders are under `art/production/sector11-modular-kit/` and `art/production/sector11-cryo-dais/`; Godot copies are under `godot/assets/environment/`. The 1280×720 runtime frames show the new assets, cryopod, character, guide core, objective, and dialogue without script or missing-resource errors. The room remains mostly a procedural shell, and the asset work is an intermediate art pass rather than Genshin-level quality.

### M02 — Build the correct opening vertical slice

- Map the approved Manhwa panels to assembly puzzle, instability, fracture, experiment, transfer, capsule awakening, System initialization, companion, and first exit objective.
- Add skippable, audio-aware, accessibility-aware camera/acting beats and return control only after Echo's vulnerability reads clearly.
- Deliver one connected playable path, not a collection of cinematic clips.

First beat underway: Godot imports the clips as `preset_idle`, `preset_walk`, `preset_run`, and `preset_fall`; the player recognizes these names and uses the fall clip backward as an interim recovery. Added a separate skippable camera-boom move for the opening recovery and manually reviewed a 6-second Godot capture at 1280×720 (`art/production/echo-opening-uniform-reference/godot-opening-awakening-cinematic-v9-2.png`). It returns to the gameplay follow view before the escape directive and first dialogue. This is not the authored Manhwa awakening performance. The transfer, experiment, fracture, false exit, and later story cinematic scenes remain missing.

### M03 — Make the System route coherent

- Author false exit, distinct sectors, exploration/scanning, stealth, fair encounters, human survival defense, and memory reveals.
- Gate supernatural abilities until the canon contract; make mission prompts, guide explanations, consequences, and checkpoints understandable.
- Remove story jumps and duplicate/contradictory objectives.

### M04 — Produce the emotional climax

- Stage Kinja's presence/lab, psychological torture, Yuki/Shizuka false choice, collapse/abyss, Zero presence/reveal/dialogue, contract, partial transformation, return, interactive revenge, loss of control, System warnings/choice, and extraction in approved order.
- Split the current omnibus sequence into reviewable scenes and gameplay transitions; do not turn interactive revenge into a long passive movie.

### M05 — Finish the reality return and living-world foundation

- Deliver hospital awakening, home/school/relationships, Minato-Kasumi route, companion consequences, and Zero's lingering presence.
- Improve the existing neighborhood slice before expanding its footprint; build schedules, readable reactions, persistence, ambience, and meaningful daily interactions around authored story beats.

### M06 — Add the user's crime, response, and prison loop

- Witness perception and line-of-sight; evidence/identity confidence; reporting latency; dispatch and police search; player warning from the System/phone/public screens; arrest, custody, sentence, prison routine, escape missions, and world-state consequences.
- Make outcomes depend on who saw what, avoid omniscient police, respect story chronology, and keep this loop opt-in through actual player choices rather than random punishment.

### M07 — Final integration and release-quality review

- Reconcile Godot gameplay with the existing app/services without duplicating progression authority; preserve Arabic/English, input/accessibility options, saves, performance tiers, and content provenance.
- Complete visual, narrative, gameplay, performance, and platform reviews before calling any phase done.

## Immediate next action

Continue M01 art: keep the page-5 backpack unless a later capsule panel proves it is removed; verify close-up placement/readability of the new direct-skin EX-011 neck mark, improve character/face framing, and refine the corridor shell, ceiling, materials, and lighting around the new wall modules and cryo dais. Replace the interim reversed-fall body motion with an authored awakening. Then complete M02 with connected, skippable Manhwa opening scenes. Keep the System-to-hospital transition locked until story progression earns it. Do not call M00, M01, or M02 complete from structural checks alone.
