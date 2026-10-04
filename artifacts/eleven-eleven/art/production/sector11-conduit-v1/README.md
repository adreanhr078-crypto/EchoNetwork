# Sector 11 conduit — Jutsu presentation candidate v1

Status: **REVIEW_PENDING**. Isolated art candidate for the existing
`energy_power_conduit` footprint. No gameplay, collision, player, Golden,
animation, room layout, or Canon changes. Runtime and phone acceptance remain
unverified until the parent integrates and reviews it.

Higgsfield 3D Jutsu project:
https://higgsfield.ai/3d-jutsu/638d295b-dbf6-4c56-95aa-516e365d4b22

One authoring mutation: `sector11-conduit-author-v1-20261001`, succeeded at
revision 1. Uses the authenticated Higgsfield connector, **not** the existing
API-key account. The operation returned no charge; actual authoring spend is
unknown. Seedance 2.5/2.0 remain the preferred video models; this is editable
Blender geometry, with no video job or generated animation.

## Files

- `conduit-jutsu-r1.blend`: unmodified downloaded editable source, semantic
  parts, bevel modifiers, portable Principled materials and a review studio.
- `sector11-conduit-v1.glb`: presentation prop only; baked bevels, 7 mesh
  nodes / 7 draw primitives, 6 materials, 6,920 triangles, 259,968 bytes.
- `conduit-jutsu-full-scene-r1.glb`: original Jutsu scene export retained for
  provenance; includes the review ground/camera. Do not integrate this file.
- `build-conduit.py`: exact Blender construction submitted to Jutsu.
- `export-candidate.py`: local evaluated-geometry check, energized preview and
  prop-only export. It does not save changes to the source `.blend`.

## Integration contract

Metres: ground origin, radius <= 0.45, height 1.8. Blender +Z is up; exported
glTF +Y is up, and Blender -Y front becomes glTF +Z. Keep the existing Godot
collision and interaction area. The lens centre is 1.3m above ground.

`CoreMesh` and `StatusSignalMesh` carry the dormant amber signal material.
For energized presentation, explicitly bind both to a cyan material; do not
change rewards, puzzle state or interaction semantics from this asset. The
two-state images are review references, with no keyframes or animation.

## Verified evidence

`audits/evidence/character-shading-20261001/higgsfield/` holds Jutsu provenance,
geometry/export verification, actual dormant/energized images and the strict
GLB report. Radius 0.449999988m and height 1.800000072m pass tolerances. Khronos
validation: 0 errors, 0 warnings; 7 informational unused-UV messages. No
required extensions, textures, armatures, actions, skins, cameras or lights in
the portable prop export. Studio AREA-light warnings apply only to the original
full-scene export; the portable prop intentionally excludes lighting/studio.

Both preview images were inspected: lens visible, service detail legible,
ground contact/framing intact. This establishes a reviewable candidate, not
professional artistic acceptance, Godot material parity or mobile performance.
