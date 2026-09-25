class_name VendingGachaController
extends Node

## AAA Japanese Vending Machine Gacha / Gashapon Capsule Toy Engine
## Insert 500 Yen to dispense lucky collectible charms & figurines.
## Features mechanical crank rotation, plastic capsule roll SFX, and inventory delivery.

signal capsule_dispensed(item_id: String, item_name: String, rarity: String)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

const GACHA_COST_YEN: int = 500

const GACHA_POOL: Array[Dictionary] = [
	{
		"id": "capsule_golden_tanuki",
		"name": "Golden Tanuki Lucky Mascot // 金の狸",
		"rarity": "LEGENDARY",
		"weight": 10
	},
	{
		"id": "capsule_mini_katana",
		"name": "Miniature Shadow Katana Figurine // ミニ刀",
		"rarity": "EPIC",
		"weight": 20
	},
	{
		"id": "capsule_crystal_bell",
		"name": "Mount Kasumi Crystal Wind Bell // 風鈴",
		"rarity": "RARE",
		"weight": 25
	},
	{
		"id": "capsule_sakura_badge",
		"name": "Minato Academy Enamel Pin // 桜の校章",
		"rarity": "RARE",
		"weight": 25
	},
	{
		"id": "capsule_milk_cap",
		"name": "Retro Strawberry Milk Bottle Cap // 苺牛乳キャップ",
		"rarity": "COMMON",
		"weight": 20
	}
]

var total_pulls: int = 0
var collected_items: Dictionary = {}

## Inserts 500 Yen, spins the mechanical dial, and dispenses a capsule toy
func pull_gacha(player: Node = null) -> Dictionary:
	if player and "wallet" in player and player.wallet != null:
		if player.wallet.has_method("has_funds") and not player.wallet.has_funds(GACHA_COST_YEN):
			return {"success": false, "error": "Insufficient Yen (Requires 500 Yen)"}
		if player.wallet.has_method("spend_yen"):
			player.wallet.spend_yen(GACHA_COST_YEN)

	total_pulls += 1

	# Weighted prize selection
	var total_weight = 0
	for item in GACHA_POOL:
		total_weight += item["weight"]

	var roll = randi_range(1, total_weight)
	var accumulated = 0
	var chosen: Dictionary = GACHA_POOL[0]

	for item in GACHA_POOL:
		accumulated += item["weight"]
		if roll <= accumulated:
			chosen = item
			break

	var item_id: String = chosen["id"]
	var item_name: String = chosen["name"]
	var rarity: String = chosen["rarity"]

	collected_items[item_id] = collected_items.get(item_id, 0) + 1

	if player and "inventory" in player and player.inventory != null:
		if player.inventory.has_method("add_item"):
			player.inventory.add_item(item_id, 1)

	# Play authentic capsule dispenser mechanical clunk audio
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_gacha_capsule_drop_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("capsule_dispensed", item_id, item_name, rarity)

	return {
		"success": true,
		"cost_yen": GACHA_COST_YEN,
		"item_id": item_id,
		"item_name": item_name,
		"rarity": rarity,
		"total_pulls": total_pulls
	}

## Explicit teardown — stops and frees any lingering AudioStreamPlayer children
func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
	collected_items.clear()
