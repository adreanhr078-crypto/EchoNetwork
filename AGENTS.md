# Repository Agent Instructions

## Owner navigation rule — 2026-09-28

Preserve the existing project map and folder layout. Begin navigation with
`PROJECT_MAP.ar.md` and the compact current-work card at
`artifacts/eleven-eleven/docs/internal/production/CURRENT_WORK.ar.md`.
Read the latest relevant checkpoint from `CONTINUATION.md`, not the entire
historical log on every request. Mandatory instructions and product/Canon
sources below still apply; read only relevant implementation files afterward.
Search within the affected system first and expand only when evidence requires
it. Put new files in the existing runtime, tests, production-source, evidence or
documentation folders. Update the map when adding a new entry point or system;
update the current-work card after meaningful delivery with actual evidence,
remaining work and the next action. Keep one current card, not dated duplicates.
Never reduce context by deleting unique assets, Canon, reports or required rules.

## Owner cleanup and current-evidence rule — 2026-10-12

After PROJECT_MAP and CURRENT_WORK, use the active app's
`docs/internal/production/WORK_TREE.ar.md` and `SOURCE_INDEX.json` to select the
current room, runtime avatar and authoritative source. Older map updates are
preserved under production/archive and are historical, never current status.
Do not use old agent screenshots as acceptance of the current scene. Record the
review checkpoint, actual scene/asset paths and matching source hashes; if this
link cannot be established, mark visual evidence UNVERIFIED and capture the
current runtime when that task resumes. Update affected source-index hashes
after intentional runtime edits. Do not choose evidence by filename or mtime alone.
The Owner requested development to stop for project cleanup; CURRENT_WORK records
the pause and the exact next task. Resume game work only on a later Owner request.
Prefer individual work; use agents only for a concrete quality or time benefit.

## Current Owner mandate and continuation (2026-09-19)

Read `artifacts/eleven-eleven/docs/11-11/design/OWNER_PRODUCTION_MANDATE.md`
and `artifacts/eleven-eleven/docs/11-11/design/CONTINUATION.md` before task work.
The revised mandate supersedes conflicting older production directions, subject
to platform safety and the Owner's later instructions. Preserve Manhwa authority.
After each meaningful delivery, append a checkpoint with files, actual tests,
limitations, worker status and the next exact action. Never equate plans with work.
Keep work in EchoNetwork; verify origin before publishing. Preserve dirty work.
Owner communication preference: no work narration; when a progress update is
required, use only «يكمل» or «ينجز». Keep final factual handoffs concise.
Prefer bounded Gemini terminal delegation when verified available; do not claim
it was used without a real returned result. Send relevant context, not full history.

The active 11.11 application is under `artifacts/eleven-eleven`. Read and preserve its project rules in `artifacts/eleven-eleven/AGENT_RULES.md` before making application changes. Do not modify legacy or unrelated project paths unless the task explicitly requires it.

# Mandatory Product Memory

Before planning, designing, reviewing, or implementing any 11.11 work, read:

1. `artifacts/eleven-eleven/docs/11-11/START_HERE.md`
2. `artifacts/eleven-eleven/docs/PROJECT_VISION.md`
3. `artifacts/eleven-eleven/docs/project-memory.json`
4. `artifacts/eleven-eleven/docs/internal/narrative/current/ar/manifest.json`

Use `$11-11-game-director` for roadmap, system-order, story-to-gameplay,
third-person, Manhwa, puzzle, progression, economy, or milestone decisions.
The Owner has explicitly chosen quality over speed and authorized a long,
evidence-gated production. This does not authorize skipping the current phase,
building every system at once, or replacing 11.11 with a clone of another game.

# Mandatory 11.11 Quality Gate

For EVERY implementation, bug fix, refactor, UI change, gameplay change,
content integration, asset change, data change, or system modification:

Before reporting the task complete, you MUST invoke and satisfy:

$11.11-autonomous-quality-gate

The task is NOT complete merely because code was written or tests passed.

Required lifecycle:

UNDERSTAND
→ INSPECT
→ PLAN
→ IMPLEMENT
→ VERIFY
→ SELF-CRITIQUE
→ AUTO-FIX SAFE DEFECTS
→ VERIFY AGAIN
→ REGRESSION REVIEW
→ FINAL DELIVERY

Do not knowingly return fixable defects to the Owner.

If runtime/browser evidence is genuinely unavailable, never fabricate PASS.
Complete every verification possible and explicitly report the missing runtime evidence.

# Mandatory 11.11 Player Experience Finish

For every player-facing integration, visual pass, puzzle pass, or release task:

- Prefer clear, evocative player-facing names over internal or legacy labels.
  Rename navigation items and mode labels when evidence shows that the new name
  makes the journey easier to understand without changing Canon.
- The game must feel like one connected experience. Story, Manhwa, puzzles,
  characters, progression, rewards, Daily, and Weekly may not feel like isolated
  demos or hidden developer screens.
- Every completed Story puzzle must produce a polished, accessible completion
  moment using the existing authoritative reward receipt: visual feedback,
  reward details, achievement feedback when earned, and a dedicated game sound
  when sound is enabled. Never grant rewards or achievements from presentation
  code, and never replay a server-owned reward from a duplicate request.
- Sound, animation, and notifications must respect mute/volume, reduced-motion,
  accessibility, and player control. Provide visual equivalents for audio cues.
- Player-facing UI must be polished, cinematic, enjoyable, and unmistakably
  consistent with the 11.11 visual language. Use strong purposeful animation
  for entry, puzzle interaction, completion, rewards, achievements, and Echo
  transformation moments. Avoid constant decorative motion that competes with
  gameplay, and keep a complete Reduced Motion alternative.
- Verify ambitious UI and animation work on target landscape viewports and
  against performance evidence. Visual intensity never justifies clipped
  controls, input delay, illegible RTL text, inaccessible focus, or oversized
  blocking payloads.
- Optimize for strong attachment to the characters, story curiosity, satisfying
  mastery, and meaningful Daily/Weekly return. Do not use deceptive dark
  patterns, fake urgency, punitive streak loss, spam notifications, or coercive
  engagement mechanics.
- Fix every known repository-local defect required to make the existing Part 1
  experience cohesive, playable, attractive, and release-ready before reporting
  completion. Add assets or content only when they close an evidenced release
  gap and remain within approved Canon.

## Owner animation foundation — 2026-09-30

For EchoNetwork character skeletal animation import/retarget work, always preserve the Golden pipeline invariants. Successful routine motions may follow that proven pipeline directly. Use `$echo-golden-animation` at `.agents/skills/echo-golden-animation/SKILL.md` immediately when output is poor or a stage fails, and no later than the second evidence-driven attempt; do not repeat blind trials. Use the skill from the start when that improves quality. The Owner-approved Walk in `artifacts/eleven-eleven/art/production/master-animation-library/golden/walk-v1/` is the fixed Golden Reference. Verify its hashes before/after each motion; never regenerate/improve the Walk or manually edit source keys. Preserve Skeleton Retarget, Root Motion and the current player; no AnimationTree/blending during verification. Process Run/Jog → Idle → Jump sequentially with the same frozen transfer/import pipeline, isolating failures per motion without changing global project settings. Later explicit Owner instructions supersede this rule.

## Gemini 3.8 Deep Rigor Invariant — 2026-10-11

When operating as or receiving directives for Gemini 3.8:
- NEVER cut corners, apply superficial patches, or take lazy shortcuts ("ممنوع الشلفقة").
- Always activate and adhere to `.agents/skills/gemini-3-8-deep-rigor/SKILL.md`.
- Inspect dependencies and explain root cause before writing code.
- Implement minimal atomic diffs; never rename public APIs, rewrite unrelated systems, or invent unrequested mechanics.
- Think before and after every tool call (pre-action purpose, post-action empirical verification).
- Orchestrate subagents (`research` for dependency scans, `self` for adversarial diff review) on non-trivial tasks.
- Exercise autonomous full-ownership authority without interrupting for routine operational approvals.
- Strictly avoid trial-and-error: study every decision deeply before execution; zero guesswork ("ممنوع المحاولات العشوائية").
- Validate via project tests and Godot logs (verifying clean exits and zero SCRIPT ERRORs).
- Inspect full git diff before declaring completion; state unverified items explicitly.



## Owner context and token economy — 2026-10-17

The Owner strictly forbids rereading the whole conversation or full historical logs for each edit. Start from the compact CURRENT_WORK card and docs/internal/production/CURRENT_CONTEXT_CACHE.json. Reuse verified facts keyed to file hashes; read only relevant changed source sections or a specific missing checkpoint. Load applicable mandatory instructions when first needed or changed, without repeated full-document reads. Keep brief Arabic updates and bounded tool output; do not claim control over provider-side prompt caching or guaranteed token savings. Refresh the compact cache after meaningful delivery, and never treat cached observations as live account balance or current visual acceptance.
