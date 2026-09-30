# Master animation production tools

Resume from `docs/internal/production/CURRENT_WORK.ar.md` and the execution record.
Do not inventory/extract the protected source ZIP again when its saved hash and
working copies match. Source archives are never modified by these tools.

## Current checkpoint

CP-20260930-02: 763 unique source files; 765 inspected takes; 499 semantic proposals;
zero canonical approvals. Existing Godot assets are mapped in
`art/production/master-animation-library/manifests/RuntimeReuseManifest.json`.
The next comparison is all nine `walk_forward` candidates, not just the shortlist.
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
