class_name TownBountyContractManager
extends Node

## AAA Minato Town Daily Bounty & Commission Contract Manager
## Genshin / GTA-style daily quest loop:
## - 4 Daily commissions spanning the town: Shrine, Clinic, Rogue Awakener, Ramen Bar
## - Individual commission completion rewards (Yen + XP)
## - Grand Turn-In Bonus: Astral Resonance Shards (Primogems) + 5000 Yen upon 4/4 completion

signal commission_completed(comm_id: String, reward_yen: int)
signal all_commissions_cleared(bonus_yen: int, astral_shards: int)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

var commissions: Dictionary = {
	"SHRINE_PRAYER": {
		"title": "Roadside Shrine Devotion",
		"desc": "Offer prayer and coin at the roadside Jizo shrine for town protection.",
		"completed": false,
		"reward_yen": 500
	},
	"CLINIC_DELIVERY": {
		"title": "Medical Restock for Nurse Aoi",
		"desc": "Purchase sterile bandages from the pharmacy and check in at the clinic.",
		"completed": false,
		"reward_yen": 800
	},
	"NOCTURNAL_SUBJUGATION": {
		"title": "Purge the Alley Rogue Awakener",
		"desc": "Defeat one aberrant subject prowling the narrow backstreets after 21:00.",
		"completed": false,
		"reward_yen": 1500
	},
	"RAMEN_SPECIAL": {
		"title": "Kasumi Ramen Nourishment",
		"desc": "Enjoy a fresh bowl of hot Tonkotsu broth at Kenji's ramen bar.",
		"completed": false,
		"reward_yen": 600
	}
}

var grand_bonus_claimed: bool = false

func get_commissions() -> Dictionary:
	return commissions.duplicate(true)

func get_completed_count() -> int:
	var count = 0
	for cid in commissions:
		if commissions[cid].get("completed", false):
			count += 1
	return count

func is_all_completed() -> bool:
	return get_completed_count() >= commissions.size()

## Completes an individual daily commission
func complete_commission(comm_id: String, player: Node = null) -> Dictionary:
	if not commissions.has(comm_id):
		return {"success": false, "error": "Unknown commission ID"}

	var comm: Dictionary = commissions[comm_id]
	if comm["completed"]:
		return {"success": false, "error": "Commission already completed"}

	comm["completed"] = true
	var reward: int = comm["reward_yen"]

	if player and "wallet" in player and player.wallet != null:
		if player.wallet.has_method("earn_yen"):
			player.wallet.earn_yen(reward)
		elif player.wallet.has_method("add_yen"):
			player.wallet.add_yen(reward)

	emit_signal("commission_completed", comm_id, reward)

	return {
		"success": true,
		"commission_id": comm_id,
		"title": comm["title"],
		"reward_yen": reward,
		"total_completed": get_completed_count(),
		"all_cleared": is_all_completed()
	}

## Claims the 4/4 Grand Daily Bounty Reward
func claim_daily_grand_reward(player: Node = null) -> Dictionary:
	if not is_all_completed():
		return {"success": false, "error": "Must complete all 4 commissions first"}
	if grand_bonus_claimed:
		return {"success": false, "error": "Daily grand reward already claimed"}

	grand_bonus_claimed = true
	var bonus_yen: int = 5000
	var astral_shards: int = 60 # Primogem / Fate equivalent

	if player:
		if "wallet" in player and player.wallet != null:
			if player.wallet.has_method("earn_yen"):
				player.wallet.earn_yen(bonus_yen)
			elif player.wallet.has_method("add_yen"):
				player.wallet.add_yen(bonus_yen)

		if "inventory" in player and player.inventory != null:
			if player.inventory.has_method("add_item"):
				player.inventory.add_item("astral_resonance_shard", astral_shards)

	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_bond_up_jingle()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("all_commissions_cleared", bonus_yen, astral_shards)

	return {
		"success": true,
		"bonus_yen": bonus_yen,
		"astral_shards": astral_shards,
		"status": "Daily Commissions Fully Completed"
	}

## Explicit teardown — frees any lingering audio children to prevent RID leaks
func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
