# 11.11 Project Agent Rules

These rules apply to every agent working in the active application.

## Owner animation foundation — 2026-09-30

The frozen Golden invariants apply to every character skeletal animation
import/retarget task. Routine successful work follows the proven pipeline directly.
Invoke `$echo-golden-animation` from the repository's
`.agents/skills/echo-golden-animation/SKILL.md` immediately when diagnosis improves
quality, at the first failed/poor result, and no later than the second attempt.
Allow at most two evidence-driven attempts per motion; a second attempt requires
a documented cause and scoped fix, never a blind retry loop.
The Owner-approved Walk is the fixed Golden Reference in
`art/production/master-animation-library/golden/walk-v1/`; verify its protected
hashes before and after each motion, and never regenerate, improve or reseal it.
Process existing Run/Jog → Idle → Jump sources sequentially with the same frozen
transfer/export and isolated Godot import pipeline. Preserve source keys,
Skeleton Retarget, Root Motion and the current player; no AnimationTree or
blending during verification. Diagnose failures within the individual motion
before any local fix, without changing global project settings. Later explicit
Owner instructions take precedence. The exact workflow is documented in
`tools/animation-library/README.md`.

## 1. Read the durable project memory first

Before analysis, planning, design, code, content, or asset work, read in order:

1. `docs/PROJECT_VISION.md`
2. `docs/project-memory.json`
3. `docs/internal/narrative/current/ar/manifest.json`
4. The current Story Bible and Narrative Master selected by that manifest when
   the task touches story, characters, puzzles, cinematics, dialogue, or world
   design.

The product vision controls product direction. The narrative manifest controls
Canon. Neither source silently overrides the other.

Use `$11-11-game-director` for any roadmap, phase, system-order, Manhwa,
third-person, progression, economy, or cross-system decision.

## 2. Current phase is authoritative

Read `currentPhase` and `currentPhaseGate` from `docs/project-memory.json`.
Do not skip that gate or begin a later system merely because its toolchain is
available. Update the phase only after the Owner approves the transition and
the completed phase passes `$11.11-autonomous-quality-gate`.

The Owner accepts a multi-year, many-milestone production. Quality over speed
does not mean uncontrolled scope: every milestone must remain playable,
testable, bounded, and evidence-gated.

## 3. Mandatory checks

Before any edit, run from the repository root:

```bash
npm run agent:preflight
```

After any edit, run:

```bash
npm run agent:postflight
```

Also invoke and satisfy `$11.11-autonomous-quality-gate`. Run targeted tests,
content validation, TypeScript, the production build, media validation, Worker
checks, and Edge runtime verification whenever applicable. Never convert
missing runtime evidence into PASS.

## 4. Product and player-experience invariants

- Build one connected game, not a collection of independent screens.
- Preserve the approved hybrid identity: live system UI, Manhwa memory/story,
  fair puzzles, cinematic transitions, third-person exploration and combat,
  relationships, and Echo's chess hobby.
- Reveal systems progressively in the order recorded in project memory.
- Keep every player-facing step understandable: objective, world meaning,
  interaction, consequence, and next action.
- Quality may scale by device; gameplay truth, accessibility, and story may not.
- Use adaptive Low/Medium/High/Ultra presentation with an explicit player
  override and tested fallbacks.
- Use Blender, Unity, Three/R3F, video, audio, and generation tools only when
  they earn their production and performance cost.
- Large-game inspiration is a quality benchmark, never permission to copy
  another game's characters, world, UI, music, assets, or signature systems.
- Build attachment through story, characters, discovery, mastery, and welcome
  return loops. Do not use coercive engagement or deceptive dark patterns.

## 5. Authority and safety invariants

- Rewards, ratings, inventory ownership, progression receipts, puzzle
  verification, economy, and unlocks remain server authoritative.
- Presentation may react to a receipt; it may not mint or replay one.
- AI assistants and companion dialogue never decide puzzle correctness,
  rewards, chess legality, Canon, inventory, or progression.
- Do not expose secrets, credentials, private player data, solution payloads,
  or unpublished Canon.
- Paid random rewards, if ever approved, come only after the economy and legal
  gate recorded in project memory. Never build them early as a retention patch.

## 6. Canon and content rules

- Echo is the protagonist. Yuki is the white-haired childhood friend.
- Echo's direct-skin neck identifier is `EX-011`; Zero may add an evolving
  layer around it but never replaces it.
- The final Manhwa handoff is required before locking story-specific gameplay,
  cinematic chronology, final character production, or replacement puzzles.
- There is no arbitrary target count for puzzles, memories, cinematics,
  achievements, characters, or endings. Content exists only when it earns a
  distinct player decision, emotion, discovery, or gameplay purpose.
- Legacy narrative may remain only behind an explicit compatibility boundary;
  it is not current Canon and must not leak into new authored work.

## 7. Worktree discipline

- Inspect `git status`, `git diff`, recent commits, and `git diff --check`.
- Preserve unrelated Owner changes and do not rewrite or delete them.
- Do not delete material without explicit authorization and a recovery note.
- Do not create commits, deploy, publish, buy services, or mutate remote state
  unless the Owner explicitly requests it.
- Report exact errors and warnings. Do not repeat a prior PASS without rerunning
  the relevant command.

## 8. Completion

Do not report a phase complete until implementation, tests, quality gate,
player review, responsive behavior, accessibility, performance, and required
runtime evidence all pass. If evidence is external or unavailable, report the
specific surface as `UNVERIFIED` or `BLOCKED`; do not lower the bar.
