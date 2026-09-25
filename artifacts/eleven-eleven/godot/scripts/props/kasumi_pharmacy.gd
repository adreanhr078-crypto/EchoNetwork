class_name KasumiPharmacy
extends Node3D

## AAA Kasumi Town Pharmacy & Clinic
## 24/7 medical counter providing sterile bandages, adrenaline ampoules,
## and neural stabilizers to suppress Reality Glitch spikes and restore vitals.

signal medicine_purchased(medicine_id: String, cost: int, player: Node)
signal medicine_consumed(medicine_id: String, player: Node)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

const PHARMACY_CATALOG: Dictionary = {
	"STERILE_BANDAGES": {
		"name": "Sterile Combat Bandages // 滅菌包帯",
		"cost": 350,
		"hp_heal": 60.0,
		"stamina_restore": 0.0,
		"glitch_suppress": 0.0,
		"description": "Medical-grade compress gauze for treating lacerations and blunt trauma."
	},
	"ADRENALINE_AMPOULE": {
		"name": "Synthesized Adrenaline Ampoule // 合成アドレナリン",
		"cost": 600,
		"hp_heal": 20.0,
		"stamina_restore": 80.0,
		"glitch_suppress": 0.0,
		"description": "Rapid intramuscular injection that instantly replenishes muscular stamina."
	},
	"NEURAL_STABILIZER": {
		"name": "Sector 11 Neural Sedative // 神経安定剤EX",
		"cost": 1200,
		"hp_heal": 0.0,
		"stamina_restore": 20.0,
		"glitch_suppress": 75.0,
		"description": "High-purity sedative that clears neural interference and suppresses reality glitches."
	}
}

var total_prescriptions_filled: int = 0

func _ready() -> void:
	_setup_visuals()

func _setup_visuals() -> void:
	# Clinical green/cyan cross lighting
	var clinic_light = find_child("ClinicCrossGlow", true, false) as OmniLight3D
	if not clinic_light:
		clinic_light = OmniLight3D.new()
		clinic_light.name = "ClinicCrossGlow"
		clinic_light.light_color = Color(0.12, 0.95, 0.65, 1.0) # Emerald/Cyan medical hue
		clinic_light.light_energy = 2.0
		clinic_light.omni_range = 7.0
		clinic_light.position = Vector3(0, 2.0, 0)
		add_child(clinic_light)

	# Medicine Bottle Display Mesh
	var bottle = find_child("PillBottleMesh", true, false)
	if not bottle:
		var bottle_mesh := MeshInstance3D.new()
		bottle_mesh.name = "PillBottleMesh"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.06
		cyl.height = 0.14
		bottle_mesh.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.45, 0.05, 0.9) # Amber medical glass
		mat.roughness = 0.1
		bottle_mesh.material_override = mat
		bottle_mesh.position = Vector3(0, 0.85, 0)
		add_child(bottle_mesh)

func buy_medicine(medicine_id: String, player: Node) -> Dictionary:
	if not PHARMACY_CATALOG.has(medicine_id):
		return {"success": false, "reason": "invalid_medicine"}

	var item: Dictionary = PHARMACY_CATALOG[medicine_id]
	var cost: int = item["cost"]

	# Deduct yen
	var wallet = player.get("wallet")
	if not wallet and player.has_method("get_wallet"):
		wallet = player.get_wallet()

	if wallet and wallet.has_method("spend_yen"):
		if not wallet.spend_yen(cost):
			return {"success": false, "reason": "insufficient_yen", "cost": cost}
	elif "yen" in player:
		if player.yen < cost:
			return {"success": false, "reason": "insufficient_yen", "cost": cost}
		player.yen -= cost

	# Add to inventory
	var inv = player.get("inventory")
	if not inv and player.has_method("get_inventory"):
		inv = player.get_inventory()
	if inv and inv.has_method("add_item"):
		inv.add_item(medicine_id.to_lower(), 1)

	# Audio Rattle
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_pill_bottle_rattle()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	total_prescriptions_filled += 1
	emit_signal("medicine_purchased", medicine_id, cost, player)

	return {
		"success": true,
		"medicine_id": medicine_id,
		"name": item["name"],
		"cost": cost
	}

func use_medicine(medicine_id: String, player: Node) -> Dictionary:
	if not PHARMACY_CATALOG.has(medicine_id):
		return {"success": false, "reason": "invalid_medicine"}

	var item: Dictionary = PHARMACY_CATALOG[medicine_id]

	# Consume from inventory if available
	var inv = player.get("inventory")
	if not inv and player.has_method("get_inventory"):
		inv = player.get_inventory()
	if inv and inv.has_method("remove_item"):
		if not inv.remove_item(medicine_id.to_lower(), 1):
			return {"success": false, "reason": "item_not_in_inventory"}

	# Apply Effects
	if item["hp_heal"] > 0 and "hp" in player:
		player.hp = minf(200.0, player.hp + item["hp_heal"])
		if player.has_signal("hp_changed"):
			player.emit_signal("hp_changed", player.hp, 200.0)

	if item["stamina_restore"] > 0:
		if player.has_method("restore_stamina"):
			player.restore_stamina(item["stamina_restore"])
		elif "stamina" in player:
			player.stamina = minf(100.0, player.stamina + item["stamina_restore"])
			if player.has_signal("stamina_changed"):
				player.emit_signal("stamina_changed", player.stamina, 100.0)

	# Audio
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_pill_bottle_rattle()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("medicine_consumed", medicine_id, player)

	return {
		"success": true,
		"medicine_id": medicine_id,
		"hp_healed": item["hp_heal"],
		"stamina_restored": item["stamina_restore"],
		"glitch_suppressed": item["glitch_suppress"]
	}

func get_catalog() -> Dictionary:
	return PHARMACY_CATALOG.duplicate()
