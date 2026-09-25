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
const CoastalOverlookPoint = preload("res://scripts/props/coastal_overlook_point.gd")
const TownNoticeBoard = preload("res://scripts/props/town_notice_board.gd")
const RoadsideShrine = preload("res://scripts/props/roadside_shrine.gd")
const InteractiveTreasureChest = preload("res://scripts/props/interactive_treasure_chest.gd")
const DynamicWeatherCycle = preload("res://scripts/environment/dynamic_weather_cycle.gd")
const KasumiRamenBar = preload("res://scripts/props/kasumi_ramen_bar.gd")
const KasumiCafe = preload("res://scripts/props/kasumi_cafe.gd")
const KasumiPharmacy = preload("res://scripts/props/kasumi_pharmacy.gd")
const MinatoHighSchool = preload("res://scripts/environment/minato_high_school.gd")
const DynamicAIDialogueEngine = preload("res://scripts/systems/dynamic_ai_dialogue_engine.gd")
const RogueAwakener = preload("res://scripts/combat/rogue_awakener.gd")
const AsphaltPuddleReflectionController = preload("res://scripts/environment/asphalt_puddle_reflection_controller.gd")
const CinematicFocusPuller = preload("res://scripts/camera/cinematic_focus_puller.gd")
const TownBountyContractManager = preload("res://scripts/systems/town_bounty_contract_manager.gd")
const VendingGachaController = preload("res://scripts/systems/vending_gacha_controller.gd")
const SeawallRadioPlayer = preload("res://scripts/props/seawall_radio_player.gd")

var game_clock: GameClock = GameClock.new()
var household_manager: HouseholdManager = HouseholdManager.new()
var weather_cycle: DynamicWeatherCycle = null
var dialogue_engine: DynamicAIDialogueEngine = DynamicAIDialogueEngine.new()
var rogue_awakener: RogueAwakener = null
var puddle_reflection_controller: AsphaltPuddleReflectionController = null
var focus_puller: CinematicFocusPuller = null
var bounty_manager: TownBountyContractManager = null
var vending_gacha: VendingGachaController = null
var seawall_radio: SeawallRadioPlayer = null

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
@onready var coastal_overlook: CoastalOverlookPoint = find_child("CoastalOverlookPoint", true, false) as CoastalOverlookPoint
@onready var notice_board: TownNoticeBoard = find_child("TownNoticeBoard", true, false) as TownNoticeBoard
@onready var roadside_shrine: RoadsideShrine = find_child("RoadsideShrine", true, false) as RoadsideShrine
@onready var chests_container: Node3D = find_child("Chests", true, false) as Node3D
@onready var ramen_bar: KasumiRamenBar = find_child("KasumiRamenBar", true, false) as KasumiRamenBar
@onready var cafe: KasumiCafe = find_child("KasumiCafe", true, false) as KasumiCafe
@onready var pharmacy: KasumiPharmacy = find_child("KasumiPharmacy", true, false) as KasumiPharmacy
@onready var high_school: MinatoHighSchool = find_child("MinatoHighSchool", true, false) as MinatoHighSchool

var has_emerged: bool = false
var audio_player: AudioStreamPlayer = null

func _ready() -> void:
	_setup_interactive_props()
	if emergence_trigger:
		emergence_trigger.body_entered.connect(_on_emergence_entered)
	if hospital_doors:
		hospital_doors.doors_opened.connect(_on_doors_opened)

	# Wire households to manager and clock
	_update_house_hours(game_clock.hour)
	if not game_clock.hour_ticked.is_connected(_on_clock_hour_ticked):
		game_clock.hour_ticked.connect(_on_clock_hour_ticked)
	_setup_weather_cycle()

func _on_clock_hour_ticked(hour: int) -> void:
	_update_house_hours(hour)
	if weather_cycle:
		weather_cycle.set_time(hour, game_clock.minute)

func _setup_weather_cycle() -> void:
	if not weather_cycle:
		weather_cycle = find_child("DynamicWeatherCycle", true, false) as DynamicWeatherCycle
		if not weather_cycle:
			weather_cycle = DynamicWeatherCycle.new()
			weather_cycle.name = "DynamicWeatherCycle"
			add_child(weather_cycle)
	if not street_light:
		street_light = find_child("StreetLightGlow", true, false) as OmniLight3D
	if street_light:
		weather_cycle.register_streetlight(street_light)
	if not game_clock.hour_ticked.is_connected(_on_clock_hour_ticked):
		game_clock.hour_ticked.connect(_on_clock_hour_ticked)
	weather_cycle.set_time(game_clock.hour, game_clock.minute)

func get_weather_cycle() -> DynamicWeatherCycle:
	if not weather_cycle:
		_setup_weather_cycle()
	if weather_cycle and weather_cycle.has_method("ensure_setup"):
		weather_cycle.ensure_setup()
	return weather_cycle

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

func _setup_interactive_props() -> void:
	if not coastal_overlook:
		coastal_overlook = find_child("CoastalOverlookPoint", true, false) as CoastalOverlookPoint
		if not coastal_overlook:
			coastal_overlook = CoastalOverlookPoint.new()
			coastal_overlook.name = "CoastalOverlookPoint"
			coastal_overlook.position = Vector3(4.0, 0.2, 5.0)
			add_child(coastal_overlook)

	if not notice_board:
		notice_board = find_child("TownNoticeBoard", true, false) as TownNoticeBoard
		if not notice_board:
			notice_board = TownNoticeBoard.new()
			notice_board.name = "TownNoticeBoard"
			notice_board.position = Vector3(10.0, 0.2, -3.2)
			add_child(notice_board)

	if not roadside_shrine:
		roadside_shrine = find_child("RoadsideShrine", true, false) as RoadsideShrine
		if not roadside_shrine:
			roadside_shrine = RoadsideShrine.new()
			roadside_shrine.name = "RoadsideShrine"
			roadside_shrine.position = Vector3(1.5, 0.2, -4.2)
			add_child(roadside_shrine)

	if not chests_container:
		chests_container = find_child("Chests", true, false) as Node3D
		if not chests_container:
			chests_container = Node3D.new()
			chests_container.name = "Chests"
			add_child(chests_container)

	# 1. Seawall Hidden Common Chest
	var seawall_chest = chests_container.find_child("CHEST_SEAWALL_01", true, false)
	if not seawall_chest:
		var c1 = InteractiveTreasureChest.new()
		c1.name = "CHEST_SEAWALL_01"
		c1.chest_id = "CHEST_SEAWALL_01"
		c1.rarity = InteractiveTreasureChest.ChestRarity.COMMON
		c1.position = Vector3(2.5, 0.2, 5.8)
		chests_container.add_child(c1)

	# 2. Kasumi Mart Alleyway Exquisite Chest
	var konbini_chest = chests_container.find_child("CHEST_KONBINI_ALLEY_02", true, false)
	if not konbini_chest:
		var c2 = InteractiveTreasureChest.new()
		c2.name = "CHEST_KONBINI_ALLEY_02"
		c2.chest_id = "CHEST_KONBINI_ALLEY_02"
		c2.rarity = InteractiveTreasureChest.ChestRarity.EXQUISITE
		c2.position = Vector3(-18.5, 0.2, -7.5)
		chests_container.add_child(c2)

	# 3. Ancient Pine Shrine Precious Chest
	var shrine_chest = chests_container.find_child("CHEST_SHRINE_PINE_03", true, false)
	if not shrine_chest:
		var c3 = InteractiveTreasureChest.new()
		c3.name = "CHEST_SHRINE_PINE_03"
		c3.chest_id = "CHEST_SHRINE_PINE_03"
		c3.rarity = InteractiveTreasureChest.ChestRarity.PRECIOUS
		c3.position = Vector3(0.5, 0.2, -5.5)
		chests_container.add_child(c3)

	# 4. Kasumi Ramen Bar
	if not ramen_bar:
		ramen_bar = find_child("KasumiRamenBar", true, false) as KasumiRamenBar
		if not ramen_bar:
			ramen_bar = KasumiRamenBar.new()
			ramen_bar.name = "KasumiRamenBar"
			ramen_bar.position = Vector3(-12.0, 0.2, 4.0)
			add_child(ramen_bar)

	# 5. Kasumi Cafe & Bakery
	if not cafe:
		cafe = find_child("KasumiCafe", true, false) as KasumiCafe
		if not cafe:
			cafe = KasumiCafe.new()
			cafe.name = "KasumiCafe"
			cafe.position = Vector3(-6.0, 0.2, 8.0)
			add_child(cafe)

	# 6. Kasumi 24/7 Pharmacy
	if not pharmacy:
		pharmacy = find_child("KasumiPharmacy", true, false) as KasumiPharmacy
		if not pharmacy:
			pharmacy = KasumiPharmacy.new()
			pharmacy.name = "KasumiPharmacy"
			pharmacy.position = Vector3(8.0, 0.2, 2.0)
			add_child(pharmacy)

	# 7. Minato High School Campus
	if not high_school:
		high_school = find_child("MinatoHighSchool", true, false) as MinatoHighSchool
		if not high_school:
			high_school = MinatoHighSchool.new()
			high_school.name = "MinatoHighSchool"
			high_school.position = Vector3(25.0, 0.2, -15.0)
			add_child(high_school)

func get_overlook_point() -> CoastalOverlookPoint:
	if not coastal_overlook:
		coastal_overlook = find_child("CoastalOverlookPoint", true, false) as CoastalOverlookPoint
		if not coastal_overlook:
			_setup_interactive_props()
	if coastal_overlook and coastal_overlook.has_method("ensure_setup"):
		coastal_overlook.ensure_setup()
	return coastal_overlook

func get_notice_board() -> TownNoticeBoard:
	if not notice_board:
		notice_board = find_child("TownNoticeBoard", true, false) as TownNoticeBoard
		if not notice_board:
			_setup_interactive_props()
	if notice_board and notice_board.has_method("ensure_setup"):
		notice_board.ensure_setup()
	return notice_board

func get_roadside_shrine() -> RoadsideShrine:
	if not roadside_shrine:
		roadside_shrine = find_child("RoadsideShrine", true, false) as RoadsideShrine
		if not roadside_shrine:
			_setup_interactive_props()
	if roadside_shrine and roadside_shrine.has_method("ensure_setup"):
		roadside_shrine.ensure_setup()
	return roadside_shrine

func get_chests() -> Array:
	var list = []
	if not chests_container:
		chests_container = find_child("Chests", true, false) as Node3D
		if not chests_container:
			_setup_interactive_props()
	if chests_container:
		for child in chests_container.get_children():
			if child is InteractiveTreasureChest or child.has_method("open_chest"):
				if child.has_method("ensure_setup"):
					child.ensure_setup()
				list.append(child)
	return list

func get_chest(target_id: String) -> InteractiveTreasureChest:
	for c in get_chests():
		if c.chest_id == target_id or c.name == target_id:
			return c
	return null

func get_ramen_bar() -> KasumiRamenBar:
	if not ramen_bar:
		_setup_interactive_props()
	return ramen_bar

func get_cafe() -> KasumiCafe:
	if not cafe:
		_setup_interactive_props()
	return cafe

func get_pharmacy() -> KasumiPharmacy:
	if not pharmacy:
		_setup_interactive_props()
	return pharmacy

func get_high_school() -> MinatoHighSchool:
	if not high_school:
		_setup_interactive_props()
	return high_school

func get_dialogue_engine() -> DynamicAIDialogueEngine:
	if not dialogue_engine:
		dialogue_engine = DynamicAIDialogueEngine.new()
		add_child(dialogue_engine)
	return dialogue_engine

func spawn_nocturnal_awakener(hour: int) -> RogueAwakener:
	if not RogueAwakener.is_nocturnal_active(hour):
		return null

	if not rogue_awakener:
		rogue_awakener = RogueAwakener.new()
		rogue_awakener.name = "RogueAwakener"
		rogue_awakener.position = Vector3(-6.5, 0.0, 14.0)
		add_child(rogue_awakener)

	return rogue_awakener

func get_nocturnal_awakener() -> RogueAwakener:
	return rogue_awakener

func get_puddle_reflection_controller() -> AsphaltPuddleReflectionController:
	if not puddle_reflection_controller:
		puddle_reflection_controller = AsphaltPuddleReflectionController.new()
		puddle_reflection_controller.name = "AsphaltPuddleReflectionController"
		add_child(puddle_reflection_controller)
	return puddle_reflection_controller

func get_focus_puller() -> CinematicFocusPuller:
	if not focus_puller:
		focus_puller = CinematicFocusPuller.new()
		focus_puller.name = "CinematicFocusPuller"
		add_child(focus_puller)
	return focus_puller

func get_bounty_manager() -> TownBountyContractManager:
	if not bounty_manager:
		bounty_manager = TownBountyContractManager.new()
		bounty_manager.name = "TownBountyContractManager"
		add_child(bounty_manager)
	return bounty_manager

func get_vending_gacha() -> VendingGachaController:
	if not vending_gacha:
		vending_gacha = VendingGachaController.new()
		vending_gacha.name = "VendingGachaController"
		add_child(vending_gacha)
	return vending_gacha

func get_seawall_radio() -> SeawallRadioPlayer:
	if not seawall_radio:
		seawall_radio = find_child("SeawallRadioPlayer", true, false) as SeawallRadioPlayer
		if not seawall_radio:
			seawall_radio = SeawallRadioPlayer.new()
			seawall_radio.name = "SeawallRadioPlayer"
			seawall_radio.position = Vector3(4.2, 0.2, 5.2)
			add_child(seawall_radio)
	return seawall_radio







