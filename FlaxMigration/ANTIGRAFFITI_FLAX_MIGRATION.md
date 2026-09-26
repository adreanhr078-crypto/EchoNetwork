# Echo Network — Godot to Flax Migration

You are the primary engineering agent responsible for migrating
Echo Network from Godot to Flax Engine.

## CRITICAL SAFETY RULE

Never delete or overwrite the working Godot implementation.

The Godot version remains the authoritative rollback and behavioral
reference until the Flax implementation is validated.

Do not remove:

- project.godot
- .gd files
- .tscn files
- .tres files
- original assets

Do not modify the Godot implementation merely to simplify migration.

---

# ENGINE

Flax Engine source:

C:\Users\yasmo\EchoNetwork\Tools\FlaxEngine

Flax Editor:

C:\Users\yasmo\EchoNetwork\Tools\FlaxEngine\Binaries\Editor\Win64\Development\FlaxEditor.exe

New game project:

C:\Users\yasmo\EchoNetwork\FlaxMigration\EchoNetworkFlax

Staged reusable source assets:

C:\Users\yasmo\EchoNetwork\FlaxMigration\SourceAssets

---

# PRIMARY OBJECTIVE

Rebuild Echo Network properly using native Flax Engine architecture.

Do NOT perform blind text conversion.

Godot-specific systems must be understood first and then reimplemented
using appropriate Flax C# or C++ systems.

Prefer C# for game-level systems unless native C++ is clearly justified.

---

# PHASE 1 — AUDIT THE GODOT PROJECT

Read the complete existing project.

Identify:

- player controller
- movement
- camera
- input
- combat
- abilities
- health
- enemies
- AI
- animation systems
- interaction systems
- dialogue
- quests
- inventory
- save/load
- UI
- HUD
- menus
- world logic
- game state
- shaders
- VFX
- audio
- cutscenes
- networking
- procedural systems
- tools/editor scripts

Understand the behavior before implementing replacements.

---

# PHASE 2 — ASSET MIGRATION

Reuse compatible original assets.

Examples:

- FBX
- GLTF
- GLB
- OBJ
- textures
- audio
- animations
- JSON
- CSV

Do not attempt to directly execute:

- .gd
- .tscn
- .tres

Those must be translated conceptually into Flax systems.

Preserve original source files.

---

# PHASE 3 — FOUNDATION

Implement first:

1. project settings
2. input system
3. player actor
4. third-person camera
5. movement
6. gravity
7. jumping
8. sprint
9. animation graph
10. collisions
11. interaction framework

Match the behavior of the Godot implementation.

---

# PHASE 4 — COMBAT

Rebuild:

- attacks
- combos
- targeting
- hit detection
- damage
- health
- enemy reactions
- abilities
- cooldowns
- VFX
- camera effects
- combat audio

Preserve existing gameplay intent.

Improve implementation quality where Flax provides a better native solution.

---

# PHASE 5 — VISUAL QUALITY

Take advantage of Flax rendering features where appropriate.

Evaluate:

- DDGI
- reflections
- volumetric fog
- shadows
- post processing
- color grading
- anti-aliasing
- particles
- materials
- decals
- terrain
- foliage
- level streaming
- LOD
- occlusion
- GPU instancing

Do not blindly enable expensive effects.

Profile them.

---

# PHASE 6 — VERTICAL SLICE

Before migrating the entire game, produce a fully playable slice containing:

- one representative environment
- player
- camera
- movement
- animations
- one enemy
- combat
- at least one ability
- VFX
- audio
- HUD
- lighting
- post-processing

The slice must actually run.

---

# PHASE 7 — VALIDATION

Compare Godot and Flax versions.

Measure:

- average FPS
- 1% low FPS
- GPU usage
- CPU usage
- RAM usage
- VRAM usage
- loading times
- frame pacing
- input latency
- visual quality
- shader compilation
- animation quality

Create a report.

Do not claim improvement without measuring it.

---

# PHASE 8 — FULL MIGRATION

Only after the vertical slice is stable:

Migrate remaining systems incrementally.

After every major system:

1. compile
2. launch
3. test
4. inspect logs
5. fix errors
6. compare behavior against Godot
7. commit changes

---

# GIT RULES

Work only on:

flax-migration

Create logical commits.

Examples:

feat(flax): create player controller

feat(flax): migrate combat framework

feat(flax): implement enemy AI

feat(flax): recreate HUD

perf(flax): optimize world rendering

fix(flax): resolve animation state transitions

Never rewrite unrelated project history.

Never force push unless explicitly authorized.

---

# QUALITY REQUIREMENTS

Do not merely make the project compile.

The migrated build must be:

- playable
- stable
- maintainable
- modular
- optimized
- visually polished

Prefer correct architecture over temporary hacks.

When something cannot be migrated automatically,
implement a native Flax replacement.

Do not silently remove features.

Document missing or changed behavior.

---

# COMPLETION REQUIREMENTS

Migration is not complete until:

- Flax Editor opens the project
- scripts compile
- the primary scene loads
- player movement works
- camera works
- collisions work
- animations work
- combat works
- UI works
- representative gameplay works
- no critical errors remain
- performance has been measured
- the original Godot version remains intact

