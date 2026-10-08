# Sector 11 Opening Awakening Cryo-Chamber: Director Plan & Modular Geometry Architecture

**Author:** Worker 1 (Room Cinematic Director), EchoNetwork Team C  
**Date:** 2026-10-08  
**Scope:** Sector 11 Opening Awakening Room (Hermetic Isolation Chamber 1)  
**Target Path:** `artifacts/eleven-eleven/art/production/room-cinematic-kit-20261008/director-plan.md`  

---

## 1. Executive Summary & Room Mandate

The Sector 11 Opening Awakening Cryo-Chamber is the player's introductory experience in *11.11*. It establishes the narrative tone: high-tension clinical sci-fi vulnerability, cold waking isolation, and mystery. In accordance with the Owner mandate and Canon:
- **Zero Supernatural Powers:** Echo awakens as a vulnerable human subject with zero combat powers, reality-glitch abilities, or spectral manifestations.
- **Physical Isolation:** The opening room is a hermetically sealed chamber with an independent PBR visual shell, zero shared walls, and zero light bleed into adjacent sectors.
- **Measured Footprint:** The room operates under the strict `opening_only` boundary: **18.0m Width × 25.4m Length × 7.2m Height** (Z = +7.0m to -18.0m, Center Z = -5.5m). It does **NOT** assume the full 42.0m corridor or adjacent generator facility.
- **Procedural Replacement:** This plan details the phased replacement of procedural box primitives in `sector11_visual_shell.gd` with modular architectural kit pieces while strictly preserving 100% of existing collision hulls, interaction triggers, and gameplay transforms.

---

## 2. Verified Coordinates & Landmark Invariants

All room coordinates are anchored to Godot world coordinates (`Vector3(X, Y, Z)`), with `Y = 0.0m` representing the top surface of the flooded floor deck. Every landmark below has been verified against `opening_room.gd`, `sector11_visual_shell.gd`, and `opening_web_room.tscn`. Their transforms and interaction volumes must remain **strictly untouched**:

| Landmark Asset | Verified Transform `(X, Y, Z)` | Orientation / Scale | Purpose / Script Authority |
| :--- | :--- | :--- | :--- |
| **Cryo Capsule (`Sector11Capsule`)** | `Vector3(-2.5, 0.0, 2.8)` | Rot Y: `+30°` (Basis: `0.6235, 0, 0.36`), Scale: `1.0` | Hero awakening pod; dais + pod visual; interaction starting point |
| **Echo Player Spawn (`EchoPlayer`)** | `Vector3(0.0, 0.0, 4.0)` | Facing `-Z` (North) | Player initial awakening spawn point |
| **Floating Companion Pod (`FloatingPod`)** | `Vector3(0.7, 1.5, 3.5)` | Hovering `Y = 1.5m` | AI companion drone initial hover anchor |
| **Antique Chronometer (`OpeningClock`)** | `Vector3(-1.85, 0.0, 1.8)` | Upright disc at `Y = 0.93m` | Primary narrative evidence #1; Area3D trigger (radius 2.4m) |
| **Sector Terminal (`SectorTerminal`)** | `Vector3(2.8, 0.0, 2.4)` | Facing `-X / -Z` console | Substation signal console puzzle; Area3D cylinder (r=1.55m) |
| **Photograph Evidence (`OpeningPhotograph`)** | `Vector3(3.7, 0.0, -1.5)` | Pedestal frame at `Y = 0.93m` | Primary narrative evidence #2; Area3D trigger (radius 2.4m) |
| **Primary Blast Gate (`PrimaryBlastGate`)** | `Vector3(0.0, 0.0, -18.0)` | Spans `X = [-3.6, +3.6]`, `H = 6.5m` | Room exit gate; locked state 0; BoxShape3D collider `7.2×6.5×0.8` |
| **High Vent Duct Aperture (`VentRim`)** | `Vector3(3.2, 1.8, -18.0)` | Rim centered `(3.2, 2.5, -17.95)` | Egress bypass duct to Room 2; TorusMesh inner 0.6m, outer 0.75m |
| **Emergency Warning Strobe (`EmergencyStrobe`)** | `Vector3(-6.0, 5.2, -4.0)` | OmniLight3D, range 8.0m | Warning beacon; pulsing red/amber strobe script |

---

## 3. Structural Envelope & Room Boundary Geometry

### 3.1 Dimensions & Coordinate Bounds
- **Width (X-axis):** `18.0m` (`X = -9.0m` to `+9.0m`)
- **Length (Z-axis):** `25.4m` (`Z = +7.0m` [South Rear Wall] to `Z = -18.0m` [North Bulkhead])
- **Height (Y-axis):** `7.2m` (`Y = 0.0m` [Floor Surface] to `Y = 7.2m` [Ceiling Structural Deck])
- **Geometric Center:** `Vector3(0.0m, 3.6m, -5.5m)`

```
                                NORTH BULKHEAD (Z = -18.0m)
                     [-9.0m]                  [0.0m]                   [+9.0m]
                     +--------------------------+----------------------------+
                     | Gate1_Bulkhead_West      | PrimaryBlastGate           | Gate1_Bulkhead_East   |
                     | (X = -6.3, W = 5.4m)     | (X = 0.0, W = 7.2m)        | (X = +6.3, W = 5.4m)  |
                     |                          |                            | [Vent Rim X=+3.2,Y=2.5]|
                     +--------------------------+----------------------------+
                     |                                                       |
                     |  Rib 05 (Z = -15.0m)      [Bay 03-L / 03-R]           |
                     |                                                       |
                     |  Rib 04 (Z = -10.0m)                                  |
                     |                                                       |
WEST CONTAINMENT     |  [Strobe: -6.0, 5.2, -4.0]                            | EAST CONTAINMENT
WALL (X = -9.0m)     |                                                       | WALL (X = +9.0m)
                     |  Rib 03 (Z = -5.0m)       [Photo: +3.7, -1.5]         | [Observation Bay
                     |                           [Bay 02-L]                  |  Z = -6.0m, W = 4.1m]
                     |                                                       |
                     |  Rib 02 (Z = 0.0m)                                    |
                     |                                                       |
                     |  Rib 01 (Z = +5.0m)       [Terminal: +2.8, +2.4]      |
                     |   [Cryo: -2.5, +2.8]      [Bay 01-L / 01-R]           |
                     |   [Clock: -1.85, +1.8]    [Player: 0.0, +4.0]         |
                     |                           [Pod: +0.7, +3.5]           |
                     +-------------------------------------------------------+
                                SOUTH BULKHEAD (Z = +7.0m)
```

### 3.2 South Containment Bulkhead (Rear Awakening Alcove)
- **Position:** `Vector3(0.0, 3.6, 7.0)`
- **Dimensions:** `18.0m Width × 7.2m Height × 0.8m Depth`
- **Current Primitive:** Single box collider & mesh `SouthContainmentWall_Body`.
- **Modular Replacement:** Heavy reinforced containment wall composed of 3 modular wall sections (5.4m × 7.2m × 0.4m each), recessed vertical umbilical chase directly behind the Cryo Capsule (`X = -2.5m`), and high-voltage feeder busbars connecting to overhead cable trays.
- **Collision Preservation:** Maintain `SouthContainmentWall_Body` static collider (`18.0 × 7.2 × 0.8` at `(0.0, 3.6, 7.0)`).

### 3.3 North Containment Bulkhead (Blast Gate Portal & Vent Egress)
- **Position:** `Z = -18.0m`
- **Current Primitives:**
  - `Gate1_Bulkhead_West`: `Vector3(5.4, 7.2, 0.8)` at `Vector3(-6.3, 3.6, -18.0)`.
  - `Gate1_Bulkhead_East`: `Vector3(5.4, 7.2, 0.8)` at `Vector3(6.3, 3.6, -18.0)`.
  - `Gate1_Bulkhead_Lintel`: `Vector3(7.2, 0.7, 0.8)` at `Vector3(0.0, 6.85, -18.0)`.
  - Door Aperture: Clear opening from `X = -3.6m` to `X = +3.6m` (`7.2m` width), `Y = 0.0m` to `Y = 6.5m`.
- **Modular Replacement:**
  - West Flank Module: 5.4m reinforced blast armor bulkhead with hydraulic locking pins and warning signage.
  - East Flank Module: 5.4m reinforced bulkhead integrated with the **High Vent Duct Aperture** at `X = +3.2m, Y = 1.8m` (reinforcing flange around the 1.2m × 1.4m opening).
  - Overhead Lintel Cassette: 7.2m structural housing for sliding gate tracks, hydraulic rams, and emergency warning beacons.
- **Collision Preservation:** Exact preservation of the two flanking static bodies and lintel static body.

### 3.4 Lateral Containment Walls (West & East Boundaries)
- **Position:** `X = -9.0m` (West) and `X = +9.0m` (East), spanning `Z = +7.0m` to `-18.0m` (`25.4m` length).
- **Current Primitives:** `WestContainmentWall` and `EastContainmentWall` (BoxShape3D `0.8 × 7.2 × 25.4`).
- **Modular Rhythm:** Built from modular bays positioned between structural ribs (see Section 4).

---

## 4. Modular Architectural Kit & Structural Grid

The chamber's architecture follows a strict **5.0m structural rhythm** along the Z-axis, defining 5 structural rib stations and 3 full architectural bays.

### 4.1 Structural Rib Grid (5m Spacing)
Structural ribs provide vertical wall articulation, ceiling beam support, and utility routing:
- **Rib 01:** `Z = +5.0m` (Awakening Alcove Rib)
- **Rib 02:** `Z = 0.0m` (Mid-Chamber Transition Rib)
- **Rib 03:** `Z = -5.0m` (Evidence & Observation Axis Rib)
- **Rib 04:** `Z = -10.0m` (Approach Rib)
- **Rib 05:** `Z = -15.0m` (Blast Gate Portal Anteroom Rib)

Each rib assembly consists of:
1. **Vertical Wall Columns (Left & Right):**
   - Dimensions: `0.42m Width × 6.7m Height × 0.55m Depth`
   - Positions: `X = ±8.78m`, `Y = 3.35m`, `Z = [5.0, 0.0, -5.0, -10.0, -15.0]`
   - Architectural detail: Chamfered titanium casing with recessed conduits and seismic anchor brackets at floor/ceiling interfaces.
2. **Ceiling Cross-Beam:**
   - Dimensions: `17.3m Span × 0.38m Height × 0.60m Depth`
   - Position: `X = 0.0m`, `Y = 6.6m`, `Z = [5.0, 0.0, -5.0, -10.0, -15.0]`
   - Architectural detail: Heavy I-beam profile with lightening holes and conduit routing clips.
3. **Overhead Service Truss:**
   - Dimensions: `16.2m Span × 0.12m Height × 0.26m Depth`
   - Position: `X = 0.0m`, `Y = 6.05m`, `Z = [5.0, 0.0, -5.0, -10.0, -15.0]`
   - Architectural detail: Welded tubular ladder truss carrying secondary pneumatic lines.

### 4.2 Wall Module Bays (3 Active Stations in Opening Room)
Between structural ribs, three wall bays exist on each side:
- **Bay 01:** Centered at `Z = +2.0m` (Span `Z = +4.7m` to `-0.3m`)
- **Bay 02:** Centered at `Z = -6.0m` (Span `Z = -5.3m` to `-9.7m`)
- **Bay 03:** Centered at `Z = -15.0m` (Span `Z = -14.7m` to `-17.7m`)

#### Distribution of Wall Modules:
1. **West Wall (`X = -9.0m`):**
   - `Z = +2.0m`: `ServiceModule_01_L` (Recessed power distribution bus, diagnostic terminals, hydraulic lines).
   - `Z = -6.0m`: `ServiceModule_02_L` (Ventilation plenum, status indicators; mounts `EmergencyStrobe` at `X = -6.0, Y = 5.2, Z = -4.0`).
   - `Z = -15.0m`: `ServiceModule_03_L` (Hydraulic accumulator module for North Blast Gate).
2. **East Wall (`X = +9.0m`):**
   - `Z = +2.0m`: `ServiceModule_01_R` (Signal routing panel adjacent to `SectorTerminal` at `X = 2.8, Z = 2.4`).
   - `Z = -6.0m`: `ObservationModule_02` (**Observation Bay Window**).
     - Dimensions: `4.1m Width × 3.45m Height × 0.28m Depth`, sill at `Y = 1.57m`, header at `Y = 5.13m`.
     - Multi-pane reinforced ballistic lead glass (`3.8m × 3.15m × 0.045m`), cyan illuminated divider mullion, "OBSERVATION // 02" stencil labeling. Overlooks dark dormant quarantine observation wing.
   - `Z = -15.0m`: `ServiceModule_03_R` (Auxiliary telemetry station).

### 4.3 Ceiling Light Cassette Grid
The central ceiling spine features 5 illuminated modular cassettes:
- Positions: `Z = [+2.5m, -2.5m, -7.5m, -12.5m, -17.5m]` at `Y = 6.81m`, centered at `X = 0.0m`.
- Dimensions per cassette: `3.2m Width × 0.25m Height × 4.2m Length`.
- Features: Recessed acrylic diffuser lenses with obsidian framing.
- Lighting association:
  - Cool Lab Fill (`CoolLabKey`): Color `(0.78, 0.83, 0.90)`, energy `1.2`, range `12.0m` at odd indices (`Z = 0.0m`, `Z = -10.0m`).
  - Warm Containment Beacons: Color `(1.0, 0.33, 0.12)`, energy `0.38`, range `6.0m` at `Z = +0.5m` and `Z = -14.5m`.

### 4.4 Flooded Floor Drainage Tray & Maintenance Deck
- **Substrate Body:** StaticBody3D `FloodedFloorBody` at `Vector3(0.0, -0.2, -5.5)`, size `18.0m × 0.4m × 25.4m`.
- **Surface Level:** Finished walking plane at `Y = 0.0m`.
- **Flooded Water Overlay:**
  - Shader: `flooded_lab_floor.gdshader`.
  - Water Depth: ~`0.02m` to `0.04m` standing puddle layer.
  - Surface Properties: Roughness `0.03`, Specular `0.95`, Puddle Coverage `0.52`, Water Tint `Color(0.015, 0.25, 0.34, 1.0)`.
  - Acoustic / Traversal: Footstep audio triggers shallow water splash SFX with metallic deck reverb.
- **Deck Expansion Inlays:**
  - Transverse joints every 5m along Z: `Z = [+1.0m, -4.0m, -9.0m, -14.0m]`.
  - Flanking maintenance panels at `X = ±6.3m`, size `2.6m × 1.15m`.

---

## 5. Procedural Primitives Replacement Strategy

Currently, `sector11_visual_shell.gd` builds numerous box primitives using `BoxMesh` and `_add_box()`. Here is the exact mapping to replace procedural meshes with high-fidelity modular assets:

| Procedural Code Function | Current Primitive Meshes | Target Modular Kit GLB Asset | Collision & Logic Action |
| :--- | :--- | :--- | :--- |
| `_build_boundaries()`: West/East walls | 2× BoxMesh `0.8 × 7.2 × 25.4` | `sector11_containment_wall_bay_v1.glb` (instanced per 5m bay) | Keep `StaticBody3D` hulls intact; hide/remove procedural BoxMesh visual |
| `_build_boundaries()`: South Wall | 1× BoxMesh `18.0 × 7.2 × 0.8` | `sector11_rear_bulkhead_v1.glb` (alcove + umbilical chase) | Keep `SouthContainmentWall_Body` static collider intact |
| `_build_boundaries()`: North Bulkheads | 2× BoxMesh `5.4 × 7.2 × 0.8` + Lintel BoxMesh | `sector11_portal_bulkhead_west_v1.glb`, `sector11_portal_bulkhead_east_v1.glb` | Keep `Gate1_Bulkhead_West/East/Lintel` colliders intact; integrate Vent Duct rim |
| `_build_structural_ribs()` | 10× ContainmentRib + 5× CeilingCrossBeam + 5× ServiceTruss | `sector11_structural_rib_assembly_v1.glb` (instanced at 5 stations) | Mesh-only visual replacement; ribs remain non-collidable (contained inside wall bounds) |
| `_build_wall_panels()` | Procedure instantiating observation & service modules | Already using `sector11_observation_module_v1.glb` and `sector11_service_module_v1.glb` | Refine mesh details, normal maps, and emissive stencils |
| `_build_ceiling_lights()` | Procedure instantiating ceiling tiles | `sector11_ceiling_tile_v1.glb` | Preserve existing tile positions and OmniLight3D children |
| `_build_service_conduits()` | CylinderMesh pipes + BoxMesh signal rails | `sector11_conduit_bundle_v1.glb` | Replace uniform cylinders with realistic flanged piping, bracket clamps, and valve junctions |
| `_build_floor_inlays()` | 8× DeckExpansionJoint + 16× MaintenanceDeckPanel | `sector11_floor_deck_tray_v1.glb` | Baked normal/parallax floor tiles mapped onto `flooded_lab_floor.gdshader` |

---

## 6. Integration & Verification Safeguards

1. **No Logic Regression:**
   - `opening_web_handoff.gd`, `opening_evidence.gd`, `substation_terminal.gd`, and `blast_gate.gd` depend on exact Node names and positions. All new visual models are slotted as children under the existing named nodes or replace `MeshInstance3D` meshes without changing parent node names.
2. **Watertight Boundary:**
   - Outer shell remains completely enclosed (`18.0 × 25.4 × 7.2m`). No camera clipping or exterior light leaks into the chamber.
3. **Rendering & Performance Budget:**
   - Target frame rate: 60 FPS on desktop, 30+ FPS on target mobile/web (`gl_compatibility`).
   - Draw calls for opening shell visual components: ≤ 65 batches (via material sharing and mesh instancing).
   - Total primitive count for opening shell: ≤ 120,000 vertices (LOD0).

---

*End of Director Plan.*
