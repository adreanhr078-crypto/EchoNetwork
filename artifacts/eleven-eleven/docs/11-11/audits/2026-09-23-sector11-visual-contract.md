# Sector 11 first-room visual review

The Owner's 23 September screenshot is a **quality reference**, not a scene or UI to copy. It demonstrates clear third-person framing, a polished floor that carries cool and warm light, a luminous capsule, layered architecture, and restrained combat/mission information. The current Godot capture (`art/production/sector11-modular-kit/phase1-review-20260923.png`) remains a prototype: Echo faces sideways at rest, the floor is matte and broad, the capsule has no active internal light, and a full-width dialogue panel covers the lower image.

## Original visual contract

The selected decorative concept is `public/assets/ui/sector11/sector11-hud-visual-contract-v1.png`. It is an **art direction reference only**, generated with the built-in image generation tool from the Owner's image as a mood reference. It is not a game background or a substitute for geometry. Prompt intent: original asymmetrical obsidian containment room, one luminous capsule, a controlled cyan floor signal, distant gate, sparse amber hazards, deep material response and protected space for Echo and live interface; no text, icons, people, logos or copied composition.

The player-facing implementation remains native Godot controls and 3D materials. Preserve Echo's lower-center silhouette and keep directives beside him without covering his face; use a compact dialogue panel only when a line is active. Place essential text in live labels with keyboard/touch input. For reduced motion, show the full line immediately and suppress the typewriter; preserve all text and actions. For low graphics tiers, use the same gameplay truth with simpler lights and specular materials; Forward+ can add richer reflection only after performance evidence on a supported GPU.

## Phase-one decisions

1. Correct Echo's default +X model facing so the standard behind-the-back camera reads his back toward the gate.
2. Reduce the dialogue panel to a legible, bounded card; keep other HUD information away from the center.
3. Tune existing floor, pod, and light materials before adding geometry or paid generated assets.
4. Compare 720p and 1080p captures, walking/landing footage, input and skip behavior, and GPU cost before accepting this slice.

This contract does not introduce story beats, Zero powers, a new reward path, or a second engine.
