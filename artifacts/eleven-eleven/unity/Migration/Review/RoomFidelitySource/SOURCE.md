# Godot Room 01 transfer

Godot native launch chain is `scenes/boot.tscn`, `scripts/boot.gd`, `scenes/native_journey.tscn`, `scenes/system_journey_preview.tscn`, `scenes/opening_native_room.tscn`, `scenes/opening_web_room.tscn`. The room surface comes from `Sector11OpeningShell` and `Sector11Facility/Room1_CryoChamber` with the `main.gd` atmosphere adapter.

Stage `OpeningRoomFidelity.cs` as `Assets/ElevenEleven/Editor/OpeningRoomFidelity.cs`. Copy `godot/assets/props/sector11_supply_case_v1.glb` to `Assets/ElevenEleven/Opening/Room01/SupplyCase.glb`. Source SHA-256 is `d3198a5b7c3baf1008c0c895d2cb5d60207f65e9fce1c2c79fa1841ad6608d6f`. Both instances use the same asset. The GLB has one mesh with four primitives. Its visible extent fits the source 0.9 m box collider.

Call `OpeningRoomFidelity.Build(shell, wall, deck, gate);` in `ChapterSceneBuilder.BuildRoom` after `Point("Bulkhead glow", ...)` and before camera construction. Rebuild Room01. The helper checks the 18 × 25.4 m deck, Unity deck centre z = 5.5 m and gate at z = 18 m. Publish the generated `Assets/ElevenEleven/Opening/Room01/Fidelity/` assets and metadata alongside the scene, helper, source GLB and import metadata.

| Owning Godot source | Unity adaptation |
| --- | --- |
| `scripts/environment/sector11_visual_shell.gd` | Five structural bays at Unity z = −5, 0, 5, 10, 15 m, 20 rib and truss pieces, 20 floor inlay pieces, two coolant conduits, two cyan rails and the source sector sign. Existing Unity module and ceiling assets already cover the authored layout. |
| `scenes/environment/opening_web_facility.tscn`, `scenes/props/breakable_supply_crate.tscn` and `scripts/environment/opening_atmosphere.gd` | Source supply cases at Unity `(5, 0, 6)` and `(-6, 0, -4)`, with reflected authored yaw of 0° and 15°. The imported roots add a 180° correction because glTFast mirrors local X while this room mirrors world Z. Static collisions correspond to the Godot 0.9 m boxes. Break and reward behavior remains a later interaction transfer. |
| `scenes/environment/blast_gate.tscn` | Two machined pillars, top beam, brighter armor, moving amber seals and door label. Added gate parts are visual meshes. The existing moving door, collider, indicator and checkpoint remain the progression owners. |
| `shaders/opening_deck.gdshader` | Cached 1024² URP albedo and packed metallic/smoothness maps. The tile grid uses 1.5 × 2.4 m. Local coolant wetness is centred near the capsule at Unity `(−2.5, −2.8)` and wall drip at `(6.6, 5.5)` in XZ. Static material response is present in both motion modes. Ripple and power transfer are outside this increment. |
| `shaders/opening_wall_finish.gdshader` and Hyper Anime lower tier | Authored room wall tone, enamel bands at y ≈ 1.42 m, cool sky bounce, violet ground bounce, a brighter overhead key, a more neutral recovery light, cyan service guides and amber practicals. The existing realtime light count is preserved. |

Compare player arrival, both source evidence stops, and the sealed and open gate on Unity PC and Mobile. Godot references are under `audits/evidence/room01-20261012/school-wake-aligned-route-60-20261102/`, especially `00-arrival.png`, `03-signal-aligned.png` and `04-threshold.png`. The static transfer needs a rendered Unity review to establish readability and a native journey to establish the interaction outcome.
