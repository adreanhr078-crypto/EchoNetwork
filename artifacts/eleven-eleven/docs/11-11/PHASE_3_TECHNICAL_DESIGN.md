# Phase 3 Technical Design Document (TDD)

## 1. Vision Alignment: The Core Loop
Before diving into technical specifics, this architecture supports the following canonical progression:
**Cover Puzzle (2D)** $\rightarrow$ **Screen Break (R3F Transition)** $\rightarrow$ **Echo Awakening (Cinematic)** $\rightarrow$ **Opening Lab (3D Exploration)** $\rightarrow$ **Puzzles (Interactive 3D/2D)** $\rightarrow$ **Threats (Systems)** $\rightarrow$ **Kinja Arc (Combat/Stealth)**.

The transition from UI/2D into the 3D world must be seamless, with the R3F Canvas persisting and managing state progressively.

---

## 2. Three/R3F Architecture
The 3D runtime relies on `@react-three/fiber` to bridge React's declarative nature with Three.js's imperative API.
* **Canvas Root**: A single global `<Canvas>` component wrapping the application after the Screen Break.
* **State Sync**: Zustand stores (`gameStore.ts`) will be accessed inside R3F components without triggering full React re-renders, using transient updates (`useStore.subscribe` or `useFrame`).
* **Physics/Collision**: We will evaluate `@react-three/rapier` for lightweight, deterministic kinematic collision (walls, floors) rather than relying solely on raycasting against complex meshes.

---

## 3. RoomDefinition Architecture
Rooms are data-driven, modular modules rather than hardcoded Three.js scenes.
```typescript
interface RoomDefinition {
  roomId: string;
  assetUrl: string; // e.g., '/assets/environments/opening-lab.glb'
  spawnPoints: Record<string, Vector3>;
  interactables: InteractableEntity[];
  cinematics: CinematicTrigger[];
  bounds: BoundingBox; // For camera occlusion
}
```
* **RoomLoader**: A component that reads `RoomDefinition`, dynamically imports the GLB via `useGLTF`, and handles `Suspense` fallbacks (loading screens/transitions).
* **Environment Instancing**: Environment meshes are static. Interactivity is layered over them using invisible hitboxes (bounding volumes) to save rendering cost.

---

## 4. Third-Person Controller (TPC) Plan
Movement must feel premium, responsive, and tactile.
* **Input Manager**: Abstracts WASD (desktop), Gamepad, and Virtual Joystick (mobile touch).
* **Kinematic Character Controller**: Echo will not be a rigid body tumbling around. We will use a capsule collider that slides along geometry, handling stairs and slopes deterministically.
* **Animation State Machine**: TPC output (velocity, turning rate) feeds directly into the `AnimationMixer` to blend between Idle $\leftrightarrow$ Walk $\leftrightarrow$ Run smoothly.

---

## 5. Camera System
Genshin-style camera architecture requires robust occlusion and framing.
* **Base Controller**: Custom orbit logic utilizing `@react-three/drei`'s `CameraControls` or a bespoke spherical coordinate math script.
* **Collision Raycasting**: The camera casts a ray from Echo's head to the camera target. If the ray hits a wall, the camera zooms in instantly to prevent clipping through environment geometry.
* **Cinematic Override**: The camera system listens to `gameStore`. If `isCinematic === true`, the player loses control, and the camera follows a pre-defined Spline path or focal target.

---

## 6. Echo Character Pipeline
* **Visuals**: Anime-style principled shader. We will avoid expensive real-time PBR roughness calculations where unlit/toon-shaded textures suffice.
* **Rigging**: Standard humanoid rig (Mixamo-compatible) for easy animation retargeting.
* **Implementation**: `<EchoPlayer />` component loads `echo.glb`, mounts the `AnimationMixer`, and attaches the TPC logic.
* **Bones & Attachments**: Exposed bone refs (e.g., `RightHand`) for future weapon/item attachments.

---

## 7. Blender $\rightarrow$ GLB $\rightarrow$ R3F Pipeline
1. **Modeling/Texturing (Blender)**: Authored at high fidelity.
2. **Optimization**: Meshes merged by material. Invisible geometry culled.
3. **Export (`export_glb.py`)**: Exported as `.glb` with **Draco** geometry compression and **Meshoptimizer**.
4. **Compression (`gltf-transform`)**: KTX2 texture compression applied in the CI pipeline for massively reduced VRAM footprint.
5. **Runtime (`gltfjsx`)**: Auto-generates React components from the GLB to easily target specific meshes (e.g., hiding a door when a puzzle is solved).

---

## 8. Interaction System
* **Proximity Triggers**: Instead of expensive per-frame raycasting from the camera to the mouse (which is terrible for touch devices), Echo has a proximity radius.
* **Contextual UI**: When Echo is within 2 meters of an interactable object facing it, a 3D HTML overlay (via Drei's `<Html>`) pops up (e.g., "[F] Inspect").
* **Trigger Payload**: Interacting dispatches an event: `interactionAction({ type: 'START_PUZZLE', payload: 'lab_terminal_1' })`.

---

## 9. Puzzle Framework
* **Seamless Transitions**: When a puzzle starts, the 3D camera dollies to focus on the puzzle object. 
* **2D Overlays**: The 3D canvas is blurred or darkened, and the 2D React UI takes over for complex logic (e.g., Circuit routing).
* **Resolution**: Upon completion, the UI unmounts, the camera returns to Echo, and the 3D environment updates (e.g., terminal screen turns green, door slides open).

---

## 10. Cinematic Framework
* **Director Component**: `<CinematicDirector sequence={currentSequence} />`
* **Tracks**: A JSON-driven timeline containing Tracks:
  * *Camera Track*: Moves camera along a spline.
  * *Animation Track*: Forces Echo to play "WakeUp_01" animation.
  * *Subtitle Track*: Displays translated narrative text.
  * *Audio Track*: Triggers spatial/2D SFX.
* **Skip Logic**: Players can skip. The Director instantly calculates the end-state of the sequence and snaps the player/environment to that state.

---

## 11. Receipt Integration (Server Authority)
* **Rule**: The 3D world NEVER grants rewards directly.
* **Flow**:
  1. Player solves puzzle.
  2. R3F dispatches action to `playerProgressionApi.ts`.
  3. Worker validates and returns HMAC Receipt.
  4. Zustand `gameStore` updates with the Receipt.
  5. R3F `<Room />` observes the store update and unlocks the door.

---

## 12. Save & Checkpoint Integration
* **Micro-Checkpoints**: `RoomId` and `SpawnPointId` are synced to Firestore/D1 periodically or at major thresholds (post-puzzle, entering new room).
* **Rehydration**: On boot, `/api/player/bootstrap` fetches the active checkpoint. The `ApplicationShell` routes directly to the R3F Canvas, and the `RoomLoader` places Echo exactly at `SpawnPointId`.

---

## 13. Performance Strategy
To maintain 60 FPS on desktop and 30 FPS on mid-tier mobile:
* **DPR Scaling**: `dpr={[1, 2]}` limits pixel density to 2x even on 3x/4x retina displays.
* **Lighting**: Fully baked lighting (Lightmaps) from Blender. NO real-time dynamic shadows from directional lights.
* **Texture Budgets**: Maximum 2048x2048 atlases.
* **Frustum Culling**: Enabled by default in Three.js.
* **Instancing**: Used for repeated elements (debris, papers, cables) via `<Instances>`.
