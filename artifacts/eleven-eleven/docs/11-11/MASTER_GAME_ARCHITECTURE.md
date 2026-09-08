# Master Game Architecture

## 1. Hybrid Serverless Cloud Architecture

11.11 operates on a serverless architecture designed for massive scale with zero idle cost.

### 1.1 Client Runtime (Vite + React + Three.js)
- **UI & State**: React 19 + Zustand (12 stores)
- **Routing**: Hash-based (`#/<screenId>`) gated by `deriveExperienceEntitlements()`
- **3D Engine**: `@react-three/fiber` and `@react-three/drei` (Authoritative runtime)
- **Legacy 2D Engine**: Phaser 3 (Restricted to A-01 Awakening Ward; to be deprecated)
- **Lazy Loading**: `three-runtime` and `phaser-runtime` are split via manual chunks to optimize LCP.

### 1.2 The Cloudflare Backend
No Node.js or Express server exists. All APIs are edge-deployed.
- **Pages Functions (`functions/api/`)**: REST endpoints for player profile, cloud saves, leaderboards, global rollout policies.
- **Durable Objects (`workers/realtime/`)**: Stateful WebSockets for multiplayer matchmaking, chess matches, parties, and co-op.
- **Echo Agent (`workers/echo-agent/`)**: Presentation-only hibernation WebSocket providing deterministic companion cues.
- **D1 (SQLite)**: Relational authoritative state (receipts, XP, cosmetics, Glicko-2 ratings).
- **R2 Storage**: Replay JSON files and immutable asset storage.
- **Cloudflare Queues**: Guaranteed delivery for match result processing and progression batches.

### 1.3 Google Firebase
- **Auth**: Anonymous, Email/Password, Google OAuth.
- **Firestore**: Used *only* for the 480KB JSON cloud save payload `players/{userId}/saves/main`. Controlled via `firestore.rules`. No Cloud Functions.

---

## 2. Server Authority & Anti-Cheat

The game trusts NOTHING from the client.
- **Progression Receipts**: Every milestone (e.g., Cover Puzzle completion) sends a POST request. The server verifies criteria, commits to D1, and returns an HMAC-SHA256 signed receipt.
- **State Normalization**: `normalizeAuthoritativeStoryState()` filters unknown receipts and enforces chapter prerequisites.
- **Glicko-2**: Chess ratings are processed chronologically via Queues. D1 triggers prevent stale updates.
- **Quota Limits**: Rewards are capped daily via D1 `network_reward_quota_claims`.

---

## 3. Data & Content Architecture

The `/data` folder contains authored JSON definitions.
- **Manifest**: Caps content to predefined maximums (e.g., 2000 puzzles, 5000 memories).
- **Story Puzzles**: Puzzles are uniquely identified and linked to Manhwa packet unlock thresholds.
- **Manhwa Pipeline**: The canonical 70-page PDF is split into WebP assets and validated against a strict $1800 \times 2700$ dimension budget via `tools/manhwa/validate-publication.mjs`.

---

## 4. The R3F 3D Rendering Pipeline

All future gameplay must adhere to this stack:
- **Modeling**: Blender 5.2.1 LTS.
- **Export**: Headless `export_glb.py` with Draco/Meshoptimizer compression.
- **Loading**: `useGLTF` with aggressive suspense boundaries.
- **Materials**: Anime-style principled shaders or unlit textures (determined by the cinematic lighting guidelines).
- **Camera**: `ThirdPersonCamera.tsx` orchestrates orbital and focal views.
