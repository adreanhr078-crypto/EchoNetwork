# Sector 11 Modular Wall Kit v1

## Files

- `build_sector11_modules.py` builds the Blender scene and exports both game meshes.
- `sector11-modular-kit-v1.blend` is the editable Blender source.
- `sector11_observation_module_v1.glb` is the observation-bay module.
- `sector11_service_module_v1.glb` is the service-hatch module.
- `sector11-modular-kit-v1.png` is the Blender review render.
- `godot-sector11-modular-review-v5.png` is the 1280×720 in-engine review frame.
- `godot-sector11-modular-review-v5.avi` is the full 11-second manual runtime capture.
- `build_sector11_ceiling_tile.py` builds one editable, repeated ceiling-light cassette.
- `sector11-ceiling-tile-v1.blend`, `sector11_ceiling_tile_v1.glb`, and `sector11-ceiling-tile-v1.png` are its Blender source, Godot export, and underside render.
- `godot-sector11-ceiling-review-v1.avi` and `godot-sector11-ceiling-review-v1.png` are the six-second in-engine review and 1280×720 frame.

## Godot integration

The GLBs are imported by `scripts/environment/sector11_visual_shell.gd` and placed as ten side-wall modules: two observation bays and eight service modules. They sit on the existing corridor wall collision, so they add no duplicate blockers. Structural ribs were moved behind the panel faces. The imported mesh local-up axis was corrected before export; the game capture confirms the wall pieces stand upright and fit the 7.2 m shell.

Eight ceiling cassettes occupy the gaps between structural crossbeams. Each has an emissive diffuser, light guides, vents, status lamps, and fastening details. The existing OmniLight nodes provide actual illumination. The tiles add no collision and sit partly in the ceiling shell. Their upright export and underside were inspected in Godot's Compatibility renderer.

## Review and limits

The modules are original Blender-built hard-surface meshes with beveled armor, inset glass or hatch, fasteners, conduits, indicators, and readable labels. They break up the repeated procedural silhouette, but their forms remain simple and do not make the corridor Genshin-quality. The floor, gate surround, room shell, lighting, and character still need a complete art pass. The main camera review showed the pieces with the cryopod, Echo, guide core, opening objective, and dialogue. Forward+ crashed on this Intel UHD machine while requesting a 128 MB Vulkan buffer; Compatibility rendered the new tiles with feature warnings for SSR and volumetric fog, so high-tier visual approval is still open.

No Tripo or Google Flow credits were spent on this kit. The Blender source remains editable so proportions and colors can be iterated without regenerating assets.
