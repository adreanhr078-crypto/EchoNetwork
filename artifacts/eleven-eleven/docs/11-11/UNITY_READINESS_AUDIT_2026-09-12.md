# Unity readiness re-audit — 2026-09-12

Verdict: **G0-A UNVERIFIED; migration incomplete. No visual/AAA pass.**

Owner direction remains Unity as the target engine, preserving Godot unchanged.
This audit supersedes any interpretation of the earlier structural migration
report as proof that the game opens or runs in Unity.

## Observed workstation state

- The official installer has completed and `Editor/Unity.exe` is present at
  `C:/Tools/Unity-6000.3.23f1-Official/Editor/Unity.exe`.
- The editor starts and reports `6000.3.23f1`; the first project batch run is
  blocked only by the missing Unity account entitlement/license.
- 7-Zip 26.02 detects the installer as a PE file; forced NSIS opening fails.
  No installer was executed. The owner's portable/no-install constraint remains.
- The official Windows install is complete. A portable ZIP can be created only
  after license/import verification; Unity does not publish a supported Windows
  Editor ZIP.

## Licence alternatives

Unity Personal is activated by signing in to Unity Hub; it cannot be enabled by
placing a password in a file or bypassing the entitlement check. Manual
`.alf`/`.ulf` activation is intended for eligible serial, Enterprise or Industry
licences, not as a workaround for a Personal account. If Hub sign-in is
unavailable, the practical production path is the preserved portable Godot
proof; the Unity project remains staged for a later licensed migration.

## Safe corrections made

- Removed automatic scene rebuilding on assembly reload (unsaved-scene risk
  and an unqualified static FindFirstObjectByType compilation defect).
- Added explicit imported-asset validation, save-result checking and interactive
  save/overwrite confirmation. Build settings are registered via Unity API.
- Attached Echo's visual spawn to the moving controller; set foot-aligned capsule
  and removed double-height camera target offset.
- Corrected EditorBuildSettings class ID and SceneRoots Transform reference.
- Removed false READY/SMOKE_OK claims. Component presence is UNVERIFIED; failure
  and incomplete batch checks exit nonzero.
- Corrected migration manifest claims that engine-specific rebuilding was done.

## Still required — before quality production

1. Open/import/compile with the licensed Editor and resolve actual diagnostics.
2. Rebuild Godot's collision shell, spawn and interaction positions with verified
   coordinate conversion. Existing arbitrary cubes are not room parity.
3. Restore ordered signal/clue/exit state, prompts, reset and quality controls.
4. Import and play Idle/Walk/Run/Interact; compare skinning, scale and orientation.
5. Compare materials, transparency, lighting and four camera angles with original
   Godot/GLB and approved Manhwa. Check camera clipping and no falling through floor.
6. Run actual Play Mode/build tests and measure performance. Web tests cannot
   compile C# or establish visual parity.

## Connected production tools

Higgsfield read succeeded: project 63a65cb7-da4a-45a7-8f0a-a91d21d2d2eb,
revision 3, no active operation. Remote GLB is 598784 bytes, whereas the local
Blender-reviewed runtime derivative is 689236 bytes; do not silently swap them.
Tripo CLI doctor found no authorization. Device login started; no generation
or credits spent. No Flow generation, Firebase or Figma changes were needed
for this prerequisite audit. Echo's mandated VRoid/Blender path is unchanged.

## Verification boundary

Verified this run: `npm run agent:preflight` PASS;
`node --test tools/unity/migration-safety.test.mjs` 3/3 PASS;
`node tools/unity/validate-unity-migration.mjs` STRUCTURE_OK;
`npm run agent:postflight` PASS (content, TypeScript, foundation tests, production
build and doctor); `git diff --check` PASS with existing CRLF warnings.
Production build retains a large-chunk advisory. These are not a C# compiler
or gameplay test; no Unity runtime verdict is implied.
