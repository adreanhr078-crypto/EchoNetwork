# Echo Network — Asset Migration Manifest

This document catalogs all 3D assets, textures, animations, and audio staged for Flax Engine ingestion, specifying their origin, destination, and Flax import configurations.

---

## 1. Asset Staging Overview

All original source assets from the Godot project (`artifacts/eleven-eleven/godot/assets/`) have been verified and non-destructively mirrored into `FlaxMigration/SourceAssets/` ready for Flax Content packaging.

- **Total 3D Models (`.glb`):** 31 files
- **Total Skeletal Animations (`.fbx`):** 46 files
- **Total Textures (`.png` / `.jpg`):** 29 files
- **Audio Files (`.ogg`):** 1 file + procedural sound banks

---

## 2. Character & Monster Models

| Model File | Source Type | Rig / Skeleton | Flax Target Content Path | Flax Import Settings |
| :--- | :--- | :--- | :--- | :--- |
| `echo_opening_uniform_v9.glb` | GLTF/GLB (Tripo/Blender) | Humanoid (Mixamo-compatible) | `Content/Characters/Echo/Echo_Opening_Uniform.flax` | Skinned Model, Import Materials = true, Gen Normals = Smoothed |
| `echo_tripo_native.glb` | GLTF/GLB (High-Poly Base) | Humanoid (Mixamo-compatible) | `Content/Characters/Echo/Echo_Tripo_Native.flax` | Skinned Model, Meshopt optimization, 46k Quad retopo |
| `kinga_scientist.glb` | GLTF/GLB | Humanoid (Lab coat / scientist) | `Content/Characters/Kinga/Dr_Kinga.flax` | Skinned Model, Import Textures = true |
| `tripo_monster_v2.glb` | GLTF/GLB | Quadruped / Chimera Beast | `Content/Enemies/Chimera/Specimen_EX000.flax` | Skinned Model, Convex Collider generation = true |
| `echo_guide_core.glb` | GLTF/GLB | Non-skinned / Floating mechanical | `Content/Companions/EchoGuideCore.flax` | Static Model with emissive pulse material slot |

---

## 3. Skeletal Animation Clips (Mixamo FBX)

All animation clips are mapped to the standard Humanoid avatar skeleton for retargeting in the Flax `AnimationGraph`.

| Animation Clip File | Movement Category | Loop | Animation Graph Slot |
| :--- | :--- | :--- | :--- |
| `Standing Idle 04.fbx` / `Standing_Idle_04.fbx` | Locomotion | Yes | Base Layer / Idle BlendSpace |
| `Standard Walk.fbx` | Locomotion | Yes | Base Layer / Walk BlendSpace |
| `Standing Run Forward.fbx` | Locomotion | Yes | Base Layer / Run BlendSpace |
| `Standing Jump.fbx` | Airborne | No | Jump State / Takeoff |
| `Sword And Shield Jump.fbx` | Combat Jump | No | Airborne / Combat Jump |
| `Hard Landing.fbx` | Landing | No | Land State / Heavy Landing Recovery |
| `Running Slide.fbx` | Traversal / Parkour | No | Traversal / Slide State |
| `Run To Rolling.fbx` / `Stand To Roll.fbx` | Parkour Recovery | No | Traversal / Roll State |
| `Wall Run.fbx` | Parkour Traversal | Yes | Traversal / Wall-Run Horizontal |
| `Climbing Up Wall.fbx` | Parkour Traversal | No | Traversal / Ledge Vault |
| `Jumping To Hanging.fbx` / `Jump_To_Hang.fbx`| Parkour Traversal | No | Traversal / Ledge Grab |
| `Backflip.fbx` | Dodge / Evasion | No | Combat / Back Evasion Roll |
| `Sword And Shield Attack.fbx` | Combat | No | Attack Layer / Combo Slash 1 & 2 |
| `Great Sword Slash.fbx` | Combat | No | Attack Layer / Heavy Finisher Slash 3 |
| `Standing Melee Attack Downward.fbx` | Combat | No | Attack Layer / Overhead Cleave |
| `Butterfly_Twirl.fbx` | Combat Ability | No | Special / Aerial Spin Finisher |
| `Standing React Small From Left.fbx` | Reaction | No | Hit Layer / Additive Stagger Left |
| `Hit_Reaction_Body.fbx` / `Hit_Reaction_Head.fbx`| Reaction | No | Hit Layer / Stagger Back |
| `Standing Death Forward 01.fbx` | Death | No | Death Layer / Forward Collapse |
| `Mutant_Walking.fbx` | Enemy Locomotion | Yes | Chimera Boss / Stalk Walk |
| `Mutant_Punch.fbx` | Enemy Attack | No | Chimera Boss / Heavy Slam |

---

## 4. Environment & Prop Models

| Model File | Asset Type | Flax Target Content Path | Collision Strategy |
| :--- | :--- | :--- | :--- |
| `sector11-wake-capsule-v2.glb` | Key Cinematic Prop | `Content/Props/CryoCapsule_V2.flax` | Compound Box / Convex Hull |
| `sector11_cryo_pod_v1.glb` | Facility Prop | `Content/Props/Sector11_CryoPod.flax` | Mesh Collider (Static) |
| `hospital_bed.glb` | Interior Prop | `Content/Props/HospitalBed.flax` | Convex Hull |
| `restraint_chair.glb` | Facility Prop | `Content/Props/RestraintChair.flax` | Convex Hull |
| `server_rack.glb` | Facility Prop | `Content/Props/ServerRack.flax` | Box Collider |
| `retro_crt_tv.glb` | Prop | `Content/Props/RetroCRT_TV.flax` | Box Collider |
| `japanese_moped.glb` | Traversal Vehicle | `Content/Vehicles/JapaneseMoped.flax` | WheeledVehicle PhysX Rigging |
| `sector11_ceiling_tile_v1.glb` | Modular Architecture | `Content/Environment/Sector11/CeilingTile.flax`| Mesh Collider (Static) |
| `sector11_cryo_dais_v1.glb` | Modular Architecture | `Content/Environment/Sector11/CryoDais.flax` | Mesh Collider (Static) |
| `sector11_observation_module_v1.glb` | Modular Architecture | `Content/Environment/Sector11/ObservationModule.flax`| Mesh Collider (Static) |
| `sector11_service_module_v1.glb` | Modular Architecture | `Content/Environment/Sector11/ServiceModule.flax` | Mesh Collider (Static) |

---

## 5. Material & Texture Pipeline

Flax Engine uses an ORM (Occlusion, Roughness, Metallic) packed texture layout:
- **Red Channel:** Ambient Occlusion (AO)
- **Green Channel:** Roughness
- **Blue Channel:** Metallic

The Godot assets are already exported with paired ORM and NormalGL textures:
- `*_Color_*.png` → Flax Diffuse / Base Color Texture
- `*_NormalGL_*.png` → Flax Normal Map (Tangent Space, Y+ orientation)
- `*_ORM_*.png` → Flax Packed Specular / Metallic / Roughness Map

For the anime/cel-shaded materials, these textures feed directly into the custom `EchoToonMaterial.flax` shader graph.
