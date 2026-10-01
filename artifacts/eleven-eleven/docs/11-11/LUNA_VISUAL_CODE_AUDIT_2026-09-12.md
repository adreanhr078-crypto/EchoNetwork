# Blender / Higgsfield review — 2026-09-12

Scope: existing G0 study and its Godot asset handoff. Manhwa remains authority.

## Findings and corrections

1. **Higgsfield room axes / camera (high):** revision 1 mixed Y-up walls/props
   with a Z-up floor. Its saved delivery image was nearly black, with isolated
   emissive lines. Converted the affected object matrices to Blender Z-up and
   moved the camera inside the room. Actual rendered revisions 2 and 3 were
   inspected. Revision 3 is the reviewed result, not revision 1.
2. **Portable lighting / glare:** AREA sources were omitted by GLB export.
   Replaced these with POINT lights, reduced cyan/magenta emission, increased
   wall/metal roughness, and separated neutral ceiling diffuser material.
3. **Unsafe static batching (high):** removing transformed parents before
   preserving child world matrices could move geometry. Flattening all meshes
   also erased door identity. Sanitization now preserves world transforms,
   retains door objects, rejects rigged/animated inputs, and refuses same-path
   overwrite. A transformed-parent regression proves world vertices and door
   identity survive the round trip.
4. **False animation confidence (high):** the old WALK/RUN only moved arms and
   torso, and loop endpoints differed. The validator previously accepted these.
   It now checks both thighs/knees and loop endpoints. The old delivered model
   fails the strengthened test at IDLE. New sampled motion studies animate legs,
   knees and opposing arms, with matching cyclic endpoints. These remain basic
   motion studies, not final authored locomotion or foot-lock/IK.
5. **False tattoo confidence (high):** `SkinTattoo_EX011` was a red cube, with
   a bone-parent transform error. Replaced it in the preparation pipeline with
   actual EX-011 glyph geometry weighted to the neck. Its name is deliberately
   `IdentifierPlacementStudy_EX011`: the high collar and sample identity prevent
   approval as the required direct-skin tattoo. The character production gate
   remains FAIL. A filename must not masquerade as visual Canon evidence.
6. **Texture fidelity:** removed blanket JPEG conversion; preserve alpha and
   constrain only oversized source textures to 1024 for the proof derivative.
   Original VRM remains unchanged. Final derivative is 6,072,104 bytes, within
   the existing 6 MiB gate, with no Khronos errors or warnings.
7. **Godot handoff:** plays the new motion-study file, enables cyclic playback
   and crossfades, removes the arbitrary 0.76 m vertical lift and synthetic body
   bob, starts facing the room, and shortens the third-person camera. A group
   hides all generated shell copies (the old name lookup hid only the first).
   The cylinder/sphere obscuring the authored exit door is hidden.

## Evidence

- `art/blender/intermediate/higgsfield-audit-r3.blend`: editable reviewed source.
- `art/blender/intermediate/higgsfield-audit-r3.png`: reviewed delivery render.
- `art/blender/intermediate/higgsfield-audit-r3-runtime.glb`: 689,236 bytes;
  6 meshes, 12 primitives, 8 materials, 8,460 triangles; strict validation PASS.
- `art/blender/intermediate/echo-audit-corrected.glb`: source for isolated
  `assets/echo-g0-motion-study.glb`; 4 clips, 113 joints. All four pass strengthened
  animation checks. WALK poses were rendered and inspected in Blender.
- `tools/blender/test_runtime_room.py`: transformed-parent and door regression PASS.
- Environment/preflight checks PASS. Project postflight PASS (content, TypeScript,
  foundation tests, production build). Existing large-chunk warnings remain.
- Godot actual OpenGL/Intel UHD render capture succeeded; startup composition
  inspected. Headless smoke passed after the new asset handoff.
- Exporter warnings remain for VRM duplicate image samplers and root-level
  skinned objects; no Khronos errors/warnings in the resulting GLB. Blender
  reports use_nodes deprecation for Blender 6, not the pinned 5.2 runtime.

## Quality decision

The prior all-green character impression is withdrawn. Structural file validity
is not hero quality. Original Echo identity, exposed-skin tattoo placement,
facial rig, cloth/hair motion, foot locking and authored locomotion still require
production work and review against the approved Manhwa. The current model is a
local VRoid sample; it is not approved for distribution as Echo.

The room is now a readable corrected study. It still has simple modular geometry
and study props. This is not Genshin-level art or a completed G0 experience.
Full movement/camera-collision playtest, performance measurement, final character
rights and art approval remain open. No open-world expansion, commit, push or
Flow generation was performed in this audit.
