class_name WardrobeDressingSystem
extends Node

## AAA Echo Residence Bedroom Wardrobe & Outfit Customization System
## Allows Echo to inspect his full-length mirror and switch between 3 authored anime outfits:
## - CASUAL_HOODIE: Minato town casual street style
## - MINATO_ACADEMY_UNIFORM: Navy blazer & tie (+15% Social Bond progression with classmates)
## - VOID_CHOSEN_COAT: Obsidian duster coat (+10% Void combat damage)
## Features metallic zipper slide audio and dynamic buff tracking.

signal outfit_changed(outfit_id: String, outfit_name: String, perk: String)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

const OUTFITS: Dictionary = {
	"CASUAL_HOODIE": {
		"name": "Minato Streetwear (Grey Hoodie & Cargo)",
		"desc": "Echo's everyday casual clothes for walking around the coastal town.",
		"perk": "Comfortable Fit (Stamina regen +5%)",
		"bonus_type": "STAMINA_REGEN",
		"bonus_value": 0.05
	},
	"MINATO_ACADEMY_UNIFORM": {
		"name": "Minato Academy Uniform (Navy Blazer)",
		"desc": "Standard uniform for second-year students at Minato High School.",
		"perk": "Model Student (+15% Social Bond affinity gain with Yuki & Shizuka)",
		"bonus_type": "BOND_MULTIPLIER",
		"bonus_value": 0.15
	},
	"VOID_CHOSEN_COAT": {
		"name": "Void Monarch Duster (Obsidian & Crimson)",
		"desc": "Tactical shadow coat designed to channel raw Singularity energy.",
		"perk": "Abyssal Authority (+10% Void Katana & Burst damage)",
		"bonus_type": "VOID_DAMAGE",
		"bonus_value": 0.10
	}
}

var current_outfit_id: String = "CASUAL_HOODIE"

func get_current_outfit() -> Dictionary:
	return OUTFITS.get(current_outfit_id, OUTFITS["CASUAL_HOODIE"])

## Changes Echo's active outfit and equips unique passive perks
func equip_outfit(outfit_id: String, player: Node = null) -> Dictionary:
	var key = outfit_id.to_upper()
	if not OUTFITS.has(key):
		return {"success": false, "error": "Unknown outfit ID"}

	current_outfit_id = key
	var outfit: Dictionary = OUTFITS[key]

	# Play metallic zipper and cloth rustle SFX
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_wardrobe_zipper_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("outfit_changed", key, outfit["name"], outfit["perk"])

	return {
		"success": true,
		"outfit_id": key,
		"outfit_name": outfit["name"],
		"perk": outfit["perk"],
		"bonus_type": outfit["bonus_type"],
		"bonus_value": outfit["bonus_value"]
	}
