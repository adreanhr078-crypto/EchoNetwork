# Sector 11 cryogenic pod v1

## Asset and integration

- Tripo task: `6248cb3a-6746-47cc-a58d-b1f05e73acc7` (`P1-20260311`, text-to-model, 18,000-face target), 40 credits.
- Original output and preview: `../tripo-out/sector11-cryo-pod-v1-6248cb3a/`.
- Godot copy: `../../../godot/assets/props/sector11_cryo_pod_v1.glb`.
- Runtime scene: `../../../godot/scenes/props/sector11_cryo_pod.tscn`, currently instanced by `../../../godot/scenes/main.tscn` as Echo's opening capsule.
- The wrapper scales the model, turns its glass bay toward the opening camera, and adds a simple static collision body. The original `sector11_capsule.tscn` and its model are preserved.
- `godot-opening-cryopod-review-v3.png` records the first in-engine integration.
- `godot-sector11-environment-review-v4.png` records the current 1280×720 composition after recovery.
- The Sector 11 shell is now a tighter 18×7.2 m space with asymmetrical observation bays, service panels, overhead utility lines, and a higher-contrast blast gate. The former wide, repeated wall layout and original gate prop remain preserved in project history.

## Visual review and limits

The capsule reads clearly at game scale and adds a distinct hero prop to the lab blockout. Its pale shell stands out strongly against the navy room. The tighter shell and layered door improve depth and focal hierarchy, but they are still mostly procedural hard-surface geometry. Sector 11 needs authored mesh forms, richer surface treatment, better character lighting, and final chapter-specific review. The pod has no opening animation, interior character, or story interaction yet; those belong in the connected awakening sequence. This does not complete M01.

Current Tripo balance after this generation: 210 credits remaining, 0 frozen, from the initially reported 460.
