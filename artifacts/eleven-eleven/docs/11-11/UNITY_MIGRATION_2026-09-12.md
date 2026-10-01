# Unity G0 migration checkpoint — 2026-09-12

## Decision boundary

The Owner explicitly changed the G0 migration target to Unity. The target is
Unity 6000.3.23f1 (changeset `09d2ecc7fb28`). The web/React runtime and all
server-authoritative systems are outside this migration and were not changed.

Unity's official Windows distribution for this release is an EXE installer or
Download Assistant. Unity does not publish a supported portable Windows Editor
ZIP. The official Editor installer and Download Assistant are staged in
`C:/Tools/Unity-6000.3.23f1-Official/downloads/`; neither was executed, so no
system installation, activation, license, or credential state was changed.

## What was preserved

- Original Godot proof remains at `art/godot/technical-proofs/g0-vertical-slice/`.
- Complete dated backup: `art/unity/migration/source-backups/godot-g0-vertical-slice-2026-09-12/`.
- Backup evidence: 225 files, 36,572,018 bytes.
- The original room and Echo GLBs were copied byte-for-byte and their hashes are
  recorded in `art/unity/migration-manifest.json`.
- Official Editor installer SHA-256: `C00E1DC2EA519F18E68C3FB6C69366DF916738BCC3A8C67537B293C2994DBC72`.
- Download Assistant SHA-256: `D618A2FB1279AC169D4733A95720D96C2BB6FBE1D158016BB7FB54A901D5BC00`.

## What was migrated/rebuilt

Unity project: `art/unity/EchoNetwork-Unity/`

- Sector 11 room GLB and reviewed Higgsfield runtime GLBs retained under
  `Assets/Art/GLB/`.
- Unity-native FBX bridges generated from the room and Echo GLBs with Blender
  5.2.1, embedded textures, and animation baking under `Assets/Art/FBX/`.
- Godot-specific movement/interaction behavior rebuilt as isolated C# scripts:
  `UnityG0Bootstrap`, `ThirdPersonController`, `G0Interactable`, and
  `G0SmokeProbe`.
- `G0SceneBuilder` reconstructs the bounded room anchor, Echo spawn, camera,
  directional light, and the three existing G0 interactions. It does not add
  combat, open world, economy, Canon progression, or duplicate web authority.

## Evidence and remaining gate

| Check | Result |
|---|---|
| Repository preflight before edits | PASS |
| Official version/changeset resolved | PASS |
| Godot original preserved and backed up | PASS |
| GLB copy/hash/FBX bridge structure | PASS (`UNITY_MIGRATION_STRUCTURE_OK`) |
| Blender FBX re-import (room + Echo) | PASS; 4 animation clips present |
| Unity Editor found on PATH or standard paths | BLOCKED — not present |
| Unity Editor open/import/play smoke | UNVERIFIED — requires the official Editor |
| Visual parity/performance/accessibility | UNVERIFIED — requires Editor/device evidence |

This checkpoint is therefore **migration prepared / runtime unverified**. No
production greenlight is claimed. The next step is intentionally paused for the
Owner: either provide/approve a supported Unity Editor installation path, or
continue with the preserved Godot/Three comparison before locking one runtime.
