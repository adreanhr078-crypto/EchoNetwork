# START HERE: 11.11 Echo Network Architecture & Context

**Welcome to 11.11 — Echo Network.** If you are an AI agent, you must read this document before making any architectural or implementation decisions.

## The Core Product Vision

11.11 is a **premium anime cinematic third-person 3D story game**, NOT just an interactive Manhwa reader or UI puzzle app. It features exploration, puzzles, combat, environmental storytelling, and an expanded open-world structure.

## The Reality of the Codebase (As of Sept 2026)

While the vision is grand, the current implementation is heavily skewed towards UI, 2D puzzles, and server infrastructure. 
- **Production-grade backend**: Cloudflare Workers, Durable Objects, D1 SQLite, Firebase Auth, HMAC signed receipts.
- **Missing Core Gameplay**: There is currently NO proper 3D character model for Echo, NO animations, NO combat system, and NO guide character.
- **Engine Conflict**: The `AwakeningWard` uses Phaser 3 (2D Isometric), while `GameWorld` uses Three.js/R3F (3D). Moving forward, **Three.js/R3F is the authoritative runtime** for all gameplay.

## Critical Master Documents

Before you implement new systems or modify the core loop, consult:

1. `CURRENT_STATE_AUDIT.md` - The exact state of what works and what is missing.
2. `MASTER_GAME_ARCHITECTURE.md` - Technical stack, data flow, and engine constraints.
3. `PHASE_ROADMAP.md` - The exact sequence of development. Do NOT implement Phase 3+ features if Phase 2 is not complete and verified.
4. `AGENT_EXECUTION_PLAYBOOK.md` - Which AI agent type should handle which tasks.
5. `RISK_REGISTER.md` - Active technical risks and constraints (bundle sizes, asset pipelines).

## Mandatory Agent Rules

1. **Do not fabricate runtime success.** If an Edge browser test fails or a component causes a white screen, report it.
2. **Preserve Server Authority.** Never bypass D1/Worker receipts by forcing Zustand states or local storage entries.
3. **Respect the Phases.** Do not jump to combat systems if the basic 3D room movement is not yet polished.
4. **No Placeholder 3D.** Do not bloat the repo with generic Three.js primitives masquerading as the final game. Wait for Blender-authored assets.
