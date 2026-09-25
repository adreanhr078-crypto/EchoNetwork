class_name InteractiveTreasureChest
extends Node3D

## Minato-Kasumi Tiered Interactive Treasure Chest (宝箱)
## Inspired by Genshin Impact / ZZZ discovery and exploration feedback loops.
## Features distinct 3D visual tier models (Common, Exquisite, Precious, Luxurious),
## smooth lid opening kinematics via Tween, interior radiant volumetric glow,
## unlatch + crystal harmonic sound synthesis, Yen economy rewards, and single-open persistence.

enum ChestRarity {
	COMMON,      # Ordinary wooden crate with iron bands // 普通の宝箱
	EXQUISITE,   # Polished azure-lacquered steel // 精巧な宝箱
	PRECIOUS,    # Gilded gold with crimson velvet // 貴重な宝箱
	LUXURIOUS    # Imperial obsidian, aurum trim and amethyst crystal // 豪華な宝箱
}

signal chest_opened(chest_id: String, rarity: int, yen_reward: int, items_reward: Array)
signal chest_interacted(interactor: Node3D)

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")
const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const EconomyManager = preload("res://scripts/systems/economy_manager.gd")
const PlayerInventory = preload("res://scripts/systems/player_inventory.gd")

@export var chest_id: String = "Chest_01"
@export var rarity: ChestRarity = ChestRarity.COMMON
@export var is_opened: bool = false
@export var custom_yen: int = -1
@export var custom_loot: Array[String] = []

var lid_pivot: Node3D = null
var chest_glow: OmniLight3D = null
var audio_player: AudioStreamPlayer3D = null
var interactable: InteractableComponent = null
var is_animating: bool = false

func _ready() -> void:
	ensure_setup()

func ensure_setup() -> void:
	_setup_visual_elements()
	_setup_interactable()
	_setup_audio()
	if is_opened and lid_pivot:
		lid_pivot.rotation.x = -deg_to_rad(80.0)
		if chest_glow:
			chest_glow.light_energy = 0.5
		if interactable:
			interactable.is_enabled = false
			interactable.prompt_target_name = get_chest_name() + " (Opened)"

func get_chest_name() -> String:
	match rarity:
		ChestRarity.COMMON:
			return "Common Chest // 普通の宝箱"
		ChestRarity.EXQUISITE:
			return "Exquisite Chest // 精巧な宝箱"
		ChestRarity.PRECIOUS:
			return "Precious Chest // 貴重な宝箱"
		ChestRarity.LUXURIOUS:
			return "Luxurious Chest // 豪華な宝箱"
		_:
			return "Treasure Chest // 宝箱"

func get_reward_yen() -> int:
	if custom_yen >= 0:
		return custom_yen
	match rarity:
		ChestRarity.COMMON: return 50
		ChestRarity.EXQUISITE: return 150
		ChestRarity.PRECIOUS: return 300
		ChestRarity.LUXURIOUS: return 500
		_: return 50

func get_reward_items() -> Array:
	if custom_loot.size() > 0:
		return custom_loot.duplicate()
	match rarity:
		ChestRarity.COMMON:
			return ["water"]
		ChestRarity.EXQUISITE:
			return ["tea", "onigiri"]
		ChestRarity.PRECIOUS:
			return ["juice", "bento"]
		ChestRarity.LUXURIOUS:
			return ["energy_drink", "ramen", "pocky"]
		_:
			return ["water"]

func _setup_visual_elements() -> void:
	if not find_child("ChestBase", true, false):
		# Chest Base Body
		var base := MeshInstance3D.new()
		base.name = "ChestBase"
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(0.9, 0.44, 0.58)
		base.mesh = b_mesh
		base.material_override = _create_chest_base_material()
		base.position = Vector3(0, 0.22, 0)
		add_child(base)

		# Metallic Trim / Corner Brackets
		var trim := MeshInstance3D.new()
		trim.name = "ChestTrim"
		var t_mesh := BoxMesh.new()
		t_mesh.size = Vector3(0.92, 0.08, 0.6)
		trim.mesh = t_mesh
		trim.material_override = _create_chest_trim_material()
		trim.position = Vector3(0, 0.40, 0)
		add_child(trim)

	# Lid Pivot for Smooth Opening Kinematics
	if not lid_pivot:
		lid_pivot = find_child("LidPivot", true, false) as Node3D
		if not lid_pivot:
			lid_pivot = Node3D.new()
			lid_pivot.name = "LidPivot"
			lid_pivot.position = Vector3(0, 0.44, -0.28) # Hinge line at top-back
			add_child(lid_pivot)

			# Lid Mesh attached to Pivot
			var lid := MeshInstance3D.new()
			lid.name = "ChestLid"
			var l_mesh := BoxMesh.new()
			l_mesh.size = Vector3(0.92, 0.18, 0.6)
			lid.mesh = l_mesh
			lid.material_override = _create_chest_base_material()
			lid.position = Vector3(0, 0.09, 0.28) # Offset forward from hinge
			lid_pivot.add_child(lid)

			# Front Clasp / Latch
			var lock := MeshInstance3D.new()
			lock.name = "ChestLock"
			var lock_mesh := BoxMesh.new()
			lock_mesh.size = Vector3(0.14, 0.14, 0.06)
			lock.mesh = lock_mesh
			lock.material_override = _create_chest_trim_material()
			lock.position = Vector3(0, 0.04, 0.59)
			lid_pivot.add_child(lock)

	# Interior Radiant Glow (OmniLight3D)
	if not chest_glow:
		chest_glow = find_child("ChestGlow", true, false) as OmniLight3D
		if not chest_glow:
			chest_glow = OmniLight3D.new()
			chest_glow.name = "ChestGlow"
			chest_glow.position = Vector3(0, 0.35, 0)
			chest_glow.omni_range = 3.6
			match rarity:
				ChestRarity.COMMON:
					chest_glow.light_color = Color(1.0, 0.85, 0.45) # Amber gold
					chest_glow.light_energy = 0.2
				ChestRarity.EXQUISITE:
					chest_glow.light_color = Color(0.4, 0.82, 1.0) # Azure sapphire
					chest_glow.light_energy = 0.35
				ChestRarity.PRECIOUS:
					chest_glow.light_color = Color(1.0, 0.72, 0.15) # Radiant sun gold
					chest_glow.light_energy = 0.5
				ChestRarity.LUXURIOUS:
					chest_glow.light_color = Color(0.9, 0.45, 1.0) # Violet-gold aurum
					chest_glow.light_energy = 0.65
			add_child(chest_glow)

func _create_chest_base_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	match rarity:
		ChestRarity.COMMON:
			mat.albedo_color = Color(0.38, 0.29, 0.22, 1.0) # Rustic wood
			mat.roughness = 0.85
			mat.metallic = 0.05
		ChestRarity.EXQUISITE:
			mat.albedo_color = Color(0.18, 0.28, 0.42, 1.0) # Azure steel
			mat.roughness = 0.35
			mat.metallic = 0.65
		ChestRarity.PRECIOUS:
			mat.albedo_color = Color(0.68, 0.16, 0.18, 1.0) # Royal crimson velvet & gold
			mat.roughness = 0.3
			mat.metallic = 0.5
		ChestRarity.LUXURIOUS:
			mat.albedo_color = Color(0.12, 0.10, 0.16, 1.0) # Obsidian composite
			mat.roughness = 0.18
			mat.metallic = 0.85
			mat.emission_enabled = true
			mat.emission = Color(0.45, 0.15, 0.65)
			mat.emission_energy_multiplier = 0.4
	return mat

func _create_chest_trim_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	match rarity:
		ChestRarity.COMMON:
			mat.albedo_color = Color(0.45, 0.46, 0.48, 1.0) # Cast iron
			mat.roughness = 0.6
			mat.metallic = 0.75
		ChestRarity.EXQUISITE:
			mat.albedo_color = Color(0.85, 0.88, 0.92, 1.0) # Polished silver
			mat.roughness = 0.2
			mat.metallic = 0.95
		ChestRarity.PRECIOUS:
			mat.albedo_color = Color(0.98, 0.78, 0.22, 1.0) # Imperial gold
			mat.roughness = 0.18
			mat.metallic = 0.98
		ChestRarity.LUXURIOUS:
			mat.albedo_color = Color(1.0, 0.84, 0.32, 1.0) # High-carat aurum
			mat.roughness = 0.12
			mat.metallic = 1.0
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.8, 0.2)
			mat.emission_energy_multiplier = 0.5
	return mat

func _setup_interactable() -> void:
	interactable = find_child("InteractableComponent", true, false) as InteractableComponent
	if not interactable:
		interactable = InteractableComponent.new()
		interactable.name = "InteractableComponent"
		interactable.verb = InteractableComponent.InteractionVerb.OPEN
		interactable.prompt_target_name = get_chest_name()
		interactable.interaction_range = 2.6
		add_child(interactable)

		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.5, 1.2, 1.5)
		col.shape = shape
		interactable.add_child(col)

	if not interactable.interaction_requested.is_connected(_on_interaction_requested):
		interactable.interaction_requested.connect(_on_interaction_requested)

func _setup_audio() -> void:
	if not audio_player:
		audio_player = find_child("ChestAudio", true, false) as AudioStreamPlayer3D
		if not audio_player:
			audio_player = AudioStreamPlayer3D.new()
			audio_player.name = "ChestAudio"
			audio_player.unit_size = 6.0
			audio_player.max_distance = 25.0
			add_child(audio_player)

func _on_interaction_requested(interactor: Node3D) -> void:
	open_chest(interactor)

func on_interacted(interactor: Node3D, verb: int) -> Dictionary:
	return open_chest(interactor)

func open_chest(interactor: Node3D = null, economy: EconomyManager = null, inventory: PlayerInventory = null) -> Dictionary:
	if is_opened:
		return {
			"success": false,
			"reason": "ALREADY_OPENED",
			"message": "Chest is already open."
		}

	is_opened = true
	is_animating = true
	emit_signal("chest_interacted", interactor)

	# 1. Kinematic Lid Opening via Tween
	if lid_pivot:
		var tween := create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(lid_pivot, "rotation:x", -deg_to_rad(80.0), 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if chest_glow:
				var flare_energy: float = 3.5 + float(rarity) * 0.8
				tween.tween_property(chest_glow, "light_energy", flare_energy, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.chain().tween_property(chest_glow, "light_energy", 0.6, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			lid_pivot.rotation.x = -deg_to_rad(80.0)
	
	# 2. Procedural Audio Feedback (Unlatch + Tiered Crystal Chime)
	if audio_player and audio_player.is_inside_tree():
		audio_player.stream = ProceduralCinematicAudio.create_chest_open_chime(rarity)
		audio_player.play()

	# 3. Disable Interactable
	if interactable:
		interactable.is_enabled = false
		interactable.prompt_target_name = get_chest_name() + " (Opened)"

	# 4. Resolve Economy & Inventory Rewards
	var yen_granted: int = get_reward_yen()
	var items_granted: Array = get_reward_items()

	# Auto-locate managers from scene tree / interactor if not explicitly provided
	if economy == null and interactor != null and interactor.get("economy_manager") != null:
		economy = interactor.economy_manager
	elif economy == null and get_tree() and get_tree().root:
		var found_econ = get_tree().root.find_child("EconomyManager", true, false)
		if found_econ is EconomyManager:
			economy = found_econ

	if inventory == null and interactor != null and interactor.get("inventory") != null:
		inventory = interactor.inventory
	elif inventory == null and get_tree() and get_tree().root:
		var found_inv = get_tree().root.find_child("PlayerInventory", true, false)
		if found_inv is PlayerInventory:
			inventory = found_inv

	if economy != null:
		economy.add_yen(yen_granted)

	if inventory != null:
		for item_id in items_granted:
			inventory.add_item(item_id, 1)

	emit_signal("chest_opened", chest_id, rarity, yen_granted, items_granted)

	return {
		"success": true,
		"chest_id": chest_id,
		"rarity": rarity,
		"yen_granted": yen_granted,
		"items_granted": items_granted,
		"is_opened": true
	}

func serialize() -> Dictionary:
	return {
		"chest_id": chest_id,
		"rarity": rarity,
		"is_opened": is_opened
	}

func deserialize(data: Dictionary) -> void:
	if data.has("chest_id"):
		chest_id = str(data["chest_id"])
	if data.has("rarity"):
		rarity = int(data["rarity"])
	if data.has("is_opened"):
		is_opened = bool(data["is_opened"])
		if is_opened and lid_pivot:
			lid_pivot.rotation.x = -deg_to_rad(80.0)
			if interactable:
				interactable.is_enabled = false
