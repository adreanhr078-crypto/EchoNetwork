class_name KasumiRamenBar
extends Node3D

## AAA Kasumi Ramen Noodle Bar
## Authentic Japanese ramen counter with wooden stools, glowing red chochin lanterns,
## steaming tonkotsu broth, interactive ordering, hunger/HP restoration, and slurp audio synthesis.

signal player_seated(player: Node)
signal player_unseated(player: Node)
signal meal_served(meal_id: String, cost: int, player: Node)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")

const MENU: Dictionary = {
	"TONKOTSU_RAMEN": {
		"name": "Chashu Tonkotsu Ramen // チャーシュー豚骨ラーメン",
		"cost": 850,
		"hunger_restore": 100.0,
		"hp_restore": 35.0,
		"stamina_buff": 20.0,
		"description": "Rich 18-hour pork bone broth with braised chashu, seasoned soft-boiled egg, and nori."
	},
	"MISO_RAMEN": {
		"name": "Hokkaido Butter Corn Miso Ramen // 味噌ラーメン",
		"cost": 780,
		"hunger_restore": 85.0,
		"hp_restore": 20.0,
		"stamina_buff": 10.0,
		"description": "Hearty red miso broth with sweet corn kernels and roasted sesame oil."
	},
	"SPICY_GYOZA": {
		"name": "Crispy Pan-Fried Gyoza (6pcs) // 焼き餃子",
		"cost": 450,
		"hunger_restore": 45.0,
		"hp_restore": 10.0,
		"stamina_buff": 15.0,
		"description": "Golden crispy dumplings filled with minced Berkshire pork, scallions, and chili rayu."
	}
}

var seated_player: Node = null
var seat_position: Vector3 = Vector3(0, 0.45, 0.8)
var total_meals_served: int = 0
var audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	_setup_visuals()

func _setup_visuals() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "RamenAudio"
		audio_player.max_distance = 14.0
		add_child(audio_player)

	# Warm counter lantern light
	var lantern = find_child("CounterLanternGlow", true, false) as OmniLight3D
	if not lantern:
		lantern = OmniLight3D.new()
		lantern.name = "CounterLanternGlow"
		lantern.light_color = Color(1.0, 0.72, 0.35, 1.0)
		lantern.light_energy = 2.4
		lantern.omni_range = 6.0
		lantern.position = Vector3(0, 1.8, 0)
		add_child(lantern)

	# Steaming Broth Bowl Node
	var broth_mesh = find_child("RamenBowlMesh", true, false)
	if not broth_mesh:
		var bowl := MeshInstance3D.new()
		bowl.name = "RamenBowlMesh"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.22
		cyl.bottom_radius = 0.12
		cyl.height = 0.18
		bowl.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.08, 0.06, 1.0) # Ceramic dark bowl
		mat.roughness = 0.2
		bowl.material_override = mat
		bowl.position = Vector3(0, 0.85, 0)
		add_child(bowl)

		# Steaming soup surface
		var soup := MeshInstance3D.new()
		soup.name = "SoupSurface"
		var soup_cyl := CylinderMesh.new()
		soup_cyl.top_radius = 0.20
		soup_cyl.bottom_radius = 0.19
		soup_cyl.height = 0.02
		soup.mesh = soup_cyl
		var soup_mat := StandardMaterial3D.new()
		soup_mat.albedo_color = Color(0.85, 0.55, 0.22, 1.0) # Rich tonkotsu broth
		soup_mat.metallic = 0.1
		soup_mat.roughness = 0.1
		soup.material_override = soup_mat
		soup.position = Vector3(0, 0.08, 0)
		bowl.add_child(soup)

func seat_player(player: Node) -> Dictionary:
	seated_player = player
	emit_signal("player_seated", player)
	return {
		"success": true,
		"seated": true,
		"seat_pos": global_position + seat_position if is_inside_tree() else position + seat_position
	}

func unseat_player() -> void:
	if seated_player:
		var p = seated_player
		seated_player = null
		emit_signal("player_unseated", p)

func is_player_seated() -> bool:
	return seated_player != null

func order_meal(meal_id: String, player: Node) -> Dictionary:
	if not MENU.has(meal_id):
		return {"success": false, "reason": "invalid_meal"}
	
	var item: Dictionary = MENU[meal_id]
	var cost: int = item["cost"]

	# Check player wallet
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

	# Restore Hunger
	if player.has_method("restore_hunger"):
		player.restore_hunger(item["hunger_restore"])
	elif "needs" in player and player.needs and player.needs.has_method("consume_food"):
		player.needs.consume_food(item["hunger_restore"], 0.0, item["stamina_buff"])

	# Restore HP
	if "hp" in player:
		player.hp = minf(200.0, player.hp + item["hp_restore"])
		if player.has_signal("hp_changed"):
			player.emit_signal("hp_changed", player.hp, 200.0)

	# Audio Synthesis Slurp
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_ramen_slurp_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	total_meals_served += 1
	emit_signal("meal_served", meal_id, cost, player)

	return {
		"success": true,
		"meal_id": meal_id,
		"name": item["name"],
		"cost": cost,
		"hunger_restored": item["hunger_restore"],
		"hp_restored": item["hp_restore"]
	}

func get_menu() -> Dictionary:
	return MENU.duplicate()
