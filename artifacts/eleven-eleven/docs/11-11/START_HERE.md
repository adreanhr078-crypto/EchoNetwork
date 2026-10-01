# START HERE: 11.11 Echo Network Architecture & Context

> **CURRENT OWNER DECISION — 2026-09-12:** Godot is the active G0 engine.
> Unity migration is cancelled. Continue at
> `art/godot/technical-proofs/g0-vertical-slice`; earlier Unity notes below are
> historical. See `G0_GODOT_RESUMPTION_2026-09-12.md` for the current handoff.

**Welcome to 11.11 — Echo Network.** If you are an AI agent, you must read this document before making any architectural or implementation decisions.

## The Core Product Vision

11.11 is a **premium anime cinematic third-person 3D story game**, NOT just an interactive Manhwa reader or UI puzzle app. It features exploration, puzzles, combat, environmental storytelling, and an expanded open-world structure.

## The Reality of the Codebase (As of Sept 2026)

While the vision is grand, the current implementation is heavily skewed towards UI, 2D puzzles, and server infrastructure. 
- **Production-grade backend**: Cloudflare Workers, Durable Objects, D1 SQLite, Firebase Auth, HMAC signed receipts.
- **Missing Core Gameplay**: There is currently NO proper 3D character model for Echo, NO animations, NO combat system, and NO guide character.
- **Engine Conflict**: The `AwakeningWard` uses Phaser 3 (2D Isometric), while `GameWorld` uses Three.js/R3F (3D). Moving forward, **Three.js/R3F is the authoritative runtime** for all gameplay.

> **G0 clarification (2026-09-11):** Three.js/R3F remains the current web runtime;
> Godot 4.7.2 is an isolated G0 candidate proof only. One runtime must win a measured
> comparison before production lock. Read `../PROJECT_MASTER_BLUEPRINT.md` and
> `../internal/production/ANTIGRAVITY_CHAT_AUDIT_2026-09-11.ar.md` for the locked
> scope and Astra continuity evidence.
>
> **Unity migration clarification (2026-09-12):** By explicit Owner direction,
> Unity 6000.3.23f1 is now the isolated G0 migration target. The Godot proof is
> preserved as a complete rollback/comparison backup; Unity is not production
> greenlit until its official Editor opens, imports, and runs the migrated room.
> See `UNITY_MIGRATION_2026-09-12.md` and `art/unity/migration-manifest.json`.
>
> **Readiness re-audit:** Read `UNITY_READINESS_AUDIT_2026-09-12.md` before
> continuing. No executable Editor was found; the copied scene is scaffolding,
> not a completed migration. Collision, animation and interaction parity remain.
> Static tests and web postflight PASS must never be reported as Unity runtime PASS.

## Critical Master Documents

Before you implement new systems or modify the core loop, consult:

1. `CURRENT_STATE_AUDIT.md` - The exact state of what works and what is missing.
2. `MASTER_GAME_ARCHITECTURE.md` - Technical stack, data flow, and engine constraints.
3. `PHASE_ROADMAP.md` - The exact sequence of development. Do NOT implement Phase 3+ features if Phase 2 is not complete and verified.
4. `AGENT_EXECUTION_PLAYBOOK.md` - Which AI agent type should handle which tasks.
5. `RISK_REGISTER.md` - Active technical risks and constraints (bundle sizes, asset pipelines).
6. `../PROJECT_MASTER_BLUEPRINT.md` - Owner-facing G0 scope, psychology contract, and measurable quality gates.
7. `../internal/production/ANTIGRAVITY_CHAT_AUDIT_2026-09-11.ar.md` - Evidence-based continuation from the prior Astra/Antigravity work.

## Mandatory Agent Rules

1. **Do not fabricate runtime success.** If an Edge browser test fails or a component causes a white screen, report it.
2. **Preserve Server Authority.** Never bypass D1/Worker receipts by forcing Zustand states or local storage entries.
3. **Respect the Phases.** Do not jump to combat systems if the basic 3D room movement is not yet polished.
4. **No Placeholder 3D.** Do not bloat the repo with generic Three.js primitives masquerading as the final game. Wait for Blender-authored assets.
