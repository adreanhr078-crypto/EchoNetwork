class_name KonbiniStore
extends Node3D

signal player_entered()
signal player_exited()
signal item_purchased(item_id: String, count: int, total_cost: int)
signal checkout_completed(total_paid: int, items_bought: Array)
signal checkout_failed(reason: String)

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")
const EconomyManager = preload("res://scripts/systems/economy_manager.gd")
const PlayerInventory = preload("res://scripts/systems/player_inventory.gd")

@export var store_name: String = "Kasumi Mart // カスミマート"
@export var is_24_hours: bool = true
@export var opening_hour: int = 0
@export var closing_hour: int = 24
@export var clerk_name: String = "Hana Mori"

var shopping_cart: Dictionary = {}
var customer_visit_count: int = 0
var audio_player: AudioStreamPlayer3D = null

@onready var door_sensor: Area3D = find_child("DoorSensor", true, false) as Area3D
@onready var checkout_register: Area3D = find_child("CheckoutRegister", true, false) as Area3D

const CLERK_GREETINGS := [
	"Irasshaimase! // Welcome to Kasumi Mart! Let me know if you need anything heated up.",
	"Welcome back! Fresh bento and cold tea were just restocked in aisle two.",
	"Good evening! Chilly out there by the water, isn't it? Our hot drinks are in the warmer cabinet."
]

func _ready() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.max_distance = 18.0
		add_child(audio_player)
	
	if door_sensor:
		door_sensor.body_entered.connect(_on_door_entered)
		door_sensor.body_exited.connect(_on_door_exited)

func is_open(current_hour: int = 17) -> bool:
	if is_24_hours:
		return true
	if opening_hour == closing_hour:
		return true
	if opening_hour < closing_hour:
		return current_hour >= opening_hour and current_hour < closing_hour
	else:
		return current_hour >= opening_hour or current_hour < closing_hour

func _on_door_entered(body: Node) -> void:
	if body.is_in_group("player") or body.has_method("get_wallet") or body.name == "EchoPlayer":
		customer_visit_count += 1
		play_entrance_chime()
		emit_signal("player_entered")

func _on_door_exited(body: Node) -> void:
	if body.is_in_group("player") or body.has_method("get_wallet") or body.name == "EchoPlayer":
		emit_signal("player_exited")

func play_entrance_chime() -> void:
	if audio_player:
		audio_player.stream = ProceduralCinematicAudio.create_konbini_chime()
		audio_player.play()

func play_register_beep() -> void:
	if audio_player:
		audio_player.stream = ProceduralCinematicAudio.create_register_beep()
		audio_player.play()

func get_clerk_greeting() -> String:
	var idx = min(customer_visit_count - 1, CLERK_GREETINGS.size() - 1)
	if idx < 0:
		idx = 0
	return CLERK_GREETINGS[idx]

func add_to_cart(item_id: String, count: int = 1) -> Dictionary:
	if not PlayerInventory.ITEM_DEFINITIONS.has(item_id):
		return {"success": false, "reason": "invalid_item"}
	
	var current = shopping_cart.get(item_id, 0)
	shopping_cart[item_id] = current + count
	return {
		"success": true,
		"item_id": item_id,
		"count": shopping_cart[item_id],
		"total_cart_cost": get_cart_total()
	}

func remove_from_cart(item_id: String, count: int = 1) -> Dictionary:
	if not shopping_cart.has(item_id):
		return {"success": false, "reason": "not_in_cart"}
	
	shopping_cart[item_id] = max(0, shopping_cart[item_id] - count)
	if shopping_cart[item_id] == 0:
		shopping_cart.erase(item_id)
	return {
		"success": true,
		"item_id": item_id,
		"remaining": shopping_cart.get(item_id, 0),
		"total_cart_cost": get_cart_total()
	}

func get_cart_total() -> int:
	var total: int = 0
	for item_id in shopping_cart.keys():
		var def = PlayerInventory.ITEM_DEFINITIONS.get(item_id, {})
		var price = def.get("price", 100)
		total += price * shopping_cart[item_id]
	return total

func clear_cart() -> void:
	shopping_cart.clear()

func checkout(buyer: Node) -> Dictionary:
	if shopping_cart.is_empty():
		emit_signal("checkout_failed", "cart_empty")
		return {"success": false, "reason": "cart_empty"}

	var total_cost = get_cart_total()

	# Resolve wallet
	var wallet: EconomyManager = null
	if buyer:
		if buyer.get("wallet") is EconomyManager:
			wallet = buyer.wallet
		elif buyer.has_method("get_wallet"):
			wallet = buyer.get_wallet()

	if not wallet:
		emit_signal("checkout_failed", "no_wallet")
		return {"success": false, "reason": "no_wallet"}

	if not wallet.has_funds(total_cost):
		emit_signal("checkout_failed", "insufficient_funds")
		return {
			"success": false,
			"reason": "insufficient_funds",
			"required": total_cost,
			"current": wallet.get_yen()
		}

	# Resolve inventory
	var inventory: PlayerInventory = null
	if buyer:
		if buyer.get("inventory") is PlayerInventory:
			inventory = buyer.inventory
		elif buyer.has_method("get_inventory"):
			inventory = buyer.get_inventory()

	# Deduct funds
	wallet.spend_yen(total_cost)

	# Deliver items
	var purchased_items = []
	for item_id in shopping_cart.keys():
		var count = shopping_cart[item_id]
		if inventory:
			inventory.add_item(item_id, count)
		purchased_items.append({"item_id": item_id, "count": count})
		emit_signal("item_purchased", item_id, count, total_cost)

	clear_cart()
	play_register_beep()

	emit_signal("checkout_completed", total_cost, purchased_items)

	return {
		"success": true,
		"total_paid": total_cost,
		"items_bought": purchased_items,
		"remaining_yen": wallet.get_yen(),
		"clerk_message": "Arigatou gozaimasu! // Thank you, please come again!"
	}

func quick_buy(item_id: String, buyer: Node, count: int = 1) -> Dictionary:
	add_to_cart(item_id, count)
	return checkout(buyer)
