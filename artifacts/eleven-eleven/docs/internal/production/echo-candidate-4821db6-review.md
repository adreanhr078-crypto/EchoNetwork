# Echo candidate 4821db6 — REJECTED

Reviewed 2026-09-10 directly from the separate checkout at `C:/Users/yasmo/EchoNetwork`.
This review does not remove or rewrite the submitted commit. No candidate file or runtime replacement from that commit was imported into the active Downloads checkout.

## Verified defects

- All four view PNGs and `animation_preview.mp4` have identical SHA-256: `FE1D3655649C1646552D5D4CF5FCC15BF5224B8D35FE30553B7F49178D95DFC4`.
- FFprobe identifies the supposed MP4 as `png_pipe`, codec `png`, 800x800. It is not a motion preview.
- Inspected `render_front.png`: a dark primitive block, not the requested Echo character. The other names do not represent different cameras.
- The submitted report explicitly admits primitive geometry, no materials, static animation keys, and duplicate renders. Its reference sheet does not identify inspected Manhwa page numbers and contradicts the report about materials.
- Re-import with the strengthened Blender gate rejects the candidate: all 19 required non-root bones lack a root ancestor. This is not a connected humanoid rig.
- The commit also changes `public/assets/characters/echo.glb` (78,428 to 15,724 bytes) and `public/assets/rooms/opening-lab.glb` (12,316 to 12,976 bytes), outside the assigned candidate-only boundary. A restoration claim does not authorize blind integration.

## Gate repair

The previous validator checked bone names, action names, a tattoo object name, and upper complexity limits. It did not prove that a skeleton was connected, materials existed, or a named clip moved any joint. It could therefore pass this invalid candidate.

`tools/blender/validate_character_glb.py` now requires root ancestry, at least one assigned material, exact clip names (allowing the exporter object prefix), positive clip duration, and changing relative bone poses. Four real Blender tests in `tools/blender/test_character_motion.py` cover one-frame clips, static multi-frame clips, rigid whole-object motion, and actual joint motion after GLB export/re-import. All four passed on Blender 5.2.1 LTS.

This remains a structural gate. It cannot certify anatomy, skin weights, face identity, the placement or appearance of a named tattoo, feet sliding, clothing intersections, Canon fidelity, or artistic quality. Those require independent visual and runtime review. Sampling is not proof that every frame is correct.

## Required replacement delivery

Continue in a new versioned candidate folder. Preserve the rejected files as evidence. Do not modify runtime assets, application source, Git history, stashes, or remote state for this asset task.

1. Inspect actual approved Manhwa pages and record their page numbers and relevant appearance details.
2. Author a real face, hair, body, hands, clothing, materials, and a connected deforming rig. Do not rename a block as Echo.
3. Author real Idle, Walk, Run, Interact, WakeUp, StandUp motion; do not use a single constant key merely to export a named action.
4. Render genuine front, side, three-quarter and closeup views, plus a properly encoded animation preview showing the motions. Verify their contents before reporting them.
5. Keep the source generator if one is used, preserve the editable blend, run the strengthened structural gate and media inspection, and state remaining artistic defects honestly.

A technical proxy may be described as a proxy, but it does not fulfill the assigned character production task.
