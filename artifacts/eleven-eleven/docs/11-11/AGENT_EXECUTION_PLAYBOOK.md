# Agent Execution Playbook

This project leverages multiple AI agents. Assign tasks according to this capability matrix to ensure the highest quality output.

## 1. Sol / The Lead Architect (Gemini 1.5 Pro / High Reasoning)
**Role**: Director, System Architect, and Phase Gatekeeper.
**Responsibilities**:
- Project planning, phase transitions, and milestone validation.
- Cross-system architecture design (e.g., designing how the 3D room system connects to D1 receipts).
- Managing the Phase Roadmap and ensuring no feature creep.

## 2. AntiGravity (Gemini)
**Role**: Technical Director, Media Producer, Test Validator.
**Responsibilities**:
- **Blender & Media Pipelines**: AntiGravity has verified access to the Blender CLI (`tools/blender/run-blender.ts`), Python scripts, and FFmpeg. Use AntiGravity to generate, validate, and export all GLB environments, character rigs, and cinematic sequences.
- **Testing & Tool Execution**: Use AntiGravity to run Playwright, diagnose full-stack test failures in real-time, and execute `npm run check`.
- **Godot / Unity Pipelines**: If engine tests are needed outside of web.

## 3. Codex (OpenAI)
**Role**: Lead Developer, Refactor Specialist.
**Responsibilities**:
- **TypeScript / R3F Coding**: Reliable, deterministic implementation of React, Zustand, and Three.js logic.
- **Large Refactors**: Extremely strong at managing multi-file structural changes across the `src/` directory without losing context.
- **Sandbox Execution**: Use Codex to execute and verify isolated backend scripts or worker unit tests.

## Execution Rules
1. **Never assign Blender tasks to Codex.** Codex lacks the local toolchain verification.
2. **Use Sol for decisions, AntiGravity for tools, Codex for code.**
3. **If a test fails, do not have Codex guess the fix.** Have AntiGravity run the test locally, read the output, and propose the fix.
