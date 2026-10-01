# G0 Vertical Slice Foundation — Godot technical proof

This is an isolated, non-Canon proof for the first 3D slice of 11:11. It is
intentionally made from Godot primitives so that the controller, camera,
collision, interaction, objective feedback, lighting and quality fallback can
be measured before a final VRoid/Blender asset is approved.

## Run

Open this folder with the pinned Godot 4.7.2 portable build, or run the safe
repository wrapper from the repository root:

`npx tsx tools/godot/run-godot.ts -- smoke artifacts/eleven-eleven/art/godot/technical-proofs/g0-vertical-slice`

The headless proof emits `GODOT_SMOKE_OK` and exits. A visual run is playable:

- `WASD` or arrow keys: move Echo
- `Shift`: sprint
- `E`: interact when the prompt appears
- `Q`: toggle HIGH / SAFE reduced effects
- `R`: reset the slice

The room is a small Sector 11-inspired test space. It is not a final Manhwa
environment or a Canon character lock. Godot is the Owner-selected G0 engine;
production promotion remains measurement- and quality-gated.

## Tripo candidate import

The official Tripo Bridge plugin is enabled for this isolated proof and listens
only on `127.0.0.1:60650` while the Godot editor is open. Tripo DCC Bridge
exports are staged under `res://TripoModels`; an imported model remains a
candidate until the visual, topology, deformation, performance and provenance
quality gates pass. Never overwrite the current rollback assets during import.
