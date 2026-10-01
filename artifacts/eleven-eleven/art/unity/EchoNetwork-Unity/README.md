# EchoNetwork Unity migration (G0 only)

This is an isolated Unity migration proof for the current Sector 11 room. It
does not replace the web runtime, server authority, Canon, or the preserved
Godot proof.

## Pinned editor

- Unity 6000.3.23f1
- Changeset `09d2ecc7fb28`
- Official release page: <https://unity.com/releases/editor/whats-new/6000.3.23f1>
- Windows distribution is an official EXE installer; Unity does not publish a
  supported portable Windows Editor ZIP. The downloaded installer is staged
  outside the repository and is not executed by this migration.

## Migrated inputs

- `Assets/Art/GLB/Sector11_G0_Room.glb` — lossless source copied from Godot.
- `Assets/Art/GLB/Echo_G0_MotionStudy.glb` — lossless animated source copied from Godot.
- `Assets/Art/GLB/Higgsfield_Audit_R3_Runtime.glb` — reviewed Hexfield/Higgsfield runtime study.
- `Assets/Art/GLB/Higgsfield_G0_Runtime.glb` — earlier isolated runtime study.
- `Assets/Art/FBX/Sector11_G0_Room.fbx` — Blender conversion for Unity's native FBX importer.
- `Assets/Art/FBX/Echo_G0_MotionStudy.fbx` — Blender conversion retaining the animation clips.

The FBX files are a bridge, not a claim that the art is final AAA canon. GLB
files remain the fidelity source for later glTFast/importer comparison.

## Scene build

**Audit 2026-09-12: NOT a completed migration.** The scene on disk is a
placeholder. Automatic scene replacement on editor reload has been removed;
the menu action is explicit and asks before replacing the generated scene.
The builder is scaffolding: room collision, animation playback, ordered
interaction state, source lighting/material fidelity and runtime tests remain.
The component probe deliberately returns an unverified/nonzero batch result
until an actual Play Mode run is performed.
Do not treat web tests or asset hashes as Unity compilation or gameplay evidence.

Open `Assets/Scenes/G0_Sector11_Escape.unity`, then run
`11.11 > Build G0 Sector 11 Escape Scene`. The builder creates the room anchor,
third-person Echo controller, camera, lighting, and the three current G0
interactions (signal node, memory clue, exit door). It deliberately does not
add combat, open world, economy, or other later-plan systems.

## Preserved Godot source

`../migration/source-backups/godot-g0-vertical-slice-2026-09-12/` contains the
complete original Godot proof. The original Godot folder in
`art/godot/technical-proofs/g0-vertical-slice/` is untouched.
