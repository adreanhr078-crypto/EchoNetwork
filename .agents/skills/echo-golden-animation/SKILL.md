---
name: echo-golden-animation
description: Diagnose poor or failed EchoNetwork skeletal animation imports, retargets or Blender/Godot differences against the Owner-approved frozen Walk. Use on failure, no later than the second bounded attempt; may use first when quality benefits.
---

# Echo Golden Animation

Use the approved Walk as a fixed regression reference. This skill applies to EchoNetwork character skeletal motion; it does not authorize generating new motion or changing the runtime character.

Routine successful clips may use the proven frozen pipeline directly without loading this skill. If motion is poor or a check fails, retain evidence and use this skill immediately, or after at most one evidence-driven second attempt. Invoke it by the second attempt at the latest, before any further repair; avoid repeated speculative retries. Use it first when that best serves quality. All Golden integrity, source-preservation, isolation, timing, sequential-stage and frozen-setting restrictions remain mandatory whether or not this skill is loaded.

The maintained project is `C:/Users/yasmo/EchoNetwork`, active app `artifacts/eleven-eleven`. Read its current work card and current Owner instructions; later Owner directions take precedence over this skill. The reference is `art/production/master-animation-library/golden/walk-v1/GoldenReference.json` inside the app. It was explicitly Owner-approved on2026-09-30. Its frozen GLB is SHA256 `21f818d302f134068de3a1eeacf3e23861e3159149567db63b6d278469a0047d`.

## Protect the reference

Run `python tools/animation-library/golden_reference.py` from the app before and after each motion stage. Never reseal or rebake the approved Walk. Preserve its .blend, GLB, source/target, reference data, import profile and tools. The guard checks both original evidence and frozen snapshots. Use a new per-motion evidence folder and isolated Godot project, never the Golden directory or existing runtime assets.

Do not improve or manually edit source keys, change Skeleton Retarget or Root Motion, replace the player, or introduce AnimationTree/blending during verification. No global project settings changes. These are current Owner requirements, not general rules for unrelated projects.

## Process one motion at a time

Process Run (an existing Jog source if selected), then Idle, then Jump sequentially. Finish the current motion's evidence before starting the next. A request to continue Jump after Run does not establish that Idle is complete; check its evidence unless later explicit Owner directions reorder the stages. Choose an existing source from CandidateReviews/SourceInventory rather than reinventorying or generating. Retain its real semantic identity: MOB1_Jog_F is jogging, not proof of sprint quality. Distinct source rig hashes require inspection, not automatic rejection or guessed remapping.

Use `single_motion.py` under Blender: `--mode inspect|bake|export --output ABSOLUTE_CASE_FOLDER --take-id EXACT_TAKE_ID --clip-name Run|Idle|Jump`. It checks the complete transfer loop plus upstream rest/alignment/export expressions against frozen Walk. Only source identity, frame count/duration, action name and output paths vary.

The timing guard uses `native_timing.py` to read the original binary FBX GlobalSettings and checks native FPS, candidate metadata FPS and imported scene FPS are all 30. Source first frame must be 1, the last frame integral, and the frame range must match candidate metadata. Unsupported source rates or start frames, unspecified native FPS and timing disagreements fail closed and require isolated diagnosis. Never relabel FPS, resample, trim or pad source keys to fit this contract. Frames 1–74 at 30fps contain 74 samples over 73/30 seconds; a 60fps variant is not interchangeable.

Inspect the original source first, including rest matrices, mapping, local bone axes, armature transforms, Hips and thigh rotations. Render source inspection before baking. The transfer preserves full source world/rest rotations, original Hips translation scaled once, and target rest offsets. No IK, foot correction, root fitting, smoothing or authored replacement keys.

If early source poses jump sharply into the later motion, inspect native curve first times/values, static Model defaults, AnimationLayer connections and the imported action/slot/rest before baking. Sparse FBX axes may start after time zero; the pinned importer can fill earlier samples from static Model defaults. Do not declare the authored motion bad or trim keys without proving native evaluation. Quarantine an unsupported import with its diagnosis and untouched inputs; a measured cause may justify a bounded second attempt using another existing library source through the same Golden pipeline. That does not authorize generation or a speculative importer fix. Read the [measured Idle boundary diagnosis](C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven/audits/evidence/golden-sequence-20260930/idle-attempt-01/ROOT_CAUSE.md) when this symptom appears.

After bake, verify Blender replay and visually compare source/target. Export only with numerical PASS and a visual review tied to the exact saved .blend SHA256. ACTIVE_ACTIONS must produce exactly one named baked clip. Do not label generated screenshots as reviewed without inspecting them.

Import that GLB alone in a per-motion Godot project. Apply only the frozen `configure_review_import.gd` diagnostic profile, preserving animation keys, then reimport. Run `single_motion.gd` with the absolute Blender reference and output JSON; compare every mapped joint at every original sample time through AnimationPlayer alone. Use the frozen C*R joint quaternion conversion and colon-to-underscore bone lookup. Render-frame cropping is a camera issue, not evidence of retarget failure.

If a stage fails, retain logs and isolate the cause before any local fix. Do not compensate by editing correct motion or unrelated settings. Default optimizer once reduced ToeBase37 keys to12/14 and introduced6.46mm error; Golden key-preserving import matched Blender within0.00136mm. That diagnosis does not justify changing Skeleton Retarget/Root Motion.

Complete the current motion's evidence before starting the next. Record exact source/tool/artifact hashes, numerical and visual results, source preservation and Golden integrity. Project preflight/postflight and the existing quality gate still apply. Golden acceptance is distinct from runtime integration or acceptance of the whole game.
