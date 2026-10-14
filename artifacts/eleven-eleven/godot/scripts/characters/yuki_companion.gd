class_name YukiCompanion
extends CharacterBody3D

## AAA Narrative Companion: Yuki Tachibana (Class 2-B Stoic Vanguard)
## Sits directly left of Echo in Class 2-B (Row 4, Aisle).
## Provides:
## - In-class companionship and observational dialogue
## - Dynamic follow AI across the school campus & town
## - Tactical Cryo / Cyan combat assist strikes with frost slow debuff
## - Synergizes with CompanionBondManager (Tier 5 Glacial Vanguard perk)
## - Styled anime humanoid avatar with cool tones, ice-blue/lavender scarf, and cryo details
## - Procedural idle breathing bob, scarf tail sway, and stoic head tracking toward Echo

signal state_changed(new_state: int)
signal dialogue_spoken(speaker: String, text: String)
signal combat_assist_triggered(target: Node, damage: float, is_critical: bool)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const CompanionBondManagerScript = preload("res://scripts/systems/companion_bond_manager.gd")
const DynamicAIDialogueEngineScript = preload("res://scripts/systems/dynamic_ai_dialogue_engine.gd")

enum State {
	CLASSROOM_IDLE,
	FOLLOWING_PLAYER,
	COMBAT_ENGAGED
}

const DESK_POSITION: Vector3 = Vector3(-2.8, 3.8, 2.5)

@export var character_id: String = "YUKI"
@export var character_name: String = "Yuki Tachibana"
@export var role: String = "Class 2-B Student / Cryo Resonance Aegis"
@export var current_state: State = State.CLASSROOM_IDLE

var following_target: Node3D = null
var combat_assist_cooldown: float = 0.0
var base_assist_damage: float = 85.0
var follow_speed: float = 4.0
var stop_distance: float = 2.0

# Visual Avatar & Procedural Animation Nodes
var _avatar_root: Node3D = null
var _breathing_pivot: Node3D = null
var _head_pivot: Node3D = null
var _scarf_tail: Node3D = null
var _cryo_core: MeshInstance3D = null
var _idle_time: float = 0.0
var _breathing_base_y: float = 0.84

func _init() -> void:
	position = DESK_POSITION

func _ready() -> void:
	_setup_visual_avatar()
	sit_at_desk()

func _setup_visual_avatar() -> void:
	var avatar = find_child("YukiAvatarMesh", true, false)
	if avatar:
		_avatar_root = avatar as Node3D
		_breathing_pivot = _avatar_root.find_child("BreathingPivot", true, false) as Node3D
		_head_pivot = _avatar_root.find_child("HeadPivot", true, false) as Node3D
		_scarf_tail = _avatar_root.find_child("ScarfTailPivot", true, false) as Node3D
		_cryo_core = _avatar_root.find_child("CryoCoreMesh", true, false) as MeshInstance3D
		return

	_build_styled_humanoid_avatar()

## Builds a high-craft stylized anime humanoid avatar for Yuki Tachibana
## Cool tones, Minato Academy navy blazer, signature ice blue & lavender scarf, and cryo resonance details
func _build_styled_humanoid_avatar() -> void:
	var avatar_root := MeshInstance3D.new()
	avatar_root.name = "YukiAvatarMesh"
	avatar_root.position = Vector3(0, 0, 0)
	_avatar_root = avatar_root
	add_child(avatar_root)

	# --- Materials Palette ---
	# Fair porcelain anime skin with cool subtle rim
	var mat_skin := _create_mat(Color(0.96, 0.93, 0.90), 0.85, 0.0, Color.BLACK, 0.0, 0.25, 0.6)
	# Sleek midnight navy / raven layered hair with cool rim
	var mat_hair := _create_mat(Color(0.12, 0.15, 0.24), 0.50, 0.0, Color.BLACK, 0.0, 0.45, 0.85)
	# Minato Academy tailored navy blazer
	var mat_blazer := _create_mat(Color(0.12, 0.18, 0.32), 0.70)
	# Crisp white uniform shirt
	var mat_shirt := _create_mat(Color(0.95, 0.96, 0.98), 0.65)
	# Steel cyan school tie
	var mat_tie := _create_mat(Color(0.25, 0.45, 0.65), 0.50)
	# Signature ice blue scarf fabric with cool rim
	var mat_scarf_ice := _create_mat(Color(0.58, 0.75, 0.92), 0.60, 0.0, Color(0.58, 0.75, 0.92), 0.12, 0.35, 0.9)
	# Flowing lavender scarf tail accent
	var mat_scarf_lavender := _create_mat(Color(0.70, 0.65, 0.86), 0.60, 0.0, Color(0.70, 0.65, 0.86), 0.10, 0.35, 0.9)
	# Charcoal pleated uniform skirt
	var mat_skirt := _create_mat(Color(0.16, 0.18, 0.25), 0.70)
	# Dark opaque 80-denier tights
	var mat_tights := _create_mat(Color(0.14, 0.14, 0.18), 0.80)
	# Sleek polished black school shoes
	var mat_shoes := _create_mat(Color(0.08, 0.08, 0.10), 0.25)
	# Crystalline cyan / violet anime eyes with cryo resonance glow
	var mat_eyes := _create_mat(Color(0.18, 0.75, 0.95), 0.20, 0.0, Color(0.10, 0.65, 0.95), 0.45)
	# Frost crystal hair barrette with icy luminescence
	var mat_frost_barrette := _create_mat(Color(0.75, 0.92, 1.0), 0.15, 0.3, Color(0.40, 0.85, 1.0), 0.55)
	# Tactical cryo holster casing
	var mat_holster := _create_mat(Color(0.10, 0.12, 0.16), 0.40)
	# Luminescent cyan cryo resonance core
	var mat_cryo_core := _create_mat(Color(0.0, 0.85, 1.0), 0.10, 0.0, Color(0.0, 0.85, 1.0), 0.85)
	# Silver blazer buttons & buckles
	var mat_silver := _create_mat(Color(0.85, 0.88, 0.92), 0.25, 0.8)

	# --- Hierarchy Structure ---
	var body_root := Node3D.new()
	body_root.name = "BodyRoot"
	avatar_root.add_child(body_root)

	# 1. Lower Body (Legs & Shoes)
	var legs_node := Node3D.new()
	legs_node.name = "LegsNode"
	body_root.add_child(legs_node)

	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.056
	leg_mesh.height = 0.46
	var leg_l := _create_mesh_part(leg_mesh, mat_tights, Vector3(-0.095, 0.38, 0.0), Vector3.ZERO, Vector3.ONE, "LegLeft")
	var leg_r := _create_mesh_part(leg_mesh, mat_tights, Vector3(0.095, 0.38, 0.0), Vector3.ZERO, Vector3.ONE, "LegRight")
	legs_node.add_child(leg_l)
	legs_node.add_child(leg_r)

	var shoe_mesh := BoxMesh.new()
	shoe_mesh.size = Vector3(0.10, 0.07, 0.18)
	var shoe_l := _create_mesh_part(shoe_mesh, mat_shoes, Vector3(-0.095, 0.04, -0.02), Vector3.ZERO, Vector3.ONE, "ShoeLeft")
	var shoe_r := _create_mesh_part(shoe_mesh, mat_shoes, Vector3(0.095, 0.04, -0.02), Vector3.ZERO, Vector3.ONE, "ShoeRight")
	legs_node.add_child(shoe_l)
	legs_node.add_child(shoe_r)

	# 2. Hips & Pleated Skirt
	var hips_node := Node3D.new()
	hips_node.name = "HipsNode"
	hips_node.position = Vector3(0, 0.74, 0)
	body_root.add_child(hips_node)

	var skirt_mesh := CylinderMesh.new()
	skirt_mesh.top_radius = 0.185
	skirt_mesh.bottom_radius = 0.28
	skirt_mesh.height = 0.28
	var skirt := _create_mesh_part(skirt_mesh, mat_skirt, Vector3(0, -0.06, 0), Vector3.ZERO, Vector3.ONE, "SkirtMesh")
	hips_node.add_child(skirt)

	var belt_mesh := CylinderMesh.new()
	belt_mesh.top_radius = 0.18
	belt_mesh.bottom_radius = 0.19
	belt_mesh.height = 0.04
	var belt := _create_mesh_part(belt_mesh, mat_shoes, Vector3(0, 0.07, 0), Vector3.ZERO, Vector3.ONE, "BeltMesh")
	hips_node.add_child(belt)

	var buckle_mesh := BoxMesh.new()
	buckle_mesh.size = Vector3(0.04, 0.035, 0.02)
	var buckle := _create_mesh_part(buckle_mesh, mat_silver, Vector3(0, 0.07, -0.185), Vector3.ZERO, Vector3.ONE, "BeltBuckle")
	hips_node.add_child(buckle)

	# 3. Breathing Pivot (Torso + Blazer + Scarf + Head)
	var breathing_pivot := Node3D.new()
	breathing_pivot.name = "BreathingPivot"
	breathing_pivot.position = Vector3(0, _breathing_base_y, 0)
	_breathing_pivot = breathing_pivot
	body_root.add_child(breathing_pivot)

	# Navy Blazer Torso
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.17
	torso_mesh.height = 0.42
	var torso := _create_mesh_part(torso_mesh, mat_blazer, Vector3(0, 0.22, 0), Vector3.ZERO, Vector3.ONE, "TorsoMesh")
	breathing_pivot.add_child(torso)

	# Blazer Lapels
	var lapel_mesh := BoxMesh.new()
	lapel_mesh.size = Vector3(0.06, 0.24, 0.02)
	var lapel_l := _create_mesh_part(lapel_mesh, mat_blazer, Vector3(-0.07, 0.26, -0.155), Vector3(0, 0, deg_to_rad(-12.0)), Vector3.ONE, "LapelLeft")
	var lapel_r := _create_mesh_part(lapel_mesh, mat_blazer, Vector3(0.07, 0.26, -0.155), Vector3(0, 0, deg_to_rad(12.0)), Vector3.ONE, "LapelRight")
	breathing_pivot.add_child(lapel_l)
	breathing_pivot.add_child(lapel_r)

	# White Uniform Shirt & Steel Cyan Tie
	var shirt_v_mesh := BoxMesh.new()
	shirt_v_mesh.size = Vector3(0.10, 0.18, 0.015)
	var shirt_v := _create_mesh_part(shirt_v_mesh, mat_shirt, Vector3(0, 0.28, -0.15), Vector3.ZERO, Vector3.ONE, "ShirtInner")
	breathing_pivot.add_child(shirt_v)

	var tie_mesh := BoxMesh.new()
	tie_mesh.size = Vector3(0.04, 0.16, 0.02)
	var tie := _create_mesh_part(tie_mesh, mat_tie, Vector3(0, 0.23, -0.16), Vector3.ZERO, Vector3.ONE, "TieMesh")
	breathing_pivot.add_child(tie)

	var button_mesh := SphereMesh.new()
	button_mesh.radius = 0.012
	button_mesh.height = 0.015
	var button := _create_mesh_part(button_mesh, mat_silver, Vector3(0, 0.12, -0.165), Vector3.ZERO, Vector3.ONE, "BlazerButton")
	breathing_pivot.add_child(button)

	# Tactical Cryo Holster & Core Charm on Right Hip
	var holster_mesh := BoxMesh.new()
	holster_mesh.size = Vector3(0.06, 0.09, 0.05)
	var holster := _create_mesh_part(holster_mesh, mat_holster, Vector3(0.19, -0.02, 0.06), Vector3(0, deg_to_rad(-15.0), deg_to_rad(-5.0)), Vector3.ONE, "CryoHolster")
	breathing_pivot.add_child(holster)

	var cryo_core_mesh := SphereMesh.new()
	cryo_core_mesh.radius = 0.02
	cryo_core_mesh.height = 0.03
	var cryo_core := _create_mesh_part(cryo_core_mesh, mat_cryo_core, Vector3(0.21, -0.02, 0.08), Vector3.ZERO, Vector3.ONE, "CryoCoreMesh")
	_cryo_core = cryo_core
	breathing_pivot.add_child(cryo_core)

	# Arms in Poised, Alert Demeanor
	var upper_arm_mesh := CapsuleMesh.new()
	upper_arm_mesh.radius = 0.055
	upper_arm_mesh.height = 0.28
	var arm_l := _create_mesh_part(upper_arm_mesh, mat_blazer, Vector3(-0.20, 0.22, 0.0), Vector3(0, 0, deg_to_rad(-8.0)), Vector3.ONE, "ArmLeft")
	var arm_r := _create_mesh_part(upper_arm_mesh, mat_blazer, Vector3(0.20, 0.22, 0.0), Vector3(0, 0, deg_to_rad(8.0)), Vector3.ONE, "ArmRight")
	breathing_pivot.add_child(arm_l)
	breathing_pivot.add_child(arm_r)

	var forearm_mesh := CapsuleMesh.new()
	forearm_mesh.radius = 0.048
	forearm_mesh.height = 0.24
	var forearm_l := _create_mesh_part(forearm_mesh, mat_blazer, Vector3(-0.22, -0.01, 0.02), Vector3(deg_to_rad(8.0), 0, deg_to_rad(-4.0)), Vector3.ONE, "ForearmLeft")
	var forearm_r := _create_mesh_part(forearm_mesh, mat_blazer, Vector3(0.21, -0.01, 0.04), Vector3(deg_to_rad(14.0), deg_to_rad(-10.0), deg_to_rad(4.0)), Vector3.ONE, "ForearmRight")
	breathing_pivot.add_child(forearm_l)
	breathing_pivot.add_child(forearm_r)

	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.038
	hand_mesh.height = 0.06
	var hand_l := _create_mesh_part(hand_mesh, mat_skin, Vector3(-0.22, -0.14, 0.02), Vector3.ZERO, Vector3.ONE, "HandLeft")
	var hand_r := _create_mesh_part(hand_mesh, mat_skin, Vector3(0.21, -0.13, 0.06), Vector3.ZERO, Vector3.ONE, "HandRight")
	breathing_pivot.add_child(hand_l)
	breathing_pivot.add_child(hand_r)

	# --- 4. Signature Ice Blue / Lavender Scarf ---
	var scarf_neck_mesh := TorusMesh.new()
	scarf_neck_mesh.inner_radius = 0.065
	scarf_neck_mesh.outer_radius = 0.145
	var scarf_neck := _create_mesh_part(scarf_neck_mesh, mat_scarf_ice, Vector3(0, 0.42, 0), Vector3(deg_to_rad(8.0), 0, 0), Vector3.ONE, "ScarfNeckWrap")
	breathing_pivot.add_child(scarf_neck)

	var scarf_knot_mesh := BoxMesh.new()
	scarf_knot_mesh.size = Vector3(0.08, 0.06, 0.05)
	var scarf_knot := _create_mesh_part(scarf_knot_mesh, mat_scarf_ice, Vector3(-0.08, 0.38, -0.11), Vector3(0, deg_to_rad(10.0), deg_to_rad(15.0)), Vector3.ONE, "ScarfKnot")
	breathing_pivot.add_child(scarf_knot)

	# Scarf Tail Pivot for subtle procedural sway
	var scarf_tail_pivot := Node3D.new()
	scarf_tail_pivot.name = "ScarfTailPivot"
	scarf_tail_pivot.position = Vector3(-0.10, 0.37, -0.06)
	_scarf_tail = scarf_tail_pivot
	breathing_pivot.add_child(scarf_tail_pivot)

	var scarf_upper_mesh := BoxMesh.new()
	scarf_upper_mesh.size = Vector3(0.07, 0.18, 0.02)
	var scarf_upper := _create_mesh_part(scarf_upper_mesh, mat_scarf_ice, Vector3(0, -0.08, 0), Vector3(deg_to_rad(12.0), 0, deg_to_rad(-10.0)), Vector3.ONE, "ScarfTailUpper")
	scarf_tail_pivot.add_child(scarf_upper)

	var scarf_lower_mesh := BoxMesh.new()
	scarf_lower_mesh.size = Vector3(0.075, 0.20, 0.018)
	var scarf_lower := _create_mesh_part(scarf_lower_mesh, mat_scarf_lavender, Vector3(0.015, -0.22, 0.025), Vector3(deg_to_rad(18.0), 0, deg_to_rad(-6.0)), Vector3.ONE, "ScarfTailLower")
	scarf_tail_pivot.add_child(scarf_lower)

	# --- 5. Neck & Head Pivot ---
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.052
	neck_mesh.bottom_radius = 0.054
	neck_mesh.height = 0.11
	var neck := _create_mesh_part(neck_mesh, mat_skin, Vector3(0, 0.45, 0), Vector3.ZERO, Vector3.ONE, "NeckMesh")
	breathing_pivot.add_child(neck)

	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0, 0.54, 0)
	_head_pivot = head_pivot
	breathing_pivot.add_child(head_pivot)

	# Stylized anime head & refined jawline
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.145
	head_mesh.height = 0.29
	var head := _create_mesh_part(head_mesh, mat_skin, Vector3(0, 0, 0), Vector3.ZERO, Vector3.ONE, "HeadMesh")
	head_pivot.add_child(head)

	var face_jaw_mesh := CapsuleMesh.new()
	face_jaw_mesh.radius = 0.115
	face_jaw_mesh.height = 0.23
	var face_jaw := _create_mesh_part(face_jaw_mesh, mat_skin, Vector3(0, -0.035, -0.04), Vector3.ZERO, Vector3.ONE, "FaceJawMesh")
	head_pivot.add_child(face_jaw)

	# Crystalline cyan anime eyes with cryo glow
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.025
	eye_mesh.height = 0.032
	var eye_l := _create_mesh_part(eye_mesh, mat_eyes, Vector3(-0.052, 0.015, -0.13), Vector3.ZERO, Vector3(1, 1.35, 0.3), "EyeLeft")
	var eye_r := _create_mesh_part(eye_mesh, mat_eyes, Vector3(0.052, 0.015, -0.13), Vector3.ZERO, Vector3(1, 1.35, 0.3), "EyeRight")
	head_pivot.add_child(eye_l)
	head_pivot.add_child(eye_r)

	# Hair: Back layered midnight navy hair
	var hair_back_mesh := SphereMesh.new()
	hair_back_mesh.radius = 0.165
	hair_back_mesh.height = 0.36
	var hair_back := _create_mesh_part(hair_back_mesh, mat_hair, Vector3(0, 0.02, 0.045), Vector3.ZERO, Vector3(1.05, 1.25, 1.05), "HairBack")
	head_pivot.add_child(hair_back)

	# Hair: Sharp parted bangs fringe
	var bangs_mesh := CapsuleMesh.new()
	bangs_mesh.radius = 0.038
	bangs_mesh.height = 0.23
	var bangs := _create_mesh_part(bangs_mesh, mat_hair, Vector3(0, 0.095, -0.115), Vector3(deg_to_rad(18.0), 0, deg_to_rad(85.0)), Vector3.ONE, "HairBangs")
	head_pivot.add_child(bangs)

	# Hair: Sleek side locks
	var sidelock_mesh := CapsuleMesh.new()
	sidelock_mesh.radius = 0.032
	sidelock_mesh.height = 0.32
	var sidelock_l := _create_mesh_part(sidelock_mesh, mat_hair, Vector3(-0.145, -0.08, -0.04), Vector3(0, 0, deg_to_rad(-4.0)), Vector3.ONE, "HairSideLockL")
	var sidelock_r := _create_mesh_part(sidelock_mesh, mat_hair, Vector3(0.145, -0.08, -0.04), Vector3(0, 0, deg_to_rad(4.0)), Vector3.ONE, "HairSideLockR")
	head_pivot.add_child(sidelock_l)
	head_pivot.add_child(sidelock_r)

	# Accessory: Glacial frost crystal barrette on side
	var barrette_mesh := PrismMesh.new()
	barrette_mesh.size = Vector3(0.025, 0.05, 0.015)
	var barrette := _create_mesh_part(barrette_mesh, mat_frost_barrette, Vector3(0.13, 0.10, -0.09), Vector3(0, deg_to_rad(-15.0), deg_to_rad(-20.0)), Vector3.ONE, "FrostBarrette")
	head_pivot.add_child(barrette)

func _create_mat(albedo: Color, roughness: float = 0.7, metallic: float = 0.0, emission: Color = Color.BLACK, emission_energy: float = 0.0, rim: float = 0.0, rim_tint: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = metallic
	if emission != Color.BLACK and emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	if rim > 0.0:
		mat.rim_enabled = true
		mat.rim = rim
		mat.rim_tint = rim_tint
	return mat

func _create_mesh_part(p_mesh: Mesh, p_mat: Material, p_pos: Vector3, p_rot: Vector3 = Vector3.ZERO, p_scale: Vector3 = Vector3.ONE, p_name: String = "") -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	if p_name != "":
		inst.name = p_name
	inst.mesh = p_mesh
	inst.material_override = p_mat
	inst.position = p_pos
	inst.rotation = p_rot
	inst.scale = p_scale
	return inst

func _process(delta: float) -> void:
	if combat_assist_cooldown > 0.0:
		combat_assist_cooldown = maxf(0.0, combat_assist_cooldown - delta)

	_update_procedural_idle(delta)

	if current_state == State.FOLLOWING_PLAYER and following_target and is_inside_tree():
		var target_pos = following_target.global_position
		var current_pos = global_position
		var dist = current_pos.distance_to(target_pos)
		if dist > stop_distance:
			var dir = (target_pos - current_pos).normalized()
			dir.y = 0.0
			velocity = dir * follow_speed
			move_and_slide()
		else:
			velocity = Vector3.ZERO

## Procedural idle animation: calm breathing bob, scarf tail sway, and stoic observational head tracking toward Echo
func _update_procedural_idle(delta: float) -> void:
	if not _avatar_root or not is_instance_valid(_avatar_root):
		return

	_idle_time += delta

	# 1. Subtle calm breathing bob (steady vertical oscillation & slight chest expansion)
	var breath: float = sin(_idle_time * 2.1)
	if _breathing_pivot and is_instance_valid(_breathing_pivot):
		_breathing_pivot.position.y = _breathing_base_y + breath * 0.007
		_breathing_pivot.scale = Vector3(1.0 + breath * 0.010, 1.0 + breath * 0.006, 1.0 + breath * 0.012)

	# 2. Ice blue & lavender scarf tail ambient sway
	if _scarf_tail and is_instance_valid(_scarf_tail):
		var scarf_sway_z := sin(_idle_time * 1.8) * 0.08
		var scarf_sway_x := cos(_idle_time * 1.3) * 0.05
		_scarf_tail.rotation.z = scarf_sway_z
		_scarf_tail.rotation.x = deg_to_rad(14.0) + scarf_sway_x

	# 3. Head tracking & stoic observational gaze toward Echo
	if _head_pivot and is_instance_valid(_head_pivot):
		var target_yaw: float = 0.0
		var target_pitch: float = sin(_idle_time * 0.6) * 0.012
		var target_roll: float = 0.0

		var echo_node: Node3D = _find_echo_target()
		if echo_node and is_inside_tree():
			var to_echo := echo_node.global_position - global_position
			var dist := to_echo.length()
			if dist < 5.5 and dist > 0.1:
				var local_dir: Vector3 = global_transform.basis.inverse() * (echo_node.global_position + Vector3(0, 1.45, 0) - _head_pivot.global_position).normalized()
				var yaw := atan2(-local_dir.x, -local_dir.z)
				var dist_xz := sqrt(local_dir.x * local_dir.x + local_dir.z * local_dir.z)
				var pitch := atan2(local_dir.y, dist_xz)

				if cos(yaw) > 0.2:
					target_yaw = clampf(yaw, -deg_to_rad(50.0), deg_to_rad(50.0))
					target_pitch = clampf(pitch, -deg_to_rad(22.0), deg_to_rad(22.0))
					# Stoic posture: sharp, attentive gaze without excessive tilt
					target_roll = sin(_idle_time * 1.2) * 0.01
				else:
					target_yaw = cos(_idle_time * 0.45) * 0.02
			else:
				target_yaw = cos(_idle_time * 0.45) * 0.02
		else:
			target_yaw = cos(_idle_time * 0.45) * 0.02

		_head_pivot.rotation.y = lerp_angle(_head_pivot.rotation.y, target_yaw, delta * 3.8)
		_head_pivot.rotation.x = lerp_angle(_head_pivot.rotation.x, target_pitch, delta * 3.8)
		_head_pivot.rotation.z = lerp_angle(_head_pivot.rotation.z, target_roll, delta * 3.0)

## Finds Echo / player node in scene tree safely
func _find_echo_target() -> Node3D:
	if following_target and is_instance_valid(following_target):
		return following_target
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			var player_nodes := tree.get_nodes_in_group("player")
			if not player_nodes.is_empty() and player_nodes[0] is Node3D and is_instance_valid(player_nodes[0]):
				return player_nodes[0] as Node3D
			var root: Node = tree.current_scene if tree.current_scene else tree.root
			if root:
				var echo := root.find_child("EchoPlayer", true, false) as Node3D
				if echo and is_instance_valid(echo):
					return echo
				var p := root.find_child("Player", true, false) as Node3D
				if p and is_instance_valid(p):
					return p
	return null

## Resets Yuki to her authored desk position in Class 2-B
func sit_at_desk() -> void:
	current_state = State.CLASSROOM_IDLE
	position = DESK_POSITION
	following_target = null
	emit_signal("state_changed", current_state)

## Commands Yuki to follow player across campus or through Minato-Kasumi alleys
func start_following(target: Node3D) -> Dictionary:
	following_target = target
	current_state = State.FOLLOWING_PLAYER
	emit_signal("state_changed", current_state)
	return {
		"success": true,
		"state": "FOLLOWING_PLAYER",
		"target": target.name if target else "Unknown"
	}

## Disengages follow mode
func stop_following() -> Dictionary:
	following_target = null
	current_state = State.CLASSROOM_IDLE
	emit_signal("state_changed", current_state)
	return {
		"success": true,
		"state": "CLASSROOM_IDLE"
	}

## Executes Yuki's signature tactical Cryo assist strike ("Glacial Severance")
func execute_combat_assist(target: Node, bond_manager: CompanionBondManagerScript = null) -> Dictionary:
	if combat_assist_cooldown > 0.0:
		return {
			"success": false,
			"error": "Combat assist on cooldown",
			"remaining_cooldown": combat_assist_cooldown
		}

	var has_glacial_vanguard: bool = false
	var has_polar_resonance: bool = false
	if bond_manager:
		has_glacial_vanguard = bond_manager.has_perk("YUKI", "Glacial Vanguard")
		has_polar_resonance = bond_manager.has_perk("YUKI", "Polar Resonance")

	# Damage calculation
	var damage: float = base_assist_damage
	var cooldown_duration: float = 5.0
	if has_glacial_vanguard:
		damage *= 1.25 # +25% Glacial Vanguard boost
		cooldown_duration *= 0.8 # -20% cooldown

	combat_assist_cooldown = cooldown_duration

	var slow_duration: float = 3.0
	if has_polar_resonance:
		slow_duration += 1.5

	# Inflict damage on target
	if target:
		if target.has_method("take_damage"):
			target.take_damage(damage)
		elif "hp" in target:
			target.hp = maxf(0.0, target.hp - damage)
		elif target.has_meta("hp"):
			target.set_meta("hp", maxf(0.0, float(target.get_meta("hp")) - damage))

		if target.has_method("apply_frost_slow"):
			target.apply_frost_slow(0.40, slow_duration)
		elif "speed_multiplier" in target:
			target.speed_multiplier = 0.60

	# Play audio if in scene tree
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_energy_blade_draw_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("combat_assist_triggered", target, damage, has_glacial_vanguard)

	return {
		"success": true,
		"skill_name": "Glacial Severance",
		"damage": damage,
		"element": "CYAN_CRYO",
		"target_name": target.name if target else "Dummy",
		"slow_duration": slow_duration,
		"glacial_vanguard_active": has_glacial_vanguard,
		"cooldown_applied": combat_assist_cooldown
	}

## Context-rich dialogue lines adapting to social bond rank
func talk(bond_manager: CompanionBondManagerScript = null) -> Dictionary:
	var bond_tier: int = 1
	if bond_manager:
		bond_tier = bond_manager.get_bond_level("YUKI")

	var line: String = ""
	if bond_tier <= 2:
		line = "Echo. Don't stare out the window too long. Kinga's observers aren't the only ones watching us."
	elif bond_tier <= 5:
		line = "Your movements in combat are sharpening, Echo. When the time comes to strike back, I'm behind you."
	else:
		line = "I swore an oath. No matter what shadow Monarch singularity tries to pull you into the dark, I will stand between you and the abyss."

	emit_signal("dialogue_spoken", character_name, line)
	return {
		"character": character_name,
		"bond_tier": bond_tier,
		"dialogue": line
	}

## Freeform dynamic conversational interaction powered by DynamicAIDialogueEngine
func chat_freeform(query: String, engine: DynamicAIDialogueEngineScript = null, context_data: Dictionary = {}) -> Dictionary:
	if not engine:
		engine = DynamicAIDialogueEngineScript.new()
	var res = engine.generate_response("YUKI", query, context_data)
	emit_signal("dialogue_spoken", character_name, res.get("text", ""))
	return res
