# Master animation production tools

Resume from `docs/internal/production/CURRENT_WORK.ar.md` and the execution record.
Do not inventory/extract the protected source ZIP again when its saved hash and
working copies match. Source archives are never modified by these tools.

## Authoritative Golden workflow — Owner instruction, 2026-09-30

The approved `MOB1_Walk_F` is a fixed Golden Reference, not a motion to rebake.
Its manifest is `art/production/master-animation-library/golden/walk-v1/GoldenReference.json`;
the frozen GLB SHA-256 is
`21f818d302f134068de3a1eeacf3e23861e3159149567db63b6d278469a0047d`.
The frozen Golden invariants apply to every motion. Routine successful work
follows the proven pipeline directly. Invoke `$echo-golden-animation` from the
repository's `.agents/skills/echo-golden-animation/SKILL.md` immediately when it
improves diagnosis/quality, at the first failed or poor result, and no later than
the second attempt. Allow at most two evidence-driven attempts per motion: record
the cause and a scoped fix before a second attempt; do not repeat failed commands
without new evidence. Preserve a still-failing case and its diagnosis instead of
starting a blind retry loop. Run `golden_reference.py` before and after every
stage. The guard checks 192 protected original files plus the
frozen snapshots and manifest hash. Never reseal the reference or write into its
directory or original `audits/evidence/single-walk-20260930/` evidence.

Process **Run/Jog, then Idle, then Jump, one motion at a time**. Complete and
record each motion's numerical and visual evidence before starting the next.
Select existing takes from `CandidateReviews.json` and `SourceInventory.json`;
retain their real semantic names. `MOB1_Jog_F` verifies jogging, not sprint
quality. A different source rig hash requires inspection of that source's rest
contract; it does not authorize changing the Golden pipeline or project settings.

`single_motion.py` compares its complete transfer loop, rest/alignment expressions
and exporter options against the frozen Walk implementation. Only source identity,
sample count/duration, action name and per-case output paths vary. `native_timing.py`
reads native binary FBX timing: native FPS, inventory FPS and imported scene FPS
must all be 30, the source must start at frame 1, and its integral last frame must
match the candidate range. Unsupported rates, unspecified native FPS and timing
disagreements fail closed for isolated diagnosis; never relabel, resample, trim or
pad source keys to satisfy this contract.

The same sequence applies to every case:

1. Verify Golden integrity, then inspect the original source, Rest Pose, Bone
   Mapping, local bone axes, armature transforms, Hips and upper-leg rotations.
   Review the source diagnostic and source images **before** baking.
2. Bake full source world/rest rotations and original Hips translation scaled
   once, preserving target rest offsets. No IK, contact/sole corrections, fitted
   root, smoothing or manually authored replacement keys.
3. Require Blender replay/length/rotation numerical PASS and inspect source/target
   comparison images. Record a visual PASS for the exact `single-motion.blend`
   SHA-256. Generated images alone do not establish a reviewed PASS.
4. Export only after both Blender gates. `ACTIVE_ACTIONS` must produce exactly
   one named clip (`Run_Source_Retarget`, `Idle_Source_Retarget` or
   `Jump_Source_Retarget`), checked in `export-check.json`.
5. Import that GLB alone into a new per-case Godot review project. Apply the same
   frozen `configure_review_import.gd` diagnostic profile, disabling optimizer
   and compression there only, then reimport. `single_motion.gd` compares every
   mapped joint at every original sample time through AnimationPlayer alone.
   Preserve the frozen C*R quaternion conversion and colon-sanitized bone lookup.
6. Save source/artifact/tool hashes, numerical and actual visual results, logs,
   preservation evidence and a final Golden integrity check. Isolate any failure
   and document its cause before a local fix; complete the case before proceeding.

No new source animation generation or source-key edits, Walk improvement,
Skeleton Retarget/Root Motion changes, current-player replacement, AnimationTree,
blending or global import/project-setting changes are authorized. An empty
`root_motion_track` in the isolated reviewer means no extraction; it is not a
change to the project's Root Motion. Golden acceptance is separate from runtime
integration and acceptance of the full game.

### Exact per-case CLI sequence

Use PowerShell from the active app directory. These variables demonstrate the
existing Run/Jog candidate; change only the case name, exact take ID, clip name
and isolated paths after the preceding motion's evidence is complete.

```powershell
$EchoAnimationApp = 'C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven'
$EchoBlender = 'C:/Tools/Blender-5.2.2-portable/blender-5.2.2-windows-x64/blender.exe'
$EchoGodot = 'C:/Tools/Godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe'
$EchoCase = "$EchoAnimationApp/audits/evidence/golden-sequence-20260930/run"
$EchoTake = '92bf7cb4b88e3ee2a29be185:0:fd47e298'
$EchoClip = 'Run'
$EchoReviewProject = "$EchoAnimationApp/.tmp/master-animation-library/run-golden-review"
$EchoBlenderProfile = "$EchoReviewProject/blender-profile"
$env:BLENDER_USER_RESOURCES = $EchoBlenderProfile
$env:BLENDER_USER_CONFIG = "$EchoBlenderProfile/config"
$env:BLENDER_USER_SCRIPTS = "$EchoBlenderProfile/scripts"
$env:BLENDER_USER_EXTENSIONS = "$EchoBlenderProfile/extensions"
$env:BLENDER_USER_DATAFILES = "$EchoBlenderProfile/datafiles"
New-Item -ItemType Directory -Path $EchoReviewProject,$EchoBlenderProfile,$env:BLENDER_USER_CONFIG,$env:BLENDER_USER_SCRIPTS,$env:BLENDER_USER_EXTENSIONS,$env:BLENDER_USER_DATAFILES -Force
Set-Location -LiteralPath $EchoAnimationApp
python tools/animation-library/golden_reference.py
& $EchoBlender --background --factory-startup --offline-mode --python tools/animation-library/single_motion.py -- --mode inspect --output $EchoCase --take-id $EchoTake --clip-name $EchoClip
& $EchoBlender --background --factory-startup --offline-mode --python tools/animation-library/render_single_motion.py -- --case $EchoCase --phase source
```

Stop at this gate and read `diagnosis.json` plus the source images under
`source-frames/`. When the source and transfer contract have been verified:

```powershell
python tools/animation-library/golden_reference.py
& $EchoBlender --background --factory-startup --offline-mode --python tools/animation-library/single_motion.py -- --mode bake --output $EchoCase --take-id $EchoTake --clip-name $EchoClip
& $EchoBlender --background --factory-startup --offline-mode --python tools/animation-library/render_single_motion.py -- --case $EchoCase --phase comparison
```

Read `blender-reference.json` and inspect `comparison-frames/`. Record
`blender-visual-review.json` with `status: "PASS"`, the reviewed .blend's actual
`blend_sha256`, and review observations/evidence. Do not write PASS before review.
The exporter checks those gates and rejects stale hashes or changed inputs:

```powershell
& $EchoBlender --background --factory-startup --offline-mode --python tools/animation-library/single_motion.py -- --mode export --output $EchoCase --take-id $EchoTake --clip-name $EchoClip
python tools/animation-library/golden_reference.py
```

Create the empty isolated review project at `$EchoReviewProject` with its own
`project.godot` and compatible renderer. Copy only this case's exported GLB and
the two reviewer scripts there; never copy into the runtime Godot project.

```powershell
Copy-Item -LiteralPath "$EchoCase/single-motion.glb" -Destination "$EchoReviewProject/single-motion.glb"
Copy-Item -LiteralPath 'tools/animation-library/single_motion.gd' -Destination "$EchoReviewProject/single_motion.gd"
Copy-Item -LiteralPath 'tools/animation-library/configure_review_import.gd' -Destination "$EchoReviewProject/configure_review_import.gd"
& $EchoGodot --headless --path $EchoReviewProject --editor --import
& $EchoGodot --headless --path $EchoReviewProject --script res://configure_review_import.gd -- res://single-motion.glb
& $EchoGodot --headless --path $EchoReviewProject --editor --import
& $EchoGodot --headless --path $EchoReviewProject --script res://single_motion.gd -- res://single-motion.glb "$EchoCase/blender-reference.json" "$EchoCase/godot-lossless-review.json"
& $EchoGodot --path $EchoReviewProject --script res://single_motion.gd -- res://single-motion.glb "$EchoCase/blender-reference.json" "$EchoCase/godot-render-review.json" --render
python tools/animation-library/golden_reference.py
```

Review the actual Godot images as well as the report. A camera crop is a
presentation issue to diagnose locally, not proof that retargeting failed.
Preserve all case evidence and complete the mandatory project quality gate,
preflight/postflight and final diff checks; numerical PASS alone is not delivery.

## Historical single-Walk diagnosis — preserved evidence, do not rerun

CP-20260930-03 supersedes the batch instructions below: Owner stopped animation
generation/improvement and requested exactly one original Walk with one Echo.
Use `single_walk.py --mode inspect --output audits/evidence/single-walk-20260930`
under the isolated Blender profile, then `--mode bake`. Review the source and
target in Blender before `--mode export`; export requires numerical PASS and a
visual gate tied to the saved .blend SHA-256. Bake transfers full rest-space
rotation/hip motion, preserving target offsets without IK, sole correction,
fitted transport, smoothing or manually authored keys. Export uses ACTIVE_ACTIONS
and rejects anything other than the one named baked Walk.

`single_walk.gd -- res://single-walk.glb ABSOLUTE_REFERENCE_JSON ABSOLUTE_REPORT`
checks every common joint at all 37 times through AnimationPlayer only. Optional
`--render` writes back/side frames. Bone names use Godot's colon sanitization;
the joint quaternion reference follows the installed Blender exporter's C*R
contract. Empty root_motion_track keeps original baked Hips translation.
Default vs key-preserving import A/B is diagnostic only: 6.46 mm/1.215 degrees
with optimized import vs 1.36 micrometres/0.000062 degrees preserving keys.
No runtime Skeleton Retarget, Root Motion, AnimationTree, player or import files
were changed. Do not compensate for optimizer loss by changing skeleton retarget.
Root cause, measurements and review evidence are in
`audits/evidence/single-walk-20260930/`. No canonical/artistic 100% claim.

## Historical batch workflow — incompatible with the current Owner rule

All batch/ranking/contact/IK instructions below describe earlier experiments.
They are retained for provenance and are not the current workflow. Do not execute
them to improve or replace the Golden Walk, or apply their corrections to the
Run/Idle/Jump sequence. Use only the authoritative Golden workflow above.

CP-20260930-02: 763 unique source files; 765 inspected takes; 499 semantic proposals;
zero canonical approvals. Existing Godot assets are mapped in
`art/production/master-animation-library/manifests/RuntimeReuseManifest.json`.
The comparison covers all nine unique `walk_forward` takes (ten source records), not just the shortlist.
`CandidateReviews.json` retains the whole group; the shortlist is navigation only.

## Regenerate interpretation without rescanning

Run from the application directory with a Python runtime containing NumPy:

```text
python tools/animation-library/refresh_cached_roles.py
python tools/animation-library/classify.py
python tools/animation-library/score_candidates.py
python tools/animation-library/rank_candidates.py
python tools/animation-library/test_pipeline.py
```

`refresh_cached_roles` reuses inspection metadata and preserves inspection rig
hashes/take IDs. `score_candidates` uses saved pose caches. Metadata-only refresh
does not approve motion. Stance diagnostics exclude low, fast swing toes, and the
ranking never awards a quality score for the same velocity threshold used to
define contact. Explicit joint aliases reject ambiguous mappings and roll helpers.

## Review derivatives in Blender and Godot

`retarget_contacts.py` runs under Blender with `--source`, `--target`, `--output`
and `--action`. Use working FBX copies and the existing Echo review GLB. The full
source take is baked at 30 FPS from frame zero; original timing, bake duration,
source/target hashes, transport, contact intervals and joint positions stay in
the JSON sidecar. No source writes or new procedural animation are performed.
Fixed leg lengths and source bend planes guide the solve; foot orientation is
transferred relative to source rest, so a different neutral toe slope is not
mistaken for a permanent tiptoe pose. This pilot is limited to compatible
humanoid locomotion; it is not approved for arbitrary climbing/combat/root turns.

Use the isolated `.tmp/master-animation-library/godot-review` project:

1. Import the candidate GLB with Godot editor `--import`.
2. Run `configure_review_import.gd -- res://candidate.glb` in that project.
3. Reimport; the review profile disables lossy animation optimization/compression.
4. Run `review_contacts.gd -- res://candidate.glb ABSOLUTE_SIDECAR ABSOLUTE_OUTPUT`.

The review records every frame from front/side/back, checks imported timing and
positions, and validates limb lengths while allowing pelvis weight transfer.
Use absolute filesystem paths for sidecar/output because Godot changes its
working directory. Invalid sidecars terminate with FAIL instead of hanging.
Headless review verifies data only; graphical review supplies the images.

Default Godot import removed rotation keys and introduced approximately 5 mm
contact errors in this pilot. The precise review profile preserved the baked
motion; runtime optimization needs an independent contact gate. Relevant primary
implementation: [Godot scene importer](https://github.com/godotengine/godot/blob/master/editor/import/3d/resource_importer_scene.cpp).

## Publication boundary

Candidates and rejected derivatives stay in `art/production/.../staging` or
ignored `.tmp`, never in `godot/Animations`. Only visually approved canonical
clips with source/rig/license/selection evidence enter that runtime library.
Joint fidelity alone does not approve shoe skin contact, limb twist, clothing,
loop seam, player speed, transitions, facial acting or fingers. Source mocap takes
precedence over generating a replacement when it satisfies the action.

## Full walk comparison and playback

```text
python tools/animation-library/compare_walks.py --blender ABSOLUTE_BLENDER_EXE --godot ABSOLUTE_GODOT_EXE --render
```

The v3 batch preserves previous v1/v2 evidence, bakes to production staging and
renders nine time samples from each of three views in an isolated project. The
report is `manifests/WalkComparison.json`. Checks include original take timing,
source hashes, imported joint/limb fidelity, evaluated shoe skin and full-take
loop endpoints. A measured record is not an approval. Duplicate archive records
remain linked to their shared take, and FBX/BVH/Unreal variants stay distinct.

Retargeting uses explicit Mixamo/Motus, Unreal and Rokoko joint contracts.
Rokoko's thigh/shin naming and FBX armature-object hip are resolved explicitly.
Planar alignment uses yaw: opposite forward vectors must not rotate the up axis.
Already in-place takes retain local pelvis travel; fitted transport is added by
the review scene. Sole corrections preserve source foot rotation and horizontal
paths; candidates exceeding the correction bound require inspection.

Resume requires unchanged source/take/target/tool/derivative hashes. A shoe
diagnostic change reruns that measurement without rebaking the mocap. Rendering
and baking have bounded process lifetimes and terminate their own process tree
on timeout. Blender processes use separate user-resource directories and offline
factory startup to avoid loading the workstation's extensions/preferences.
See [Blender resource variables](https://docs.blender.org/manual/en/latest/advanced/command_line/arguments.html).

Copy `review_walk_loop.gd` into the isolated project and run it with candidate,
absolute sidecar and output-directory arguments. It advances AnimationPlayer
through four loops at 30 FPS without seeking across seams, validates pelvis
transport, and renders frames when a graphical renderer is present. This uses
[AnimationMixer manual processing](https://docs.godotengine.org/en/latest/classes/class_animationmixer.html).
It does not measure controller transitions or phone frame time.
