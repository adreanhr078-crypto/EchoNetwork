class_name KasumiCafe
extends Node3D

## AAA Kasumi Coastal Cafe & Bakery
## Cozy seaside cafe with retro vinyl jazz, dark mahogany tables, aromatic drip coffee,
## sweet melon pan, energy & thirst restoration, and relaxing atmosphere.

signal order_served(item_id: String, cost: int, player: Node)
signal table_occupied(player: Node)
signal table_vacated(player: Node)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

const CAFE_MENU: Dictionary = {
	"DRIP_COFFEE": {
		"name": "Hand-Drip Sumiyaki Coffee // 炭火焙煎ドリップコーヒー",
		"cost": 420,
		"thirst_restore": 55.0,
		"energy_restore": 35.0,
		"sanity_restore": 15.0,
		"description": "Slow-dripped dark roast coffee with smoky notes of cedar and dark cacao."
	},
	"MATCHA_LATTE": {
		"name": "Uji Iced Matcha Latte // 宇治抹茶ラテ",
		"cost": 480,
		"thirst_restore": 65.0,
		"energy_restore": 20.0,
		"sanity_restore": 25.0,
		"description": "Ceremonial stone-ground Uji green tea whisked with silky milk and gentle sweetness."
	},
	"MELON_PAN": {
		"name": "Fresh-Baked Melon Pan // 焼きたてメロンパン",
		"cost": 240,
		"thirst_restore": 0.0,
		"energy_restore": 20.0,
		"sanity_restore": 10.0,
		"description": "Fluffy sweet brioche encased in a crunchy, sugar-crusted cookie crust."
	}
}

var seated_guest: Node = null
var total_orders: int = 0

func _ready() -> void:
	_setup_visuals()

func _setup_visuals() -> void:
	var cafe_light = find_child("CafeWarmLight", true, false) as OmniLight3D
	if not cafe_light:
		cafe_light = OmniLight3D.new()
		cafe_light.name = "CafeWarmLight"
		cafe_light.light_color = Color(1.0, 0.88, 0.65, 1.0) # Warm amber cafe light
		cafe_light.light_energy = 2.2
		cafe_light.omni_range = 8.0
		cafe_light.position = Vector3(0, 2.2, 0)
		add_child(cafe_light)

	# Coffee Cup Table Mesh
	var cup_mesh = find_child("CoffeeCupMesh", true, false)
	if not cup_mesh:
		var cup := MeshInstance3D.new()
		cup.name = "CoffeeCupMesh"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.09
		cyl.bottom_radius = 0.06
		cyl.height = 0.12
		cup.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.92, 0.94, 0.96, 1.0) # White ceramic mug
		cup.material_override = mat
		cup.position = Vector3(0.3, 0.76, 0)
		add_child(cup)

func sit_at_table(player: Node) -> Dictionary:
	seated_guest = player
	emit_signal("table_occupied", player)
	return {
		"success": true,
		"seated": true,
		"table_pos": global_position if is_inside_tree() else position
	}

func leave_table() -> void:
	if seated_guest:
		var g = seated_guest
		seated_guest = null
		emit_signal("table_vacated", g)

func is_table_occupied() -> bool:
	return seated_guest != null

func order_item(item_id: String, player: Node) -> Dictionary:
	if not CAFE_MENU.has(item_id):
		return {"success": false, "reason": "invalid_item"}

	var item: Dictionary = CAFE_MENU[item_id]
	var cost: int = item["cost"]

	# Spend yen
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

	# Restore Thirst & Energy
	if item["thirst_restore"] > 0:
		if player.has_method("restore_thirst"):
			player.restore_thirst(item["thirst_restore"])
		elif "needs" in player and player.needs and player.needs.has_method("consume_drink"):
			player.needs.consume_drink(item["thirst_restore"], item["energy_restore"])

	if item["energy_restore"] > 0 and player.has_method("restore_energy"):
		player.restore_energy(item["energy_restore"])

	# Audio chime
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_vending_clunk()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	total_orders += 1
	emit_signal("order_served", item_id, cost, player)

	return {
		"success": true,
		"item_id": item_id,
		"name": item["name"],
		"cost": cost,
		"thirst_restored": item["thirst_restore"],
		"energy_restored": item["energy_restore"]
	}

func get_menu() -> Dictionary:
	return CAFE_MENU.duplicate()
