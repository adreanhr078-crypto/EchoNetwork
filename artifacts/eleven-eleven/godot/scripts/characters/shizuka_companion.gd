class_name ShizukaCompanion
extends CharacterBody3D

## AAA Narrative Companion: Shizuka (Class 2-B Emotional Anchor)
## Sits directly in front of Echo in Class 2-B (Row 3, Window).
## Provides:
## - Empathetic emotional support & psychological trauma counseling
## - Sharing homemade bento boxes (+100 Hunger, +50 HP, plays bento open SFX)
## - Suppresses Echo's Reality Glitches and restores sanity
## - Synergizes with CompanionBondManager (Tier 3 Handmade Bento & Tier 5 Psychological Anchor)
## - Styled anime humanoid avatar with warm apricot/crimson accents & bento prop
## - Procedural idle breathing bob & empathetic head tilt toward Echo

signal state_changed(new_state: int)
signal dialogue_spoken(speaker: String, text: String)
signal bento_shared(player: Node, meal_data: Dictionary)
signal trauma_counseled(player: Node, sanity_restored: float, glitch_suppressed: float)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const CompanionBondManagerScript = preload("res://scripts/systems/companion_bond_manager.gd")
const DynamicAIDialogueEngineScript = preload("res://scripts/systems/dynamic_ai_dialogue_engine.gd")

enum State {
	CLASSROOM_IDLE,
	ROOFTOP_LUNCH,
	FOLLOWING_PLAYER,
	RESTING
}

const DESK_POSITION: Vector3 = Vector3(-4.5, 3.8, 4.2)

@export var character_id: String = "SHIZUKA"
@export var character_name: String = "Shizuka"
@export var role: String = "Class 2-B Student / Emotional Anchor"
@export var current_state: State = State.CLASSROOM_IDLE

var following_target: Node3D = null
var bento_share_count: int = 0
var counseling_count: int = 0
var follow_speed: float = 3.8
var stop_distance: float = 2.0

# Visual Avatar & Procedural Animation Nodes
var _avatar_root: Node3D = null
var _breathing_pivot: Node3D = null
var _head_pivot: Node3D = null
var _bento_prop: Node3D = null
var _idle_time: float = 0.0
var _breathing_base_y: float = 0.82
var _bento_base_y: float = 0.10

func _init() -> void:
	position = DESK_POSITION

func _ready() -> void:
	_setup_visual_avatar()
	sit_at_desk()

func _setup_visual_avatar() -> void:
	var avatar = find_child("ShizukaAvatarMesh", true, false)
	if avatar:
		_avatar_root = avatar as Node3D
		_breathing_pivot = _avatar_root.find_child("BreathingPivot", true, false) as Node3D
		_head_pivot = _avatar_root.find_child("HeadPivot", true, false) as Node3D
		_bento_prop = _avatar_root.find_child("BentoBoxProp", true, false) as Node3D
		return

	_build_styled_humanoid_avatar()

## Builds a high-craft stylized anime humanoid avatar for Shizuka
## Warm apricot & crimson ribbons, cream knit cardigan, apron accents, and bento box prop
func _build_styled_humanoid_avatar() -> void:
	var avatar_root := MeshInstance3D.new()
	avatar_root.name = "ShizukaAvatarMesh"
	avatar_root.position = Vector3(0, 0, 0)
	_avatar_root = avatar_root
	add_child(avatar_root)

	# --- Materials Palette ---
	# Soft warm anime skin with subtle peach rim
	var mat_skin := _create_mat(Color(0.98, 0.90, 0.84), 0.82, 0.0, Color.BLACK, 0.0, 0.25, 0.5)
	# Warm chestnut hair with soft amber rim
	var mat_hair := _create_mat(Color(0.44, 0.25, 0.16), 0.60, 0.0, Color.BLACK, 0.0, 0.35, 0.4)
	# Minato Academy cream knit cardigan
	var mat_cardigan := _create_mat(Color(0.93, 0.85, 0.74), 0.80)
	# Crisp white uniform shirt / collar
	var mat_white_shirt := _create_mat(Color(0.96, 0.96, 0.98), 0.70)
	# Warm apricot apron accents & ties
	var mat_apron := _create_mat(Color(0.98, 0.72, 0.58), 0.75, 0.0, Color(0.98, 0.72, 0.58), 0.10)
	# Vibrant crimson satin ribbon with subtle luminescence
	var mat_crimson_ribbon := _create_mat(Color(0.85, 0.12, 0.22), 0.40, 0.0, Color(0.85, 0.12, 0.22), 0.20)
	# Warm peach / apricot hairpin
	var mat_hairpin := _create_mat(Color(1.0, 0.70, 0.52), 0.30, 0.0, Color(1.0, 0.70, 0.52), 0.30)
	# Minato Academy charcoal uniform pleated skirt
	var mat_skirt := _create_mat(Color(0.28, 0.22, 0.26), 0.75)
	# Clean white school socks
	var mat_socks := _create_mat(Color(0.95, 0.95, 0.96), 0.80)
	# Brown leather school loafers
	var mat_loafers := _create_mat(Color(0.24, 0.16, 0.12), 0.35)
	# Expressive amber/hazel anime eyes
	var mat_eyes := _create_mat(Color(0.88, 0.52, 0.18), 0.20, 0.0, Color(0.88, 0.52, 0.18), 0.35)
	# Soft cheek blush
	var mat_blush := _create_mat(Color(1.0, 0.62, 0.65, 0.7), 0.90, 0.0, Color(1.0, 0.55, 0.60), 0.25)
	# Bento box: Cinnabar lacquer
	var mat_bento_box := _create_mat(Color(0.72, 0.14, 0.14), 0.30, 0.0, Color(0.72, 0.14, 0.14), 0.15)
	# Bento box: Black lacquer trim / lid
	var mat_bento_black := _create_mat(Color(0.12, 0.12, 0.14), 0.25)
	# Furoshiki wrapping cloth knot (warm peach)
	var mat_furoshiki := _create_mat(Color(0.98, 0.76, 0.58), 0.70)
	# Natural bamboo chopstick case
	var mat_chopsticks := _create_mat(Color(0.85, 0.75, 0.56), 0.60)

	# --- Hierarchy Structure ---
	var body_root := Node3D.new()
	body_root.name = "BodyRoot"
	avatar_root.add_child(body_root)

	# 1. Lower Body (Legs & Shoes)
	var legs_node := Node3D.new()
	legs_node.name = "LegsNode"
	body_root.add_child(legs_node)

	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.055
	leg_mesh.height = 0.44
	var leg_l := _create_mesh_part(leg_mesh, mat_socks, Vector3(-0.09, 0.36, 0.0), Vector3.ZERO, Vector3.ONE, "LegLeft")
	var leg_r := _create_mesh_part(leg_mesh, mat_socks, Vector3(0.09, 0.36, 0.0), Vector3.ZERO, Vector3.ONE, "LegRight")
	legs_node.add_child(leg_l)
	legs_node.add_child(leg_r)

	var shoe_mesh := BoxMesh.new()
	shoe_mesh.size = Vector3(0.095, 0.07, 0.17)
	var shoe_l := _create_mesh_part(shoe_mesh, mat_loafers, Vector3(-0.09, 0.04, -0.02), Vector3.ZERO, Vector3.ONE, "ShoeLeft")
	var shoe_r := _create_mesh_part(shoe_mesh, mat_loafers, Vector3(0.09, 0.04, -0.02), Vector3.ZERO, Vector3.ONE, "ShoeRight")
	legs_node.add_child(shoe_l)
	legs_node.add_child(shoe_r)

	# 2. Hips & Skirt
	var hips_node := Node3D.new()
	hips_node.name = "HipsNode"
	hips_node.position = Vector3(0, 0.72, 0)
	body_root.add_child(hips_node)

	var skirt_mesh := CylinderMesh.new()
	skirt_mesh.top_radius = 0.18
	skirt_mesh.bottom_radius = 0.27
	skirt_mesh.height = 0.26
	var skirt := _create_mesh_part(skirt_mesh, mat_skirt, Vector3(0, -0.04, 0), Vector3.ZERO, Vector3.ONE, "SkirtMesh")
	hips_node.add_child(skirt)

	var apron_sash_mesh := CylinderMesh.new()
	apron_sash_mesh.top_radius = 0.17
	apron_sash_mesh.bottom_radius = 0.19
	apron_sash_mesh.height = 0.06
	var apron_sash := _create_mesh_part(apron_sash_mesh, mat_apron, Vector3(0, 0.08, 0), Vector3.ZERO, Vector3.ONE, "ApronSash")
	hips_node.add_child(apron_sash)

	var apron_skirt_mesh := BoxMesh.new()
	apron_skirt_mesh.size = Vector3(0.20, 0.22, 0.02)
	var apron_skirt := _create_mesh_part(apron_skirt_mesh, mat_apron, Vector3(0, -0.04, -0.15), Vector3.ZERO, Vector3.ONE, "ApronSkirtFront")
	hips_node.add_child(apron_skirt)

	# 3. Breathing Pivot (Torso + Upper Body + Arms + Head)
	var breathing_pivot := Node3D.new()
	breathing_pivot.name = "BreathingPivot"
	breathing_pivot.position = Vector3(0, _breathing_base_y, 0)
	_breathing_pivot = breathing_pivot
	body_root.add_child(breathing_pivot)

	# Torso & Cardigan
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.16
	torso_mesh.height = 0.40
	var torso := _create_mesh_part(torso_mesh, mat_cardigan, Vector3(0, 0.20, 0), Vector3.ZERO, Vector3.ONE, "TorsoMesh")
	breathing_pivot.add_child(torso)

	# Blouse Sailor Collar
	var collar_mesh := BoxMesh.new()
	collar_mesh.size = Vector3(0.28, 0.04, 0.22)
	var collar := _create_mesh_part(collar_mesh, mat_white_shirt, Vector3(0, 0.38, 0.02), Vector3.ZERO, Vector3.ONE, "CollarMesh")
	breathing_pivot.add_child(collar)

	# Apron Bib & Front Pocket
	var apron_bib_mesh := BoxMesh.new()
	apron_bib_mesh.size = Vector3(0.22, 0.25, 0.03)
	var apron_bib := _create_mesh_part(apron_bib_mesh, mat_apron, Vector3(0, 0.19, -0.15), Vector3.ZERO, Vector3.ONE, "ApronBib")
	breathing_pivot.add_child(apron_bib)

	var apron_pocket_mesh := BoxMesh.new()
	apron_pocket_mesh.size = Vector3(0.14, 0.08, 0.02)
	var apron_pocket := _create_mesh_part(apron_pocket_mesh, mat_apron, Vector3(0, 0.12, -0.165), Vector3.ZERO, Vector3.ONE, "ApronPocket")
	breathing_pivot.add_child(apron_pocket)

	# Crimson Chest Ribbon & Tails
	var ribbon_knot_mesh := BoxMesh.new()
	ribbon_knot_mesh.size = Vector3(0.08, 0.07, 0.03)
	var ribbon_knot := _create_mesh_part(ribbon_knot_mesh, mat_crimson_ribbon, Vector3(0, 0.33, -0.16), Vector3.ZERO, Vector3.ONE, "ChestRibbonKnot")
	breathing_pivot.add_child(ribbon_knot)

	var ribbon_tail_mesh := BoxMesh.new()
	ribbon_tail_mesh.size = Vector3(0.03, 0.09, 0.015)
	var ribbon_tail_l := _create_mesh_part(ribbon_tail_mesh, mat_crimson_ribbon, Vector3(-0.03, 0.26, -0.165), Vector3(0, 0, deg_to_rad(-16.0)), Vector3.ONE, "RibbonTailL")
	var ribbon_tail_r := _create_mesh_part(ribbon_tail_mesh, mat_crimson_ribbon, Vector3(0.03, 0.26, -0.165), Vector3(0, 0, deg_to_rad(16.0)), Vector3.ONE, "RibbonTailR")
	breathing_pivot.add_child(ribbon_tail_l)
	breathing_pivot.add_child(ribbon_tail_r)

	# Arms gently holding the Bento Box
	var upper_arm_mesh := CapsuleMesh.new()
	upper_arm_mesh.radius = 0.052
	upper_arm_mesh.height = 0.24
	var arm_l := _create_mesh_part(upper_arm_mesh, mat_cardigan, Vector3(-0.18, 0.22, -0.07), Vector3(deg_to_rad(40.0), deg_to_rad(18.0), deg_to_rad(-8.0)), Vector3.ONE, "ArmLeft")
	var arm_r := _create_mesh_part(upper_arm_mesh, mat_cardigan, Vector3(0.18, 0.22, -0.07), Vector3(deg_to_rad(40.0), deg_to_rad(-18.0), deg_to_rad(8.0)), Vector3.ONE, "ArmRight")
	breathing_pivot.add_child(arm_l)
	breathing_pivot.add_child(arm_r)

	var forearm_mesh := CapsuleMesh.new()
	forearm_mesh.radius = 0.046
	forearm_mesh.height = 0.20
	var forearm_l := _create_mesh_part(forearm_mesh, mat_cardigan, Vector3(-0.11, 0.12, -0.18), Vector3(deg_to_rad(75.0), deg_to_rad(32.0), 0), Vector3.ONE, "ForearmLeft")
	var forearm_r := _create_mesh_part(forearm_mesh, mat_cardigan, Vector3(0.11, 0.12, -0.18), Vector3(deg_to_rad(75.0), deg_to_rad(-32.0), 0), Vector3.ONE, "ForearmRight")
	breathing_pivot.add_child(forearm_l)
	breathing_pivot.add_child(forearm_r)

	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.038
	hand_mesh.height = 0.06
	var hand_l := _create_mesh_part(hand_mesh, mat_skin, Vector3(-0.08, 0.10, -0.25), Vector3.ZERO, Vector3.ONE, "HandLeft")
	var hand_r := _create_mesh_part(hand_mesh, mat_skin, Vector3(0.08, 0.10, -0.25), Vector3.ZERO, Vector3.ONE, "HandRight")
	breathing_pivot.add_child(hand_l)
	breathing_pivot.add_child(hand_r)

	# --- 4. Bento Box Prop ---
	var bento_prop := Node3D.new()
	bento_prop.name = "BentoBoxProp"
	bento_prop.position = Vector3(0, _bento_base_y, -0.26)
	_bento_prop = bento_prop
	breathing_pivot.add_child(bento_prop)

	# Tiered lacquered bento box base
	var bento_box_mesh := BoxMesh.new()
	bento_box_mesh.size = Vector3(0.16, 0.07, 0.12)
	var bento_box := _create_mesh_part(bento_box_mesh, mat_bento_box, Vector3(0, 0, 0), Vector3.ZERO, Vector3.ONE, "BentoBase")
	bento_prop.add_child(bento_box)

	# Polished black lid
	var bento_lid_mesh := BoxMesh.new()
	bento_lid_mesh.size = Vector3(0.165, 0.02, 0.125)
	var bento_lid := _create_mesh_part(bento_lid_mesh, mat_bento_black, Vector3(0, 0.042, 0), Vector3.ZERO, Vector3.ONE, "BentoLid")
	bento_prop.add_child(bento_lid)

	# Furoshiki wrapping cloth knot
	var furoshiki_knot_mesh := SphereMesh.new()
	furoshiki_knot_mesh.radius = 0.028
	furoshiki_knot_mesh.height = 0.038
	var furoshiki_knot := _create_mesh_part(furoshiki_knot_mesh, mat_furoshiki, Vector3(0, 0.062, 0), Vector3.ZERO, Vector3.ONE, "FuroshikiKnot")
	bento_prop.add_child(furoshiki_knot)

	# Natural bamboo chopstick case tucked on side
	var chopsticks_mesh := BoxMesh.new()
	chopsticks_mesh.size = Vector3(0.15, 0.016, 0.02)
	var chopsticks := _create_mesh_part(chopsticks_mesh, mat_chopsticks, Vector3(0, 0.052, -0.065), Vector3.ZERO, Vector3.ONE, "ChopstickCase")
	bento_prop.add_child(chopsticks)

	# --- 5. Neck & Head Pivot ---
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.05
	neck_mesh.bottom_radius = 0.052
	neck_mesh.height = 0.10
	var neck := _create_mesh_part(neck_mesh, mat_skin, Vector3(0, 0.44, 0), Vector3.ZERO, Vector3.ONE, "NeckMesh")
	breathing_pivot.add_child(neck)

	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0, 0.52, 0)
	_head_pivot = head_pivot
	breathing_pivot.add_child(head_pivot)

	# Stylized anime head & jawline
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.14
	head_mesh.height = 0.28
	var head := _create_mesh_part(head_mesh, mat_skin, Vector3(0, 0, 0), Vector3.ZERO, Vector3.ONE, "HeadMesh")
	head_pivot.add_child(head)

	var face_jaw_mesh := CapsuleMesh.new()
	face_jaw_mesh.radius = 0.11
	face_jaw_mesh.height = 0.22
	var face_jaw := _create_mesh_part(face_jaw_mesh, mat_skin, Vector3(0, -0.035, -0.04), Vector3.ZERO, Vector3.ONE, "FaceJawMesh")
	head_pivot.add_child(face_jaw)

	# Warm amber anime eyes
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.024
	eye_mesh.height = 0.032
	var eye_l := _create_mesh_part(eye_mesh, mat_eyes, Vector3(-0.052, 0.012, -0.125), Vector3.ZERO, Vector3(1, 1.35, 0.3), "EyeLeft")
	var eye_r := _create_mesh_part(eye_mesh, mat_eyes, Vector3(0.052, 0.012, -0.125), Vector3.ZERO, Vector3(1, 1.35, 0.3), "EyeRight")
	head_pivot.add_child(eye_l)
	head_pivot.add_child(eye_r)

	# Soft cheek blush accents
	var blush_mesh := SphereMesh.new()
	blush_mesh.radius = 0.022
	blush_mesh.height = 0.015
	var blush_l := _create_mesh_part(blush_mesh, mat_blush, Vector3(-0.065, -0.032, -0.115), Vector3.ZERO, Vector3.ONE, "BlushLeft")
	var blush_r := _create_mesh_part(blush_mesh, mat_blush, Vector3(0.065, -0.032, -0.115), Vector3.ZERO, Vector3.ONE, "BlushRight")
	head_pivot.add_child(blush_l)
	head_pivot.add_child(blush_r)

	# Hair: Back bob
	var hair_back_mesh := SphereMesh.new()
	hair_back_mesh.radius = 0.16
	hair_back_mesh.height = 0.32
	var hair_back := _create_mesh_part(hair_back_mesh, mat_hair, Vector3(0, 0.02, 0.04), Vector3.ZERO, Vector3(1.05, 1.15, 1.05), "HairBack")
	head_pivot.add_child(hair_back)

	# Hair: Front bangs fringe
	var bangs_mesh := CapsuleMesh.new()
	bangs_mesh.radius = 0.038
	bangs_mesh.height = 0.22
	var bangs := _create_mesh_part(bangs_mesh, mat_hair, Vector3(0, 0.085, -0.11), Vector3(deg_to_rad(22.0), 0, deg_to_rad(90.0)), Vector3.ONE, "HairBangs")
	head_pivot.add_child(bangs)

	# Hair: Side locks framing face
	var sidelock_mesh := CapsuleMesh.new()
	sidelock_mesh.radius = 0.032
	sidelock_mesh.height = 0.26
	var sidelock_l := _create_mesh_part(sidelock_mesh, mat_hair, Vector3(-0.135, -0.06, -0.04), Vector3(0, 0, deg_to_rad(-6.0)), Vector3.ONE, "HairSideLockL")
	var sidelock_r := _create_mesh_part(sidelock_mesh, mat_hair, Vector3(0.135, -0.06, -0.04), Vector3(0, 0, deg_to_rad(6.0)), Vector3.ONE, "HairSideLockR")
	head_pivot.add_child(sidelock_l)
	head_pivot.add_child(sidelock_r)

	# Accessory 1: Warm apricot/peach hairpin
	var hairpin_mesh := BoxMesh.new()
	hairpin_mesh.size = Vector3(0.015, 0.04, 0.02)
	var hairpin := _create_mesh_part(hairpin_mesh, mat_hairpin, Vector3(-0.125, 0.09, -0.09), Vector3(0, deg_to_rad(15.0), deg_to_rad(-25.0)), Vector3.ONE, "HairpinMesh")
	head_pivot.add_child(hairpin)

	# Accessory 2: Crimson satin hair ribbon
	var hair_ribbon_mesh := BoxMesh.new()
	hair_ribbon_mesh.size = Vector3(0.032, 0.032, 0.016)
	var hair_ribbon := _create_mesh_part(hair_ribbon_mesh, mat_crimson_ribbon, Vector3(0.13, 0.05, -0.07), Vector3(0, deg_to_rad(-18.0), deg_to_rad(20.0)), Vector3.ONE, "CrimsonHairRibbon")
	head_pivot.add_child(hair_ribbon)

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

## Procedural idle animation: breathing bob, bento motion, and empathetic head tilt toward Echo
func _update_procedural_idle(delta: float) -> void:
	if not _avatar_root or not is_instance_valid(_avatar_root):
		return

	_idle_time += delta

	# 1. Subtle breathing bob (gentle vertical oscillation & chest expansion)
	var breath: float = sin(_idle_time * 2.3)
	if _breathing_pivot and is_instance_valid(_breathing_pivot):
		_breathing_pivot.position.y = _breathing_base_y + breath * 0.008
		_breathing_pivot.scale = Vector3(1.0 + breath * 0.012, 1.0 + breath * 0.008, 1.0 + breath * 0.015)

	# 2. Bento box gentle breath bobbing in hands
	if _bento_prop and is_instance_valid(_bento_prop):
		_bento_prop.position.y = _bento_base_y + breath * 0.004

	# 3. Head tracking & empathetic tilt toward Echo when nearby
	if _head_pivot and is_instance_valid(_head_pivot):
		var target_yaw: float = 0.0
		var target_pitch: float = sin(_idle_time * 0.7) * 0.015
		var target_roll: float = 0.0

		var echo_node: Node3D = _find_echo_target()
		if echo_node and is_inside_tree():
			var to_echo := echo_node.global_position - global_position
			var dist := to_echo.length()
			if dist < 5.5 and dist > 0.1:
				# Echo is nearby! Transform to local companion space
				var local_dir: Vector3 = global_transform.basis.inverse() * (echo_node.global_position + Vector3(0, 1.45, 0) - _head_pivot.global_position).normalized()
				var yaw := atan2(-local_dir.x, -local_dir.z)
				var dist_xz := sqrt(local_dir.x * local_dir.x + local_dir.z * local_dir.z)
				var pitch := atan2(local_dir.y, dist_xz)

				# Clamp head rotation within natural human limits
				if cos(yaw) > 0.2:
					target_yaw = clampf(yaw, -deg_to_rad(55.0), deg_to_rad(55.0))
					target_pitch = clampf(pitch, -deg_to_rad(25.0), deg_to_rad(25.0))
					# Empathetic warm head tilt toward Echo (listening/caring posture)
					target_roll = clampf(target_yaw * 0.12, -0.07, 0.07) + sin(_idle_time * 1.4) * 0.02
				else:
					target_yaw = cos(_idle_time * 0.5) * 0.03
			else:
				target_yaw = cos(_idle_time * 0.5) * 0.025
		else:
			target_yaw = cos(_idle_time * 0.5) * 0.025

		_head_pivot.rotation.y = lerp_angle(_head_pivot.rotation.y, target_yaw, delta * 3.5)
		_head_pivot.rotation.x = lerp_angle(_head_pivot.rotation.x, target_pitch, delta * 3.5)
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

## Resets Shizuka to her authored desk position in Class 2-B
func sit_at_desk() -> void:
	current_state = State.CLASSROOM_IDLE
	position = DESK_POSITION
	following_target = null
	emit_signal("state_changed", current_state)

## Move to school rooftop for lunchtime bento sharing
func go_to_rooftop_lunch() -> void:
	current_state = State.ROOFTOP_LUNCH
	position = Vector3(0.0, 8.5, -6.5)
	emit_signal("state_changed", current_state)

## Starts following player
func start_following(target: Node3D) -> Dictionary:
	following_target = target
	current_state = State.FOLLOWING_PLAYER
	emit_signal("state_changed", current_state)
	return {
		"success": true,
		"state": "FOLLOWING_PLAYER",
		"target": target.name if target else "Unknown"
	}

## Stops following player
func stop_following() -> Dictionary:
	following_target = null
	current_state = State.CLASSROOM_IDLE
	emit_signal("state_changed", current_state)
	return {
		"success": true,
		"state": "CLASSROOM_IDLE"
	}

## Shares a lovingly prepared Japanese Bento Box with Echo
func share_homemade_bento(player: Node, bond_manager: CompanionBondManagerScript = null) -> Dictionary:
	bento_share_count += 1

	var has_handmade_bento_perk: bool = false
	if bond_manager:
		has_handmade_bento_perk = bond_manager.has_perk("SHIZUKA", "Handmade Bento")

	var hunger_restore: float = 100.0
	var hp_heal: float = 50.0
	var energy_restore: float = 30.0

	if has_handmade_bento_perk:
		hunger_restore = 150.0
		hp_heal = 75.0
		energy_restore = 45.0

	# Apply benefits to player
	if player:
		if "needs" in player and player.needs != null:
			if "hunger" in player.needs:
				player.needs.hunger = minf(100.0, player.needs.hunger + hunger_restore)
			if "energy" in player.needs:
				player.needs.energy = minf(100.0, player.needs.energy + energy_restore)

		if "hp" in player:
			player.hp = minf(200.0, player.hp + hp_heal)
			if player.has_signal("hp_changed"):
				player.emit_signal("hp_changed", player.hp, 200.0)
		elif player.has_meta("hp"):
			player.set_meta("hp", minf(200.0, float(player.get_meta("hp")) + hp_heal))

	# Play bento box opening SFX
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_bento_box_open_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	var meal_info: Dictionary = {
		"meal_name": "Shizuka's Special Tamagoyaki & Karaage Bento",
		"hunger_restored": hunger_restore,
		"hp_healed": hp_heal,
		"energy_restored": energy_restore,
		"perk_active": has_handmade_bento_perk,
		"share_count": bento_share_count
	}

	emit_signal("bento_shared", player, meal_info)
	return {
		"success": true,
		"meal": meal_info["meal_name"],
		"hunger_restored": hunger_restore,
		"hp_healed": hp_heal,
		"energy_restored": energy_restore,
		"dialogue": "Here, Echo! I made extra rolled omelette and sweet karaage today. Make sure you eat every bite!"
	}

## Provides psychological counseling to calm Echo's reality glitch and mental trauma
func provide_trauma_counseling(player: Node, bond_manager: CompanionBondManagerScript = null) -> Dictionary:
	counseling_count += 1

	var has_psych_anchor: bool = false
	if bond_manager:
		has_psych_anchor = bond_manager.has_perk("SHIZUKA", "Psychological Anchor")

	var sanity_boost: float = 40.0
	var glitch_reduction: float = 50.0

	if has_psych_anchor:
		sanity_boost = 60.0
		glitch_reduction = 75.0

	if player:
		if "sanity" in player:
			player.sanity = minf(100.0, player.sanity + sanity_boost)
		elif player.has_meta("sanity"):
			player.set_meta("sanity", minf(100.0, float(player.get_meta("sanity")) + sanity_boost))

		if "glitch_meter" in player:
			player.glitch_meter = maxf(0.0, player.glitch_meter - glitch_reduction)
		if "reality_glitch" in player:
			player.reality_glitch = maxf(0.0, player.reality_glitch - glitch_reduction)
		elif player.has_meta("reality_glitch"):
			player.set_meta("reality_glitch", maxf(0.0, float(player.get_meta("reality_glitch")) - glitch_reduction))

	emit_signal("trauma_counseled", player, sanity_boost, glitch_reduction)

	return {
		"success": true,
		"sanity_restored": sanity_boost,
		"glitch_suppressed": glitch_reduction,
		"psychological_anchor_active": has_psych_anchor,
		"counseling_count": counseling_count,
		"dialogue": "Take a deep breath, Echo. You're right here with me. Listen to the ocean wind. Ground yourself."
	}

## Context-rich empathetic dialogue lines adapting to social bond rank
func talk(bond_manager: CompanionBondManagerScript = null) -> Dictionary:
	var bond_tier: int = 1
	if bond_manager:
		bond_tier = bond_manager.get_bond_level("SHIZUKA")

	var line: String = ""
	if bond_tier <= 2:
		line = "Morning, Echo! Did you sleep okay? You looked a little exhausted when you walked into class."
	elif bond_tier <= 5:
		line = "Whenever the world starts feeling like cold numbers and static, just look at me. I'll always pull you back."
	else:
		line = "You don't have to carry the burden of the cataclysm alone, Echo. No matter what happens, you will always have a place to come home to."

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
	var res = engine.generate_response("SHIZUKA", query, context_data)
	emit_signal("dialogue_spoken", character_name, res.get("text", ""))
	return res
