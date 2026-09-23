---
name: 11-11-tripo-cli
description: >-
  Invoke Tripo 3D OpenAPI V3 from the agent to generate, rig, and animate 3D
  models for 11.11. Use tools/tripo/run-tripo.ts as the entry point. Requires
  TRIPO_API_KEY or --api-key. Do not modify frozen game logic or reward authority.
metadata:
  category: tooling
  source:
    repository: 'https://github.com/adreanhr078-crypto/EchoNetwork'
    path: .agents/skills/11-11-tripo-cli
    license: project-internal
---

# 11.11 Tripo 3D CLI Skill

This skill provides direct programmatic access to Tripo 3D OpenAPI V3 for generating high-fidelity 3D models, PBR textures, automated character rigging, and animation retargeting.

## Entry Points

- Check credits balance:
  `npx tsx tools/tripo/run-tripo.ts balance`
- Text-to-Model generation:
  `npx tsx tools/tripo/run-tripo.ts text-to-model --prompt "heavy industrial sci-fi ceiling pipes" --output ./artifacts/eleven-eleven/public/assets/props/pipes.glb`
- Rig model:
  `npx tsx tools/tripo/run-tripo.ts rig --task-id <task_id> --output ./artifacts/eleven-eleven/public/assets/characters/rigged.glb`
- Retarget animation:
  `npx tsx tools/tripo/run-tripo.ts retarget --rig-id <rig_id> --animation "preset:walk" --output ./artifacts/eleven-eleven/public/assets/characters/walk.glb`

## Environment Requirements

- `TRIPO_API_KEY`: API token from https://platform.tripo3d.ai
- Node.js 22+ with `npx tsx`
- Models are exported in standard GLB format and validated through `tools/blender/run-blender.ts` or directly mounted in R3F.
