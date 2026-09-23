# Echo opening uniform candidate — animation iteration v10

This is an opening-era student-uniform candidate derived from approved Manhwa pages 3 and 5. The generated turnaround is a geometry guide, not a replacement for the Manhwa or an approved final character sheet.

## Files

- `echo-opening-uniform-turnaround-v1.png` — generated four-view guide from the two Manhwa crops.
- `echo-opening-uniform-front-v1.png`, `echo-opening-uniform-back-v1.png` — views passed to Tripo.
- `build_echo_opening_uniform.py` and `build_echo_opening_uniform_v2.py` … `build_echo_opening_uniform_v10.py` — Blender build recipes and animation iterations.
- `echo-opening-uniform-v1.blend` … `echo-opening-uniform-v10.blend` — preserved editable Blender iterations.
- `../../../godot/assets/characters/echo_opening_uniform_v10.glb` — current runtime derivative referenced by `godot/scenes/player/echo_player.tscn`.

## Source and processing

- Front/back source crops: Manhwa page 3 city/school-uniform view and page 5 Sector X gate/backpack view, stored alongside these files.
- Full-body Tripo task: `9e2a6155-317b-47e3-9bf6-90b4163c40aa` (40 credits); rig task: `07e308f1-91ea-44a4-b811-85b3d9ec60a2` (25 credits).
- Retarget tasks: idle/walk/run `80b1621a-6d64-4f83-842d-6f146906c14f` (30 credits); fall recovery `f813d9b6-e061-4fd9-8b38-6ec23f1dee63` (10 credits).
- The v1 Tripo base is preserved; Blender v2–v10 iterations correct orientation and author the lower-body motion while retaining the imported upper-body motion. The current v10 derivative has 22 bones and seven clips (`preset_idle`, `preset_walk`, `preset_run`, `preset_fall`, `preset_jump`, `preset_turn`, `preset_wakeup`).
- v8 resets the twisted leg pose in idle and adds 28-frame walk and 15-frame run cycles. v9 solves the full four-bone leg chain to a toe target, bakes 49-frame walk and 25-frame run cycles, and synchronizes stride distances with the 3.0 m/s walk and 6.4 m/s sprint at their runtime animation rates.
- v10 adds a 73-frame recovery clip staged from the available collapse take, eases into idle, and pins the lower toe to the player's floor height during the opening. Godot 4.7.2 imports it as `preset_wakeup`; the opening camera remains skippable.
- Tripo source and previews remain under `art/production/tripo-out/echo-opening-uniform-fullbody-v1-2-07e308f1/` and the associated motion/recovery task folders.

## Review status

- The visible school blazer, shirt, tie, trousers, dark eyes, hair, and backpack design follow the opening-era reference. Manhwa page 5 shows the backpack at the experiment-gate approach; keep it unless a later capsule panel confirms it was removed.
- Added a replaceable `EX-011` identifier mesh attached to the imported neck bone as a direct-skin layer. It is present in runtime, but a close-up face/neck review is still required before treating the mark's scale, side, and readability as accepted.
- `scenes/cinematics/opening_awakening_cinematic.tscn` now provides a short, skippable camera orbit on the player's camera boom, then returns to the normal follow camera as recovery ends. Enter/Space or E skips the camera move without skipping the recovery.
- Idle, walk, run, jump, turn, fall, and wakeup are available. The wakeup is an interim staged recovery built from the existing fall take, not a final bespoke Manhwa performance. Runtime review still calls for better hand bracing and a lower, more settled initial pose.
- `walk-v9-runtime.png` records the current 1280×720 Godot runtime check; `ui-rightside-dual-review-v1.png` shows the mission dock and Echo-side System notification together; `walk-v8-contact.png` and `run-v8-03.png` preserve earlier iteration checks; `phase1-idle-v6.png` records the corrected neutral leg pose. `echo-opening-recovery-godot-review-v2.png` records an earlier in-engine recovery and dialogue frame.
- Blender toe-contact bake validation measured a maximum 0.00694-unit toe-target error before export. Godot 4.7.2 imported both locomotion clips; a 360-frame runtime walk and separate walk/sprint probes stayed grounded, at 3.0 and 6.4 m/s. These probes cover the current flat opening floor. Terrain-adaptive skeletal IK, start/stop blending, gait transitions, turn/fall/landing performances, and full-body acting still need refinement.
- `godot-opening-awakening-cinematic-v9.avi` and `godot-opening-awakening-cinematic-v9-2.png` record the latest manually reviewed camera move and return to gameplay. The review showed the scene loading without script-parse or missing-resource errors; the known ObjectDB shutdown leak persists.
- `godot-wakeup-v10-flooring.avi` and `godot-wakeup-v10-flooring-contact.png` record the 1920×1080 Godot runtime review of the new recovery. It confirms the imported clip and continuous toe-to-floor correction; its first lying pose and hand-bracing still need another authored pass.
- The Godot review confirms runtime visibility and the interim recovery flow, not final visual approval. Close-up face likeness, mark placement/readability, authored awakening acting, and exact backpack continuity inside the capsule remain open. The corridor still needs a detailed art pass. This iteration is a foundation, not Genshin-level final animation or art quality.

The earlier torso-only output from cropped source panels is preserved as a rejected iteration under `art/production/tripo-out/echo-opening-uniform-v1-rig-9c646dd7/`; it is not used by Godot.
