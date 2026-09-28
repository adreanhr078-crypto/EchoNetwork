# Archived Flax experiment

Godot in `artifacts/eleven-eleven/godot` is the owner-directed runtime. This
directory is historical migration work, not the active game or release source.
Unique Flax source, reports, inventories and snapshots remain preserved.

The `SourceAssets` mirror contained hundreds of byte-identical copies of files
already kept in the active project. The cleanup manifest at
`../artifacts/eleven-eleven/docs/internal/production/2026-09-28-cleanup-manifest.json`
maps each removed duplicate to its retained original and SHA-256. Unique files
remain here. Do not treat the pruned mirror as a complete Flax import package.

The manifest records a local ZIP backup. Removed tracked copies are also
recoverable from the recorded Git base commit. If this archived experiment is
ever resumed, explicitly reconstruct its input package from that inventory.
