# Sector 11 wake capsule runtime audit — 2026-09-20

## Source and spend record

- Source workspace: authenticated Tripo Pro project asset
  `standalone-game-ready-hero-asset-one-vertical-human-containment-and-w-cffdd6d3-c165-419a-8159-e6eef46a5ec2`.
- Approved operation: one standard Quad retopology pass, Smart Mesh disabled,
  50,000 polygon request.
- Confirmed and actual cost: 10 Tripo credits. Account balance changed from
  3,020 to 3,010. No texture, animation or additional generation credit was spent.
- Downloaded source: `containment capsule 3d model (1).glb`, preserved only as
  an ignored production intermediate; it is not shipped to players.

## Direct-result rejection

The paid export was not accepted merely because generation completed. Inspection
measured 3,304,644 bytes, 126,364 triangles, 62 meshes/primitives, 62 materials,
no textures and 115 Khronos validation errors. Its presentation parts were also
visibly exploded away from the central shell. This failed runtime structure,
silhouette coherence and validation gates.

## Corrective authoring pipeline

`tools/blender/build_sector11_capsule_v2.py` provides the reproducible correction:

1. import the untouched Tripo retopology result;
2. remove eight detached presentation-only pieces;
3. normalize the coherent central shell to a 2.8 m authored height;
4. reduce only the shell to the environment triangle budget;
5. assign a restrained seven-material graphite, steel, rubber, interior, signal,
   door-signal and transmissive-glass hierarchy;
6. build a separate beveled glass door and hinged `CAPSULE_OPEN` action; and
7. export a raw authoring GLB for strict optimization and validation.

The runtime derivative is then generated with the pinned Meshopt pipeline at
`public/assets/props/sector11-wake-capsule-v2.glb`.

## Accepted runtime measurements

- SHA-256: `9F69F129EB25F700CAB5A0AFFE1204D9E7165BFF0AE338A0B0DA4F4217C70866`
- File size: 358,148 bytes
- Geometry: 70,570 triangles / 43,900 vertices
- Structure: 4 meshes / 8 primitives / 7 materials
- Animation: one `CAPSULE_OPEN` action, frames 1–42 at 24 fps
- Texture count: 0
- Khronos validation: 0 errors / 0 warnings
- Required runtime extensions: `EXT_meshopt_compression`,
  `KHR_mesh_quantization`

Microsoft Edge presentation evidence waits for the real four-mesh capsule, turns
the existing third-person camera without moving Echo or granting progress, and
captures the open pod in the authored room. The capsule remains beneath the 80k
environment triangle budget and the normal GLB transfer budget.

## Quality boundary

This checkpoint accepts a coherent, animated and validated runtime prop. It does
not claim final AAA surface art or one-to-one Manhwa likeness: the source contained
no texture maps, so the current material hierarchy is authored procedural PBR.
Close-up decals, controlled wear, bespoke normal detail, fluid/condensation FX,
door-contact sound and a human art-direction review remain separate gates. The
rejected paid export is evidence of disciplined quality control, not a delivered
asset.
