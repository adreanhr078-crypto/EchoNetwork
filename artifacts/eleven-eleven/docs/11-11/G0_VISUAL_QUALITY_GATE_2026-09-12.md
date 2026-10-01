# G0 visual quality gate — Manhwa and owner-video target

Date: 2026-09-12  
Authority: ordered Manhwa first; the three owner-supplied MP4 files are motion,
lighting, composition, and finish references. They do not replace Canon.

## Reference audit

The videos establish a 2D-anime cinematic target with:

- a recognisable black-haired Echo silhouette in every focal shot;
- expressive face/eyes and layered hair rather than a generic avatar;
- a black technical coat with small red/cyan accents and readable material breakup;
- dense industrial wall panels, pipes, screens, wet/specular floor response, and
  motivated cyan/magenta practical lighting;
- stable character identity across wide, medium, and close shots;
- controlled contrast: blacks remain dark while faces, doorways, and interaction
  targets stay readable;
- restrained camera motion and clear focal progression toward the experiment.

Contact sheets used for the audit are stored in
`art/blender/reference/video-quality-audit/`.

## Current evidence and decision

| Area | Evidence | Gate |
| --- | --- | --- |
| Corridor scale/composition | Higgsfield revision 5; 12 x 24 x 6.2 m, 113 organised objects | PASS for G0 blockout |
| Lab language | four containment tubes, overhead utilities, wake platform, sealed door | CONDITIONAL PASS |
| GLB structure | Khronos validator: 0 errors, 0 warnings | PASS |
| Blender visual read | three 960 x 540 Eevee review angles | CONDITIONAL PASS |
| Godot import/runtime | Godot 4.7.2 import, smoke, and camera regression | PASS |
| Godot lighting/material finish | visible capture remains too dark/flat and lacks surface micro-detail | FAIL |
| Echo identity | current model is a local motion proxy and does not match the videos/model sheet | FAIL |
| Facial performance | no approved face rig or close-up proof | FAIL |
| Hair/cloth secondary motion | not authored | FAIL |
| Opening cinematic | not authorised until room and Echo gates pass | BLOCKED BY QUALITY |

## Non-negotiable acceptance criteria

The current character must continue to be labelled `PROXY`; it cannot be approved
as Echo. VRoid is optional, not mandatory: the base may come from Higgsfield,
VRoid, or another rights-cleared pipeline, whichever survives the visual and
deformation comparison. Every candidate still requires Blender refinement and
four rendered reviews (front, three-quarter, profile, close-up) against
`echo-ex011-model-sheet-v1.png`. It must include the approved
hair silhouette, facial proportions, two-tone eye treatment only where Canon
requires it, black layered coat, exposed-skin EX-011 placement, facial rig,
and tested hair/coat deformation.

The room gate requires readable 10–90% luminance range in the gameplay camera,
no clipped emissive panels, visible dark-surface separation, a readable door at
the end of the corridor, material breakup at near/mid/far distances, and collision
around walls and containment tubes. Three runtime captures plus an interactive
playtest are required before lock.

## Next bounded work

1. Generate and compare a high-consistency Echo turnaround in Higgsfield; use
   VRoid only if it produces the stronger rights-cleared base.
2. Build a new 3D candidate from the approved turnaround without replacing the proxy.
3. Refine face, hair cards/clumps, coat silhouette, materials, and rig in Blender.
4. Rebalance the G0 room in the production renderer and add authored surface
   detail without expanding beyond this corridor.
5. Import both assets into Godot, run structural/performance checks, and capture
   wide/medium/close evidence.
6. Only then produce the short opening cinematic through Flow/Higgsfield.

No claim of AAA, Genshin parity, or visual lock is permitted while either FAIL
above remains open.

## 2026-09-13 MPFB anatomy checkpoint

- Installed the official MPFB extension into the verified Blender 5.2.1 LTS
  portable build and generated a native Blender human base at the approved
  1.72 m design height.
- Added a game-oriented weighted skeleton and retained MPFB topology/shape keys,
  so this candidate is technically suitable for later animation and facial
  refinement. It is saved as
  `art/production/echo-hero-mpfb-v1/echo-hero-mpfb-base-v2.blend`.
- Applied a restrained, reversible anime-proportion target stack (larger eyes,
  narrower triangular jaw, reduced nose depth/width, and adjusted head scale).
  Four review renders were captured at 1200 x 1600.
- The topology/rig foundation is a **PASS** for continued sculpting. Echo identity
  remains a **FAIL**: the face is still generic, there is no approved hair,
  clothing is only a diagnostic coverage material, and the eye geometry is
  review-only. Nothing from this checkpoint may replace the Godot proxy yet.
- Next gate: author the Echo-specific face silhouette, proper sclera/iris/cornea,
  layered black hair and the primary coat blockout, then re-render front,
  three-quarter, profile and close-up against the manhwa/turnaround.
- A first procedural strand-direction study was saved as
  `echo-hero-mpfb-hair-v1.blend`. It is **REJECTED** for integration: the locks
  establish the intended asymmetric silhouette but read as separated hard
  spikes, lack a continuous scalp mass, and fail the close-up material/shape
  standard. It remains only as a direction map for a smooth surface-sculpted
  hair pass.
- Higgsfield 3D Jutsu was inspected in the signed-in account. Its current UI is
  a scene blockout/staging-to-video workflow (sets, props, characters, cameras,
  then Seedance), not a downloadable hero-character mesh authoring surface.
  It remains useful for cinematic previs but is not accepted as the source of
  Echo's production game mesh.

## 2026-09-13 identity-pass checkpoint

- Built `art/production/echo-identity-pass-v1/echo-identity-pass-v2.blend`
  from the rigged MPFB base. The pass adds reversible Echo-specific facial
  ratios, separate sclera/iris/pupil/highlight layers, eyebrows, a continuous
  scalp shell, and broad overlapping hair masses.
- Technical continuity remains intact: the original MPFB mesh, 41 shape keys
  and 53-bone game skeleton are preserved. The candidate still has not replaced
  the runtime proxy.
- Visual audit: eye readability and skull coverage improved substantially over
  the first hair-direction study. The close-up still fails the hero bar because
  the face is generic, some locks read as repeated procedural forms, and the
  diagnostic body coverage is not authored clothing. Gate remains **FAIL**.
- Completed one deliberately scoped Higgsfield GPT Image 2 reference job at
  4K/high quality (job `cdaf2262-7857-4475-a249-8696e6d6405a`, 11 credits) and
  saved the synchronized front/profile/three-quarter sculpt guide as
  `art/production/echo-higgsfield-turnaround/echo-head-sculpt-sheet-higgsfield-v1.png`.
  The remaining Higgsfield balance after this job is 35 credits. This reference
  is for corrective Blender sculpting, not a substitute for a game mesh.
- The next legal move through the gate is to apply the new synchronized head
  reference to a manual face/hair corrective pass. Coat production stays behind
  that identity check so clothing detail cannot conceal a weak face.
- A first correction from that sheet changed the lower-face length and converted
  the hair from round swept tubes to thin overlapping ribbons. The construction
  is technically cleaner, but the close-up still exposes a cap-like crown and
  insufficient likeness. It remains **NOT APPROVED**; no Godot import was made.
- Split the 4K sheet into four lossless 1440 x 1440 sculpt views and embedded the
  synchronized front/profile images in
  `art/production/echo-identity-pass-v1/echo-sculpt-workspace-v1.blend`.
  The procedural hair collection is hidden in this workspace so it cannot bias
  or obstruct the manual likeness sculpt.
- Tripo CLI device authorization completed successfully on 2026-09-13. The
  local `default` profile and overseas API endpoint both pass the official
  diagnostic check. The account currently reports **0 available credits**, so
  no multiview generation was submitted and no paid action was taken. Tripo is
  technically ready but remains unavailable as a production source until the
  account receives credits; Blender corrective sculpting continues meanwhile.
- Identity pass v3 replaced the rejected flat ribbon study with twelve closed,
  tapered volumetric hair masses and rebuilt both iris/pupil/catchlight stacks
  with matched convergence. Four 1400 x 1600 evidence renders and the reversible
  Blender source are stored in `art/production/echo-identity-pass-v3/`.
  Technical continuity and silhouette coherence improved, but the visual gate
  is still **FAIL**: the hair remains a coarse blockout rather than layered
  authored locks, the MPFB eyelids and facial planes do not match the synchronized
  reference, the rear silhouette is incomplete, and clothing remains diagnostic.
  Pass v3 is therefore evidence only and is forbidden from replacing the Godot
  proxy. The next acceptable path is true reference-aligned sculpt/retopology or
  a high-fidelity multiview base followed by Blender correction—not another
  procedural cosmetic pass.
- Tripo Studio free-plan evaluation started with the approved full-body Echo
  A-pose reference and model `v3.1 – Best Quality`. The one-time 8K trial reduced
  the displayed first-generation cost from 65 to 0, preserving the account's
  200 monthly Studio credits. Studio task
  `904926bd-9f21-46f5-a2d7-42d2995cd41a` is an evaluation candidate only. No
  retopology, segmentation, rigging, animation, download integration, or Godot
  replacement is authorized by task completion alone; the generated geometry
  must first survive silhouette, face, hair, rear reconstruction, clothing,
  texture, topology and licensing review.

## 2026-09-12 character-source checkpoint

- Higgsfield produced a dedicated 4K, single-character A-pose reference at
  `art/production/echo-higgsfield-turnaround/echo-front-apose-higgsfield-v2.png`.
  This is the current approved **modelling reference**, not an approved 3D asset.
- The Tripo CLI/device authorisation did not complete even after a fresh code, so
  that route was suspended instead of asking the owner to repeat the same login.
- Higgsfield's catalog exposes Meshy 7 Image-to-3D, but the connected toolset does
  not currently expose its required `generate_3d` action. Magnific was tested as
  the fallback and rejected the request because its MCP requires a Premium plan.
- A local Blender procedural study was saved under
  `art/production/echo-hero-foundation-v3/`. Its rig/export pipeline works, but its
  primitive anatomy, hair and clothing surfaces do not meet the modelling
  reference. It is explicitly **REJECTED FOR GAME INTEGRATION** and must not
  replace `EchoMotionProxy_NotCanon`.
- The Echo identity gate therefore remains **FAIL**. The next valid production
  action is a true sculpt/retopology pass (or a successful high-fidelity
  image-to-3D base) followed by four-angle render and deformation review.

## 2026-09-13 Tripo HD source and Godot bridge checkpoint

- Tripo Studio task `904926bd-9f21-46f5-a2d7-42d2995cd41a` produced the first
  downloadable Echo candidate from the approved Higgsfield A-pose reference.
  The immutable source GLB and Blender inspection copy are stored under
  `art/production/echo-tripo-hd-v31-8k/` with front, three-quarter, side, rear
  and face-closeup evidence renders.
- Structural inspection found one mesh, 1,954,040 triangles, 1,017,367
  vertices, one material, three images (including an 8192 x 8192 source), and
  no armature. The identity and outfit direction are materially stronger than
  the existing proxy, but the raw source is not runtime-ready: it is far over
  the interactive character budget, has over-glossy baked response, visible
  facial/hair cleanup defects, and no deformation evidence.
- The official Tripo Godot Bridge 1.0.0 is installed and enabled only in the
  isolated `g0-vertical-slice` proof. Godot 4.5 loaded the plugin successfully,
  registered all scripts, and started its localhost-only WebSocket receiver on
  `127.0.0.1:60650`; no script errors were emitted in the headless editor test.
- A first protected runtime retopology used Quad topology with Smart Low Poly
  v2. The mode's actual maximum was 10,000 polygons, so Tripo ignored the
  attempted 50,000 entry and produced only 14,671 quad faces. Close inspection
  showed unacceptable face, hair and coat degradation. This output is
  **REJECTED** and must never be retopologized again or imported as Echo. The
  test cost 40 Studio credits, reducing the visible Pro balance from 3200 to
  3160; no free generation retry was consumed.
- The original 1,954,040-triangle history version was then explicitly restored
  and retopologized with Smart Low Poly disabled and a real 50,000 target. This
  cost 10 credits and produced 46,332 quad faces / 46,404 topology vertices.
  The exported `Echo_Tripo_Quad46K_8K_Candidate.glb` retains an 8192 x 8192
  source image and preserves the overall silhouette far better than the
  rejected Smart Low Poly output. Five Blender review views are stored beside
  it. Face texture projection, hair tips and the highly glossy material still
  need correction; it is a deformation candidate, not a visual lock.
- Tripo Humanoid v1.0 Auto Rig completed on the 46K candidate for 20 credits,
  reducing the visible balance to 3130. The first Idle retarget was submitted
  for deformation review. The rigged result still requires export and Blender/
  Godot verification; the browser preview alone is not a pass.
- Strict validation of the unrigged 46K export is expectedly **FAIL** as a game
  deliverable: 92,626 rendered triangles, no skin or animations, missing
  tangents, two validator errors tied to `FB_ngon_encoding`/accessor metadata,
  and a 26.8 MB file above the runtime budget. These are pipeline defects to
  correct during the Blender bake/export pass, not reasons to revert to the
  two-million-triangle source.
- Gate remains **FAIL / IN PROGRESS**. The retopologized output must preserve
  face, hair, coat silhouette and hands, then pass rigging, Idle/Walk/Run/
  Interact deformation, strict GLB validation, Godot import and visible runtime
  review before it may replace `EchoMotionProxy_NotCanon`.

## 2026-09-14 Tripo rig and G0 motion-set checkpoint

- Exported the humanoid-rigged 8K candidate first with Idle only, then produced
  `Echo_Tripo_Quad46K_8K_Rigged_G0_MotionSet.glb` with four in-place clips:
  Idle, Walk, Run and Look Around. Animation retargeting did not consume further
  Studio credits; the visible Tripo balance remained 3130.
- Blender 5.2.1 LTS reimport found one skinned character mesh, one non-production
  Icosphere helper, one 41-bone armature and four real actions. Each action has
  40 changing bones, so the clips are genuine skeletal motion rather than rigid
  object transforms. Review renders and `rig-report.json` are stored under
  `art/production/echo-tripo-quad46k-8k-candidate/motion-review/`.
- Deformation review is a **CONDITIONAL PASS for the skeleton only**. No gross
  anatomy collapse was found in Idle, Walk, Run or Look Around, but the long
  front coat behaves as an overly fused sheet and intersects/compresses around
  the legs during locomotion. The face/eye projection remains smeared at close
  range, hair highlights are too plastic, and the coat/skin response is much too
  glossy for the approved manhwa look. The candidate remains forbidden from
  replacing the proxy.
- The motion-set GLB retains 8192, 4096 and 2048 texture sources, proving that
  texture resolution was not lost. Its delivery metrics are 92,622 triangles,
  67,161 vertices, 41 joints, four animations and 24,042,504 bytes.
- Strict Khronos/project validation has zero schema errors but still **FAILS**:
  two warnings (missing authored tangents and a skinned mesh below a transformed
  parent), 92,622 triangles above the 80,000 delivery ceiling, and a 24.0 MB
  master above the current 6 MB runtime profile. The 8K master is retained as
  source evidence; a separate corrected runtime derivative is required.
- Godot 4.7.2 successfully completed import of both rigged GLBs and their
  generated material textures in the isolated G0 project. Import success is not
  a visual pass and does not change the gate.
- Next legal move: Blender correction on this rigged candidate—remove the helper,
  fix the skinned-parent hierarchy, author tangents, split/reweight the coat,
  correct face/hair materials and reproject/bake detail from the immutable
  1.95M-triangle 8K source. Export separate hero-master and runtime profiles,
  then repeat all four deformation renders and a visible Godot playtest.

## 2026-09-14 Sector 11 wake-capsule checkpoint

- The first room hero asset is the containment/wake capsule because it anchors
  Echo's opening, establishes Sector 11's medical-mechanical language, and can
  carry both cinematic and gameplay interaction. Tripo task
  `cffdd6d3-c165-419a-8159-e6eef46a5ec2` used the one-time detailed-parts trial
  and consumed no credits. Its 62-part / 1,870,199-triangle exploded output is
  retained as source evidence only and is rejected for direct integration.
- Tripo task `0e6b444a-ade2-49d2-8d41-bf728ddccb05` produced the strongest
  assembled body after prompt correction. The generation cost 30 credits and
  one 50K Quad retopology cost 10 more, leaving the visible balance at 3090.
  Detached presentation panels remained, so Blender isolated the main connected
  body instead of spending the last free retry or pretending the export was
  production-ready.
- The immutable high body contains 1,545,564 triangles and no textures. The
  isolated retopology body contains 76,145 rendered triangles. Blender authored
  UVs and baked the high geometry to 4096 and 2048 normal-map profiles, then
  added a separate transparent hatch, frame, hinges, release control, restrained
  cyan medical strips, emergency indicator and service panels. Review renders
  are stored under `art/production/sector11-wake-capsule-tripo-v2/`.
- `Sector11_WakeCapsule_G0_Runtime.glb` is the current runtime candidate:
  76,708 triangles, 55,786 exported vertices, 16 meshes, six materials, one 2K
  baked normal texture and 6,285,752 bytes. Two degenerate exported tangent
  vectors were repaired deterministically; strict Khronos/project validation
  now reports **PASS with zero errors and zero warnings** under the 80K/6MiB
  G0 profile. The 4K bake remains available as the hero master and is not used
  to inflate the runtime package.
- Godot 4.7.2 imported the candidate successfully, the G0 scene instantiates it
  at the wake position with deterministic collision, and the smoke test prints
  `G0_WAKE_CAPSULE_READY`, `G0_VERTICAL_SLICE_READY` and `GODOT_SMOKE_OK`.
  A real Godot-rendered audit frame confirms that the hatch is transparent and
  the internal cradle remains readable.
- Capsule gate: **TECHNICAL PASS / VISUAL CONDITIONAL PASS**. The asset is ready
  for G0 layout and interaction prototyping, but the Godot render is darker and
  more cyan-saturated than the Blender evidence. Final cinematic approval still
  requires scene-level exposure/material tuning and a visible door-open motion
  test with Echo framed inside. The overall G0 gate remains **FAIL / IN PROGRESS**.

## 2026-09-14 Echo controlled re-creation comparison

- A separate Tripo v3.1 candidate was generated from a purpose-written Echo
  A-pose reference: visible heterochromatic eyes, separated coat tails, matte
  black tactical tailoring and restrained cyan/crimson accents. The image
  reference used one free image generation; the HD geometry used 30 credits and
  the 4K texture pass used 20 credits. Visible Studio balance moved from 3090 to
  3040. No subscription or paid upgrade was selected.
- The candidate source files are retained under
  `art/production/echo-tripo-hd-v32-reference-candidate/` as immutable
  comparison evidence. `Echo_Tripo_HD_v32_Textured4K_Source.glb` has a valid
  schema with no validator warnings, one 4K texture and a visibly cleaner coat
  split than the earlier motion candidate. It is deliberately not a runtime
  delivery: 1,959,855 triangles, 58,376,584 bytes, no armature and no animations.
- **Visual/identity decision: REJECT AS ECHO REPLACEMENT.** The recreated model
  is a useful technical reference for cloth separation and a matte material
  response, but its face, hair silhouette and overall persona are too generic
  to replace the original Echo candidate. It must not be rigged, integrated or
  presented as canon merely because its raw mesh is more detailed.
- Next quality-gate move: retain the original rigged Echo as identity source;
  apply the proven material and coat-separation lessons to a corrected Blender
  derivative, then test Idle/Walk/Run before any Godot replacement decision.
