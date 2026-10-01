# G0 Godot Vertical Slice Proof — execution log

> Superseded character/visual findings: see [2026-09-12 audit](LUNA_VISUAL_CODE_AUDIT_2026-09-12.md).
> The old candidate failed the strengthened animation gate. The proof now uses
> `echo-g0-motion-study.glb`. Higgsfield revision 3 is the reviewed scene;
> startup rendering was inspected, but final character art and full playtest
> remain unapproved. The tables below preserve the earlier checkpoint history.
>
> Latest owner-video comparison and explicit visual failures:
> [G0_VISUAL_QUALITY_GATE_2026-09-12.md](G0_VISUAL_QUALITY_GATE_2026-09-12.md).

**Date:** 2026-09-11  
**Scope:** isolated technical proof only  
**Continuation point:** Astra's `ScreenBreak → First 3D Escape` checkpoint in
`docs/internal/production/opening-recovery-execution-audit.md`

## What changed

Created `art/godot/technical-proofs/g0-vertical-slice`, a bounded Sector 11-inspired
room proof with an authored Blender delivery path. It contains:

- `EchoPlayer` (`CharacterBody3D`) with keyboard/arrow movement, sprint, gravity,
  collision and a following third-person camera.
- One signal, one memory clue and one exit door with distance-based interaction.
- A single objective transition: inspect `11:11` → reach the door → slice clear.
- Lighting, a cinematic dark-room palette and a `Q` reduced-effects fallback.
- A `CanvasLayer` with Arabic objective, interaction prompt and test status.
- `R` recovery/reset so the proof can be replayed without persistent state.
- A Blender-authored room GLB (`assets/g0-room.glb`) loaded by the proof while the
  procedural collision shell remains authoritative.
- A VRoid-derived Echo candidate (`assets/echo-g0-candidate.glb`) with EX-011
  binding, four animation clips, and a third-person presentation bridge. This is a
  local prototype identity only; it is not the final Manhwa-approved Echo model.
- A Higgsfield 3D Jutsu room study (revision 1) exported to
  `art/blender/intermediate/g0-higgsfield-room.glb` and sanitized by Blender into
  `g0-higgsfield-room-runtime.glb` for portable inspection. The source study is
  reference material, not Canon.

## Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Pinned Godot executable | PASS | `GODOT_DOCTOR_OK` (4.7.2 stable) |
| Project import | PASS | safe wrapper import completed |
| Scene/script parse | PASS | no parse errors after import |
| Headless node contract | PASS | `GODOT_SMOKE_OK` |
| Wrapper contract | PASS | `GODOT_PORTABLE_PROOF_OK` |
| Blender-authored room GLB | PASS | Khronos strict validation (0 errors/0 warnings), Blender re-import, Godot smoke |
| Echo candidate GLB structure | PASS | Khronos strict validation (0 errors/0 warnings), Blender re-import, character validator; EX-011 present |
| Higgsfield room study bridge | PASS (derived runtime file) | Remote revision 1 (49 objects, 14×14×5.5 m); Blender sanitization to 1 mesh; Khronos strict + re-import pass |
| Antigravity static audit | CONDITIONAL PASS | [ANTIGRAVITY_G0_AUDIT_2026-09-11.md](./ANTIGRAVITY_G0_AUDIT_2026-09-11.md) |
| Visual playtest | UNVERIFIED | requires a visible desktop run |
| Manhwa visual identity / final VRoid rights | UNVERIFIED | candidate is structural only; source is an owner-local VRoid sample |
| Performance/accessibility | UNVERIFIED | profiler + Edge checklist pending |

## Quality gate decision

`G0-A Toolchain = PASS` for the isolated proof. The Blender → GLB → Godot bridge is
now structurally green, while the Echo's Manhwa fidelity, rights, visual playtest,
performance, and accessibility remain explicitly unverified. Antigravity's
independent static review is conditional and records SpringArm3D, clamp/collision,
and Unicode-font risks. `G0-B` through `G0-F` remain `UNVERIFIED`; therefore this
does not authorize production lock, final character art, combat, open world, or a
second gameplay engine.

## Reproduction

From the repository root:

`npx tsx tools/godot/run-godot.ts -- smoke artifacts/eleven-eleven/art/godot/technical-proofs/g0-vertical-slice`
