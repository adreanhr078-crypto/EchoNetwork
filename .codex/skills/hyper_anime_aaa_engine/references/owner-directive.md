# MANDATORY ARCHITECTURAL DIRECTIVE: BUILD THE PERMANENT "HYPER-ANIME AAA ENGINE" SKILL & CORE PIPELINE (GODOT 4.8)

You are operating on High Effort. From this moment forward, we are elevating our entire Godot 4.8 3D game to a visual, kinetic, and atmospheric standard that surpasses *Genshin Impact*, *Wuthering Waves*, and *Zenless Zone Zero*, outperforming the highest benchmark outputs of Claude Opus 5.5.

Every single asset, scene, room, character, UI element, camera movement, and combat/traversal mechanic built in this project MUST strictly obey this system. Dull colors, static lighting, stiff animations, robotic cameras, or empty environments are strictly forbidden.

Execute ALL THREE PHASES below completely. Write full, production-ready code with deeply implemented math, shaders, and procedural systems—ZERO placeholders or `TODO` comments.

---

## PHASE 1: INSTALL PERMANENT GLOBAL SKILL & REPOSITORY CONSTITUTION
Create `.codex/skills/hyper_anime_aaa_engine/SKILL.md` AND enforce it at the very top of `AGENTS.md` (and `.cursorrules`) so every future task automatically loads and obeys these 5 Pillars:

### Pillar 1: Hyper-Chromatic Color & Rendering Standard (Beyond Genshin)
- **Renderer:** Forward+ with HDR 3D rendering, MSAA 4x, and Screen-Space AA.
- **Tonemapping & Color Grading:** Always use `TONE_MAPPER_ACES` (`exposure = 1.18`, `white = 6.5`) paired with dynamic color correction (`saturation = 1.38`, `contrast = 1.22`, `brightness = 1.04`).
- **Chromatic Shadows Rule:** Shadows and ambient occlusion must NEVER be black or grey. Always inject rich chromatic bounce light into shadows (Deep Royal Indigo `#141038` for cool/night zones, Vibrant Magenta-Violet `#2a0f3d` for arcane rooms, Warm Golden-Crimson `#3b1219` for warm/sunset zones).
- **Multi-Layer Atmosphere:** Every scene MUST initialize with **Volumetric Fog** (anisotropic light scattering `0.7`, height falloff, colored light absorption), **HDR Multi-Bicubic Glow/Bloom** (`hdr_threshold = 0.85`, soft screen/additive blend), **SSR (Screen-Space Reflections)**, **SSAO**, and **SSIL** (Indirect Lighting) so glowing magic and colorful surfaces visibly bounce color onto nearby walls and characters.

### Pillar 2: Universal Custom Shader Mandate (Zero Default Materials)
- Plain `StandardMaterial3D` is banned for visible geometry.
- Every character, monster, weapon, and interactive prop must use our custom **Multi-Band Anime Cel + Rim + Specular Shader** featuring crisp shadow steps, subsurface scattering (SSS) tinting on skin/cloth edges, iridescent/anisotropic highlights, and intense **View-Space Fresnel Rim Lighting** that dynamically inherits local lighting colors.
- Environments (floors, glass tubes, walls, water, portals) must use custom shaders featuring parallax depth, emission pulse masks, reflection roughness maps, and real-time player proximity interaction.

### Pillar 3: Kinetic AAA Camera System (ZZZ / WuWa Style)
- Never use a rigid, static `Camera3D` parented directly to the player.
- Always route cameras through our `DynamicActionCameraRig` featuring:
  - **Spring-Damper Third-Person Follow** with velocity-based predictive look-ahead.
  - **Speed-Reactive FOV & Dutch Tilt:** Smoothly widen FOV when sprinting/dashing/rolling and apply subtle banking roll (`1.5° to 3.5°`) during sharp turns and parkour maneuvers.
  - **Multi-Frequency Trauma Shake & Hit-Stop:** Directional camera punch, chromatic aberration spikes, and radial motion blur bursts on attacks, landings, and glass/object shatters.

### Pillar 4: Fluid Locomotion, Parkour & Secondary Physics
- Movement must never feel linear or robotic. All locomotion must use **Exponential Velocity Interpolation** with custom acceleration/deceleration curves, lean-into-turn procedural bone/mesh tilting (`rotation.z` & `rotation.x` velocity coupling), and squash-and-stretch micro-scaling on jump/land/roll.
- **Secondary Motion:** Always drive procedural spring physics for hair, capes, coats, and accessories synced with a global wind + player velocity vector.

### Pillar 5: Omni-Present Interactive VFX Density
- No action happens silently or invisibly. Walking, running, climbing, rolling, idle breathing, UI opening, and combat must continuously emit layered `GPUParticles3D`:
  - **Ground Interaction:** Footstep energy ripples, dust bursts, elemental sparks, and surface-matched decals.
  - **Motion Trails:** Ribbon trails (`TrailMesh` / `RibbonTrailMesh`) with emissive gradient falloff on fast limb movements, dashes, and weapon swings.
  - **Ambient Micro-Life:** Every room/zone must have 3 depth layers of ambient floating particles (foreground bokeh motes, mid-ground swirling elemental embers/petals with curl turbulence, and background volumetric light shafts).

---

## PHASE 2: IMPLEMENT THE CORE ENGINE MODULES IN GODOT 4.8 NOW
Build and wire the following complete, production-ready modules into our project immediately:

### 1. `res://engine_visuals/HyperAnimeWorldManager.gd` (Autoload Post-Processing & Chromatic Engine)
Write a complete Autoload singleton that automatically injects and manages:
- A master `WorldEnvironment` + `CameraAttributesPractical` + dual `DirectionalLight3D` setup (Key Light + Chromatic Rim Counter-Light).
- Real-time rich presets (`"arcane_neon_sanctuary"`, `"celestial_vivid_day"`, `"crimson_overdrive"`, `"abyssal_bioluminescence"`) with smooth `Tween` morphing of sky shaders, volumetric fog density/scattering, bloom intensity, and shadow chromatic tint.
- A global screen-space shockwave, chromatic aberration pulse, and hit-stop time-scale controller (`trigger_impact_pulse(intensity, duration, world_pos)`).

### 2. `res://engine_visuals/shaders/hyper_anime_uber.gdshader` (Master Character & World Shader)
Write our flagship Godot 4.8 spatial shader supporting:
- **3-Tone Chromatic Cel Ramp** with adjustable shadow border warmth/coolness and self-shadow attenuation.
- **Dual Rim Lighting:** Sharp view-aligned Fresnel highlight + light-direction masked neon backlight.
- **Dynamic Emission & Energy Flow:** Scrolling UV energy veins / pulse waves across outfits, weapons, or sci-fi/fantasy props.
- **Global Player Proximity & Wind Sync:** Reacts to `global uniform vec3 player_world_pos` and `global uniform vec4 global_wind_data`.

### 3. `res://engine_visuals/shaders/reactive_surface_pro.gdshader` (Floors, Water, Glass & Interactive Surfaces)
Write a surface shader for floors, liquids, and architectural surfaces that provides:
- High-clarity SSR + Reflection blending with chromatic Fresnel grazing angles.
- **Real-time 16-Point Ripple & Energy Imprint Array:** Automatically spawns glowing concentric distortion/color rings wherever the player steps, lands, or rolls.
- Subtle animated grid/rune or caustics subsurface layer that illuminates as the player approaches.

### 4. `res://engine_visuals/camera/DynamicActionCameraRig.gd` (Pro Cinematic & Gameplay Camera)
Write a complete, drop-in 3D Camera Controller node with:
- Smooth spring-arm collision avoidance, velocity lag, and combat lock-on framing.
- Dynamic FOV scaling (`base_fov = 70.0` up to `92.0` on high-speed dash/parkour), procedural banking tilt on lateral movement, and spring-based landing compression.
- Built-in Perlin-noise trauma shake (`add_trauma(amount, direction)`) affecting both rotational angles and subtle FOV kicks.

### 5. `res://engine_visuals/vfx/KineticVFXOrchestrator.gd` (Procedural Particle & Trail Factory)
Write a self-contained VFX system that procedurally builds and pools `GPUParticles3D` and `ShaderMaterial` instances (no external missing textures required—generate crisp procedural radial/spark/ring gradients in shaders) for:
- **Locomotion VFX:** Footstep glowing rings, sprint wind-lines, dash after-image/bursts, and heavy landing shockwaves.
- **Environmental Turbulence:** Continuous multi-colored ambient magic motes, floating embers, and rising light streams around the active camera using Godot 4 `GPUParticlesAttractorVectorField3D` / turbulence noise.
- **Kinetic Feel Enhancer:** Procedural mesh tilt/lean helper that attaches to our character controller to give instant AAA weight, momentum, and responsiveness to walking, running, rolling, and climbing.

---

## PHASE 3: AUTO-INTEGRATION & VERIFICATION
1. Register `HyperAnimeWorldManager` and `KineticVFXOrchestrator` in `project.godot` Autoloads (and configure required global shader uniforms in `project.godot`).
2. Integrate `DynamicActionCameraRig`, the kinetic movement tilt/VFX hooks, and the new shaders directly into our existing player and main scene without breaking any existing gameplay logic or story/cutscene triggers.
3. Verify all `.gd` and `.gdshader` files for zero syntax errors in Godot 4.8.