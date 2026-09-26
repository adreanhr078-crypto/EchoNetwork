# Echo Network — Godot 4 to Flax Engine Architecture Mapping

This document provides the authoritative system-by-system architectural blueprint mapping the existing, validated Godot 4 implementation of **Echo Network (11.11)** to **Flax Engine** (v1.9+ / v1.12+).

---

## 1. Executive Architectural Paradigm Comparison

| Engine Concept | Godot 4 Architecture | Flax Engine Architecture | Architectural Advantage in Flax |
| :--- | :--- | :--- | :--- |
| **Hierarchy Object** | `Node` / `Node3D` | `Actor` | Strongly-typed native C++ objects with minimal C# overhead |
| **Logic Component** | Attached GDScript / C# Script on Node | `Script` component attached to `Actor` | Entity-Component-System (ECS) style composition, multiple scripts per actor |
| **Player Controller** | `CharacterBody3D` (`move_and_slide()`) | `CharacterController` (PhysX kinematic capsule) | Hardware-accelerated PhysX swept capsule with native step offset, slope limit, skin width |
| **Camera Spring** | `SpringArm3D` + `Camera3D` | `Camera` actor + custom sphere-cast collision ray | Tighter control over camera lag, multi-target framing, framing offset, smooth collision clipping avoidance |
| **Bone Socketing** | `BoneAttachment3D` | `AnimatedModel.GetSocketTransform()` / `BoneSocket` actor | Direct native matrix extraction per frame; zero transform lag or jitter |
| **Animation Graph** | `AnimationPlayer` / `AnimationTree` | `AnimationGraph` (Anim Graph state machine) | Native multi-layer blending, inertialization, additive anime combat overlays, IK solvers |
| **Shading / Materials**| Godot Spatial Shaders (`visual_shader` or `.gdshader`) | Flax Material Graph / Custom HLSL Pixel/Vertex Shaders | Node-based material editor with native NPR/Cel ramp shading, screen-space outlines, custom depth passes |
| **Particle VFX** | `GPUParticles3D` | `ParticleSystem` + `ParticleEmitter` | Highly optimized GPU ribbon/trail particles, burst spawners, depth collision |
| **World Streaming** | Manual Scene instancing / background threads | `Scene` streaming via Flax SceneManager / Async Load | Native multi-scene support, asynchronous background streaming, level streaming bounds |
| **Audio System** | `AudioStreamPlayer3D` / Procedural generators | `AudioSource` actor with 3D attenuation / HRTF | Native spatial sound, Doppler effect, reverb zones, procedural audio buffers |
| **UI System** | Control nodes (`Control`, `TextureRect`, `Label`) | `UIControl` actor with Flax UI controls (`Label`, `Image`, `Panel`) | Scalable DPI canvas rendering, hardware-accelerated draw calls |

---

## 2. Core Subsystems Mapping

### 2.1 Player Locomotion & Physics

#### Godot Implementation
- **Source Script:** `artifacts/eleven-eleven/godot/scripts/player/echo_player.gd` & `player_traversal_controller.gd`
- **Mechanism:** `CharacterBody3D` driven by custom vector velocity integration. Handles ground detection via `is_on_floor()`, slide calculation, gravity accumulation, jump velocity impulsing, and inertia banking via `locomotion_inertia_banking.gd`.

#### Flax Engine Implementation
- **Target Script:** `EchoNetworkFlax/Source/Player/EchoLocomotion.cs` & `PlayerTraversalController.cs`
- **Flax Class:** `FlaxEngine.CharacterController` + `FlaxEngine.Script`
- **Physics Engine:** Nvidia PhysX kinematic character controller.
- **Key Methods:**
  - `CharacterController.Move(Vector3 displacement)`: High-performance swept collision resolution.
  - `CharacterController.IsGrounded`: PhysX ground contact flag.
  - `CharacterController.StepOffset`: Automatic stair stepping (default: 0.35m).
  - `CharacterController.SlopeLimit`: Native maximum slope climbing angle (default: 45°).
- **Inertial Banking:** C# slerp and rotatory roll applied directly to `Actor.LocalOrientation` proportional to angular velocity.

---

### 2.2 Parkour & Advanced Traversal

#### Godot Implementation
- **Source Script:** `artifacts/eleven-eleven/godot/scripts/player/player_traversal_controller.gd`
- **Capabilities:**
  - Running slide (crouch while sprinting).
  - Wall-run / Wall-climb detection using raycasts.
  - Ledge grabbing & hanging (`Jumping To Hanging.fbx`).
  - Rolling recovery from high falls (`Run_To_Rolling.fbx`).

#### Flax Engine Implementation
- **Target Script:** `EchoNetworkFlax/Source/Player/PlayerTraversalController.cs`
- **Collision Queries:** `Physics.RayCast()` and `Physics.SphereCast()` from character chest/waist/feet origins.
- **State Machine States:**
  - `TraversalState.Grounded`: Standard locomotion.
  - `TraversalState.InAir`: Airborne trajectory with coyote time (0.15s) and jump buffering (0.12s).
  - `TraversalState.Sliding`: Capsule height reduced from 1.75m to 0.9m; friction reduced; directional impulse.
  - `TraversalState.WallRunning`: Horizontal gravity dampening (0.2x); lateral velocity preserved along wall plane normal.
  - `TraversalState.LedgeClimb`: Root motion / lerped translation to ledge top anchor point.
  - `TraversalState.RollRecovery`: Impact absorption state preventing movement penalty if roll input is timed upon landing.

---

### 2.3 Third-Person Orbit Camera & Target Lock-On

#### Godot Implementation
- **Source Script:** `artifacts/eleven-eleven/godot/scripts/camera/cinematic_focus_puller.gd` + SpringArm3D hierarchy.
- **Mechanism:** Spring arm cast against environment collision mask (Layer 1).

#### Flax Engine Implementation
- **Target Script:** `EchoNetworkFlax/Source/Camera/ThirdPersonOrbitCamera.cs`
- **Structure:**
  - `Actor` (Camera Rig Pivot) attached to Player origin + target offset.
  - `Camera` actor as child of Pivot.
- **Occlusion Prevention:** Spherical sweep (`Physics.SphereCast(pivot, cameraRadius, direction, out hit, maxDistance, collisionMask)`). If an obstacle is struck, camera position smoothly interpolates to `hit.Point + hit.Normal * skinRadius`.
- **Combat Dynamic FOV:** Base FOV 75°. Expands to 85° during sprint, narrows to 65° during katana attack combo / lock-on focus.
- **Lock-On Target Tracking:** Queries nearby enemies in radius; computes screen-space angle; soft-locks camera yaw and pitch towards target center of mass.

---

### 2.4 Sekiro/Genshin Style Anime Katana Combat

#### Godot Implementation
- **Source Script:** `artifacts/eleven-eleven/godot/scripts/combat/visceral_combat_controller.gd` & `shadow_katana.gd`
- **Mechanics:** 4-hit combo sequence, deflect/parry timing window, hit-stop frame freezing, damage numbers, camera shake.

#### Flax Engine Implementation
- **Target Script:** `EchoNetworkFlax/Source/Combat/CombatController.cs`, `KatanaBladeSocket.cs`, `DeflectParrySystem.cs`, `HitStopController.cs`
- **Weapon Socketing:**
  - In Flax, the katana actor is attached to the player's animated model right-hand bone socket using `AnimatedModel.GetSocketTransform("RightHand", out Transform socketTransform)`.
  - The blade geometry carries a trigger collider (`BoxCollider` with `IsTrigger = true`).
- **Hit Detection:** Sweep raycast between blade root and tip or trigger overlap during active attack frames (controlled via animation event callbacks).
- **Hit-Stop (Micro-Stutter):**
  - Instantaneous freeze of `Time.TimeScale` (e.g. to 0.02) for 0.06 - 0.12 seconds on heavy slash impact.
  - Camera impulse kickback along impact normal.
- **Deflection / Posture System:**
  - Deflect window: 0.18s upon pressing Guard.
  - Successful deflect: Triggers spark VFX emitter, metallic audio sting, zero health damage to player, massive posture damage to attacker.
  - Guard break state triggered when enemy or player posture bar reaches maximum capacity (100).

---

### 2.5 Enemy AI Architecture

#### Godot Implementation
- **Source Scripts:**
  - `artifacts/eleven-eleven/godot/scripts/enemies/sector11_security_droid.gd` (Patrol & ranged shock bursts).
  - `artifacts/eleven-eleven/godot/scripts/enemies/specimen_ex000.gd` (Chimera boss: leaping smash, roar, sweeping claws).
  - `artifacts/eleven-eleven/godot/scripts/characters/dr_kinga.gd` (Dr. Kinga neuro-lab boss: ranged singularity projectiles, teleportation).

#### Flax Engine Implementation
- **Target Scripts:**
  - `EchoNetworkFlax/Source/Enemies/EnemyBase.cs`: Shared health, posture, poise, ragdoll/dissolve, and aggro dispatch.
  - `EchoNetworkFlax/Source/Enemies/SecurityDroidAI.cs`: Flax NavMesh navigation (`Navigation.FindPath`), perception cone raycasting, state transitions (Patrol, Alert, Attack, Stunned).
  - `EchoNetworkFlax/Source/Enemies/ChimeraBossAI.cs`: Behavior tree / state pattern: Phase 1 (Quadruped pounce, claw sweep), Phase 2 (Enraged roar, shockwave stomp, singularity breach).
  - `EchoNetworkFlax/Source/Enemies/DrKingaAI.cs`: Ranged caster AI with teleport evasions triggered by player proximity, singularity orb projectile spawning, shield barriers.

---

### 2.6 Cel-Shading & Anime Visual Pipeline

#### Godot Implementation
- **Implementation:** Custom SpatialShader material with discrete step functions (`smoothstep`), light angle quantization, and rim light calculations.

#### Flax Engine Implementation
- **Flax Shader Asset:** Custom Flax Material Graph (`EchoToonMaterial.flax`) with:
  - **Color Banding:** Diffuse lighting sampled and quantized using 2-step / 3-step color ramps (Shadow Tone, Midtone, Highlight).
  - **Anime Inverted Hull Outline:** Additional vertex extrusion pass along vertex normals with back-face culling and pure black / dark crimson outline color.
  - **Specular Sheen:** Sharp anisotropic highlight curve on hair and metallic blade edges.
  - **Rim Glow:** Fresnel falloff glow driven by character awakening aura state.

---

### 2.7 Seamless Japanese City & District Streaming Architecture

#### Godot Implementation
- **Source Scripts:** Modular town kit (`japanese_town_modular_kit.gd`), hospital interior (`hospital_interior.gd`), alleyway, school, shops.

#### Flax Engine Implementation
- **Target Scripts:** `EchoNetworkFlax/Source/World/WorldStreamingManager.cs`, `DistrictChunk.cs`, `EnterableInteriorManager.cs`
- **Flax Streaming Model:**
  - Multi-scene architecture where each city district (Minato Commercial Ward, Kasumi Alleyway, High School Grounds, Residential Suburbs, Sector 11 Subterranean) is an individual `.scene` asset in Flax.
  - `WorldStreamingManager` tracks player grid position via 2D bounding boxes.
  - When the player approaches within streaming radius (e.g., 200m), Flax asynchronously loads the adjacent scene via `Level.LoadSceneAsync()`.
  - Distant districts beyond 400m are culled or swapped for low-poly HLOD mesh representations.
- **Enterable Building Interiors:**
  - Seamless door triggers (`BoxCollider` with `IsTrigger = true`).
  - Upon entering doorway: Camera occlusion masks swap, interior lighting environment (PointLights, Emissive neon) enables, exterior high-density geometry culling enabled. Zero loading screens.

---

### 2.8 Vehicle Traversal (Moped & Vehicles)

#### Godot Implementation
- **Source Asset/Script:** `artifacts/eleven-eleven/godot/assets/props/japanese_moped.glb`

#### Flax Engine Implementation
- **Target Scripts:** `EchoNetworkFlax/Source/Vehicles/VehicleController.cs` & `VehicleEntryExit.cs`
- **Physics:** PhysX wheeled vehicle or custom raycast suspension chassis (`WheeledVehicle` in Flax).
- **Entry / Exit Mechanics:**
  - Approach interact prompt (E / Gamepad Y).
  - Player character snaps to vehicle seat socket; character controller disabled; vehicle controller receives player throttle/steering inputs.
  - Smooth camera offset expansion for high-speed city cruising.
  - Dismount: Player ejects laterally to safe ground position.

---

### 2.9 UI & Audio Pipeline

#### Godot Implementation
- **HUD:** Godot Control nodes for health bars, ability cooldown icons, damage floating labels.
- **Audio:** Procedural audio synthesis and spatial audio players.

#### Flax Engine Implementation
- **Target Scripts:** `EchoNetworkFlax/Source/UI/GameplayHUDController.cs`, `TutorialToastSystem.cs`, `DialogueOverlayController.cs`
- **UI:** Root `UIControl` with canvas anchoring, health bar fill sliders, stamina gauges, boss posture meters, and responsive screen-space scaling.
- **Audio:** `AudioSource` components with 3D logarithmic falloff curves, master mixer routing (Music, SFX, Voice, Ambient).

---

## 3. Summary of Migration File Mapping

| Godot Source Component | Flax Target Source File | Namespace |
| :--- | :--- | :--- |
| `echo_player.gd` | `EchoNetworkFlax/Source/Player/EchoPlayer.cs` | `EchoNetwork.Player` |
| `player_traversal_controller.gd` | `EchoNetworkFlax/Source/Player/PlayerTraversalController.cs` | `EchoNetwork.Player` |
| `locomotion_inertia_banking.gd` | `EchoNetworkFlax/Source/Player/EchoLocomotion.cs` | `EchoNetwork.Player` |
| `cinematic_focus_puller.gd` | `EchoNetworkFlax/Source/Camera/ThirdPersonOrbitCamera.cs` | `EchoNetwork.Camera` |
| `visceral_combat_controller.gd` | `EchoNetworkFlax/Source/Combat/CombatController.cs` | `EchoNetwork.Combat` |
| `shadow_katana.gd` | `EchoNetworkFlax/Source/Combat/KatanaBladeSocket.cs` | `EchoNetwork.Combat` |
| `sector11_security_droid.gd` | `EchoNetworkFlax/Source/Enemies/SecurityDroidAI.cs` | `EchoNetwork.Enemies` |
| `specimen_ex000.gd` | `EchoNetworkFlax/Source/Enemies/ChimeraBossAI.cs` | `EchoNetwork.Enemies` |
| `dr_kinga.gd` | `EchoNetworkFlax/Source/Enemies/DrKingaAI.cs` | `EchoNetwork.Enemies` |
| `japanese_town_modular_kit.gd` | `EchoNetworkFlax/Source/World/WorldStreamingManager.cs` | `EchoNetwork.World` |
| `hospital_interior.gd` | `EchoNetworkFlax/Source/World/EnterableInteriorManager.cs` | `EchoNetwork.World` |
| `japanese_moped.glb` | `EchoNetworkFlax/Source/Vehicles/VehicleController.cs` | `EchoNetwork.Vehicles` |
