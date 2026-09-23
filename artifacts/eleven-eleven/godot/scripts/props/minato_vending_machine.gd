class_name MinatoVendingMachine
extends Node3D

signal drink_purchased(item_id: String, price: int, buyer: Node)
signal purchase_failed(reason: String)

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")
const EconomyManager = preload("res://scripts/systems/economy_manager.gd")
const PlayerInventory = preload("res://scripts/systems/player_inventory.gd")

const DRINKS := {
	"water": {"name": "Natural Mineral Water // 天然水", "price": 120},
	"tea": {"name": "Iced Green Tea // 緑茶", "price": 140},
	"juice": {"name": "Kasumi Citrus Juice // 柑橘ジュース", "price": 160}
}

@onready var interactable = find_child("VendingInteractable", true, false)
var audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.max_distance = 12.0
		add_child(audio_player)
	
	if not interactable:
		interactable = find_child("VendingInteractable", true, false) as InteractableComponent
	if interactable:
		interactable.verb = InteractableComponent.InteractionVerb.BUY
		interactable.prompt_target_name = "Vending Machine"

func on_interacted(interactor: Node3D, verb: int) -> Dictionary:
	# Default quick-buy action purchases water
	return buy_drink("water", interactor)

func buy_drink(item_id: String, buyer: Node = null) -> Dictionary:
	if not DRINKS.has(item_id):
		emit_signal("purchase_failed", "invalid_item")
		return {"success": false, "reason": "invalid_item"}

	var drink_info = DRINKS[item_id]
	var price: int = drink_info["price"]

	# Wallet resolution
	var wallet: EconomyManager = null
	if buyer:
		if buyer.get("wallet") is EconomyManager:
			wallet = buyer.wallet
		elif buyer.has_method("get_wallet"):
			wallet = buyer.get_wallet()
	
	if not wallet:
		emit_signal("purchase_failed", "no_wallet")
		return {"success": false, "reason": "no_wallet"}

	if not wallet.has_funds(price):
		emit_signal("purchase_failed", "insufficient_funds")
		return {"success": false, "reason": "insufficient_funds", "required": price, "current": wallet.get_yen()}

	# Deduct yen
	wallet.spend_yen(price)

	# Add to inventory
	var inventory: PlayerInventory = null
	if buyer:
		if buyer.get("inventory") is PlayerInventory:
			inventory = buyer.inventory
		elif buyer.has_method("get_inventory"):
			inventory = buyer.get_inventory()

	if inventory:
		inventory.add_item(item_id, 1)

	# Play can drop clunk sound
	if audio_player:
		audio_player.stream = ProceduralCinematicAudio.create_vending_clunk()
		audio_player.play()

	emit_signal("drink_purchased", item_id, price, buyer)

	return {
		"success": true,
		"item_id": item_id,
		"item_name": drink_info["name"],
		"price": price,
		"remaining_yen": wallet.get_yen()
	}
