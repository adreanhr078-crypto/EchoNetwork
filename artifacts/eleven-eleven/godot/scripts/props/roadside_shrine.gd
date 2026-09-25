class_name RoadsideShrine
extends Node3D

## Minato-Kasumi Coastal Roadside Jizo Shrine (Dousojin / Hokora // 道祖神・地蔵尊)
## A time-weathered coastal stone shrine nestled beneath ancient pines.
## Offering a 100 Yen coin and bowing in prayer rings the sacred crystal bell,
## cleanses neural fatigue, and grants the "Blessing of Coastal Clarity".

signal shrine_offered(offering_amount: int, blessing_name: String)

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")
const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const EconomyManager = preload("res://scripts/systems/economy_manager.gd")

const OFFERING_COST: int = 100
const BLESSING_NAME: String = "Blessing of Coastal Clarity // 潮風の加護"

var interactable: InteractableComponent = null
var prayer_count: int = 0
var audio_player: AudioStreamPlayer = null
var shrine_glow: OmniLight3D = null

func _ready() -> void:
	ensure_setup()

func ensure_setup() -> void:
	_setup_visual_elements()
	_setup_interactable()
	_setup_audio()

func _setup_visual_elements() -> void:
	if not find_child("ShrineMesh", true, false):
		# Stone Pedestal
		var pedestal := MeshInstance3D.new()
		pedestal.name = "ShrineMesh"
		var p_mesh := BoxMesh.new()
		p_mesh.size = Vector3(0.9, 0.7, 0.7)
		pedestal.mesh = p_mesh
		var p_mat := StandardMaterial3D.new()
		p_mat.albedo_color = Color(0.38, 0.40, 0.39, 1.0)
		p_mat.roughness = 0.9
		pedestal.material_override = p_mat
		pedestal.position = Vector3(0, 0.35, 0)
		add_child(pedestal)

		# Jizo Figure / Alcove Stone
		var statue := MeshInstance3D.new()
		statue.name = "JizoStatue"
		var s_mesh := CylinderMesh.new()
		s_mesh.top_radius = 0.22
		s_mesh.bottom_radius = 0.28
		s_mesh.height = 0.65
		statue.mesh = s_mesh
		var s_mat := StandardMaterial3D.new()
		s_mat.albedo_color = Color(0.48, 0.50, 0.49, 1.0)
		s_mat.roughness = 0.85
		statue.material_override = s_mat
		statue.position = Vector3(0, 0.95, 0)
		add_child(statue)

		# Traditional Red Bib / Offering Cloth
		var bib := MeshInstance3D.new()
		bib.name = "RedBib"
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(0.32, 0.25, 0.32)
		bib.mesh = b_mesh
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color(0.85, 0.12, 0.14, 1.0) # Vermilion Shinto Red
		b_mat.roughness = 0.6
		bib.material_override = b_mat
		bib.position = Vector3(0, 0.92, 0)
		add_child(bib)

	# Shrine Amber Lantern Light
	if not shrine_glow:
		shrine_glow = find_child("ShrineGlow", true, false) as OmniLight3D
		if not shrine_glow:
			shrine_glow = OmniLight3D.new()
			shrine_glow.name = "ShrineGlow"
			shrine_glow.light_color = Color(1.0, 0.78, 0.45, 1.0)
			shrine_glow.light_energy = 1.4
			shrine_glow.omni_range = 3.5
			shrine_glow.position = Vector3(0, 1.2, 0.3)
			add_child(shrine_glow)

func _setup_interactable() -> void:
	interactable = find_child("InteractableComponent", true, false)
	if not interactable:
		interactable = InteractableComponent.new()
		interactable.name = "InteractableComponent"
		interactable.verb = InteractableComponent.InteractionVerb.PRAY
		interactable.prompt_target_name = "Roadside Jizo Shrine // 道祖神・地蔵尊"
		interactable.interaction_range = 2.8
		add_child(interactable)
		
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.6, 2.0, 1.6)
		col.shape = shape
		interactable.add_child(col)

	if not interactable.interaction_requested.is_connected(_on_interaction):
		interactable.interaction_requested.connect(_on_interaction)

func _setup_audio() -> void:
	if not audio_player:
		audio_player = find_child("ShrineAudio", true, false) as AudioStreamPlayer
		if not audio_player:
			audio_player = AudioStreamPlayer.new()
			audio_player.name = "ShrineAudio"
			audio_player.volume_db = -3.0
			add_child(audio_player)

func _on_interaction(interactor: Node3D) -> void:
	# Attempt to locate economy manager in scene tree
	var economy: EconomyManager = null
	if interactor and interactor.get("economy_manager") != null:
		economy = interactor.economy_manager
	elif get_tree() and get_tree().root:
		var found_econ = get_tree().root.find_child("EconomyManager", true, false)
		if found_econ and found_econ is EconomyManager:
			economy = found_econ

	offer_prayer(interactor, economy)

func offer_prayer(interactor: Node3D, economy: EconomyManager = null) -> Dictionary:
	var success: bool = false
	var spent: int = 0
	
	if economy != null:
		if economy.has_funds(OFFERING_COST):
			economy.spend_yen(OFFERING_COST)
			spent = OFFERING_COST
			success = true
		else:
			return {
				"success": false,
				"reason": "INSUFFICIENT_FUNDS",
				"message": "Not enough Yen for offering (100 Yen required)."
			}
	else:
		# If no economy manager provided, default to free prayer
		success = true

	prayer_count += 1

	# Play sacred crystal suzu bell chime
	if audio_player and audio_player.is_inside_tree():
		audio_player.stream = ProceduralCinematicAudio.create_shrine_crystal_bell()
		audio_player.play()

	# Apply restorative blessing to interactor
	if interactor:
		if interactor.get("stamina") != null:
			var max_stam: float = 100.0
			if interactor.get("MAX_STAMINA") != null:
				max_stam = float(interactor.get("MAX_STAMINA"))
			interactor.stamina = minf(max_stam, interactor.stamina + 50.0)
			if interactor.has_signal("stamina_changed"):
				interactor.emit_signal("stamina_changed", interactor.stamina, max_stam)
		if interactor.has_method("heal"):
			interactor.heal(25.0)

	emit_signal("shrine_offered", spent, BLESSING_NAME)

	return {
		"success": true,
		"prayer_count": prayer_count,
		"offering_spent": spent,
		"blessing": BLESSING_NAME,
		"stamina_restored": 50.0
	}

func get_prayer_count() -> int:
	return prayer_count
