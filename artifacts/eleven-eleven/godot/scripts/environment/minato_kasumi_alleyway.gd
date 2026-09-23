class_name MinatoKasumiAlleyway
extends Node3D

signal street_emerged()
signal shadow_step_tutorial_triggered()
signal ocean_view_inspected()
signal exterior_revealed()

const HospitalSlidingDoors = preload("res://scripts/props/hospital_sliding_doors.gd")
const MinatoVendingMachine = preload("res://scripts/props/minato_vending_machine.gd")
const ResidentialHouse = preload("res://scripts/props/residential_house.gd")
const MinatoNPC = preload("res://scripts/characters/minato_npc.gd")
const GameClock = preload("res://scripts/systems/game_clock.gd")
const HouseholdManager = preload("res://scripts/systems/household_manager.gd")
const KonbiniStore = preload("res://scripts/props/konbini_store.gd")
const EchoResidence = preload("res://scripts/props/echo_residence.gd")
const RideableVehicle = preload("res://scripts/vehicles/rideable_vehicle.gd")

var game_clock: GameClock = GameClock.new()
var household_manager: HouseholdManager = HouseholdManager.new()

@onready var street_light: OmniLight3D = find_child("StreetLightGlow", true, false) as OmniLight3D
@onready var vending_glow: OmniLight3D = find_child("VendingGlow", true, false) as OmniLight3D
@onready var ocean_ambience: Node = find_child("OceanAmbience", true, false)
@onready var emergence_trigger: Area3D = find_child("EmergenceTrigger", true, false) as Area3D
@onready var hospital_doors = find_child("HospitalSlidingDoors", true, false)
@onready var vending_machine = find_child("MinatoVendingMachine", true, false)
@onready var sato_house = find_child("ResidentialHouse", true, false)
@onready var konbini_store = find_child("KonbiniStore", true, false)
@onready var echo_residence = find_child("EchoResidence", true, false)
@onready var houses_container: Node3D = find_child("Households", true, false) as Node3D
@onready var npc_container: Node3D = find_child("NPCs", true, false) as Node3D
@onready var vehicles_container: Node3D = find_child("Vehicles", true, false) as Node3D


var has_emerged: bool = false
var audio_player: AudioStreamPlayer = null

func _ready() -> void:
	if emergence_trigger:
		emergence_trigger.body_entered.connect(_on_emergence_entered)
	if hospital_doors:
		hospital_doors.doors_opened.connect(_on_doors_opened)

	# Wire households to manager and clock
	_update_house_hours(game_clock.hour)
	game_clock.hour_ticked.connect(_update_house_hours)

func _update_house_hours(hour: int) -> void:
	for house in get_houses():
		house.household_manager = household_manager
		house.current_hour = hour

func _on_doors_opened() -> void:
	emit_signal("exterior_revealed")
	play_coastal_ambience()

func _on_emergence_entered(body: Node) -> void:
	if has_emerged:
		return
	if body is EchoPlayer or body.is_in_group("player") or body.has_method("perform_attack"):
		has_emerged = true
		emit_signal("street_emerged")
		
		# Unlock Shadow Step on Echo upon emerging into reality
		if body.has_method("unlock_shadow_step"):
			body.unlock_shadow_step()
			emit_signal("shadow_step_tutorial_triggered")

func play_coastal_ambience() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer.new()
		add_child(audio_player)
	if audio_player and not audio_player.playing:
		audio_player.stream = ProceduralCinematicAudio.create_ocean_coastal_breeze()
		audio_player.volume_db = -6.0
		audio_player.play()

func get_clock() -> GameClock:
	return game_clock

func get_household_manager() -> HouseholdManager:
	return household_manager

func get_konbini() -> KonbiniStore:
	if not konbini_store:
		konbini_store = find_child("KonbiniStore", true, false) as KonbiniStore
	return konbini_store

func get_houses() -> Array:
	var list = []
	if not houses_container:
		houses_container = find_child("Households", true, false) as Node3D
	if houses_container:
		for child in houses_container.get_children():
			if child.has_method("ring_doorbell") or child.get("household_id") != null:
				list.append(child)
	if not sato_house:
		sato_house = find_child("ResidentialHouse", true, false)
	if sato_house and not list.has(sato_house):
		list.append(sato_house)
	return list

func get_house(target_id: String):
	for h in get_houses():
		var hid = h.get("household_id")
		if hid == target_id or (target_id == "HOUSE_001" and (hid == "HOUSE_SATO_01" or hid == "HOUSE_001")):
			return h
	return null


func get_npcs() -> Array:
	var list = []
	if not npc_container:
		npc_container = find_child("NPCs", true, false) as Node3D
	if npc_container:
		for child in npc_container.get_children():
			if child is MinatoNPC:
				list.append(child)
	
	# Also include Konbini clerk if instantiated
	var konbini = get_konbini()
	if konbini:
		var clerk = konbini.find_child("ClerkHana", true, false)
		if clerk is MinatoNPC and not list.has(clerk):
			list.append(clerk)

	return list

func get_npc(target_id: String) -> MinatoNPC:
	for npc in get_npcs():
		if npc.npc_id == target_id:
			return npc
	return null

func get_npc_count() -> int:
	return get_npcs().size()

func get_echo_residence() -> EchoResidence:
	if not echo_residence:
		echo_residence = find_child("EchoResidence", true, false) as EchoResidence
	return echo_residence

func get_vehicles() -> Array:
	var list = []
	if not vehicles_container:
		vehicles_container = find_child("Vehicles", true, false) as Node3D
	if vehicles_container:
		for child in vehicles_container.get_children():
			if child is RideableVehicle or child.has_method("mount"):
				list.append(child)
	return list

func get_vehicle(type_or_name) -> Object:
	for v in get_vehicles():
		if type_or_name is String and v.get("vehicle_name") == type_or_name:
			return v
		elif type_or_name is int and v.get("vehicle_type") == type_or_name:
			return v
	return null

