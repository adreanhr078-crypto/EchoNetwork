# Echo runtime asset audit — 2026-09-19

## Inspected source

- Runtime file: `public/assets/characters/echo.glb`
- SHA-256: `44EF65C46D74E5156ED732B83864709E5CCA8A6AE406EE91732C36ADB31B877B`
- File size: 22,774,444 bytes
- Inspection path: official local Blender 4.2 glTF importer, headless/read-only.

## Measured contents

- One primary body mesh: 57,990 vertices / 74,999 polygons.
- One small tattoo mesh: 4 vertices / 2 polygons.
- One armature: 41 bones, one `root`, paired leg/foot/toe chains and arm twist bones.
- Six imported clips at 24 fps: `IDLE` 2.458 s, `INTERACT` 1.958 s,
  `RUN` 0.792 s, `STANDUP` 2.958 s, `WAKEUP` 2.958 s, `WALK` 1.292 s.
- Textures reported by Blender: 8192×8192 base color, 4096×4096 metallic,
  and 2048×2048 normal.
- Bind-pose body bounds were offset from the scene origin and measured roughly
  0.883 m tall before runtime scaling.

## Accepted runtime corrections

- Fit the imported scene to a measured 1.78 m target height at load time.
- Centre horizontal bind-pose bounds and place the lowest point on the player
  ground origin; this removes the prior lateral offset and floor sinking.
- Derive walk/run playback scale from the measured clip durations and the same
  distance-per-contact values used by procedural footsteps.

## Quality boundary

This audit proves file structure, rig presence, clip inventory and deterministic
runtime fitting. It does not approve facial topology, deformation quality, hair or
cloth motion, materials, close-up rendering, exact heel/toe contacts, or final
Manhwa likeness. Those require recorded visual reviews and remain open gates.
