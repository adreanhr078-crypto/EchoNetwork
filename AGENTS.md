# Repository Agent Instructions

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
