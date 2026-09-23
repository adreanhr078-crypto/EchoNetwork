class_name EchoResidence
extends Node3D

signal house_state_changed(new_state: String)
signal photo_inspected(photo_type: String, memory_text: String)
signal tv_state_changed(is_on: bool)
signal fridge_state_changed(is_open: bool)
signal stove_state_changed(is_lit: bool)
signal cleaning_progress_updated(tasks_done: int, total_tasks: int)
signal rested_in_bed(new_hour: int, restored_hp: float, restored_energy: float)

enum HouseState {
	NEGLECTED,
	RESTORED
}

const InteractableComponent = preload("res://scripts/interaction/interactable_component.gd")
const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const PlayerInventory = preload("res://scripts/systems/player_inventory.gd")
const PlayerNeeds = preload("res://scripts/systems/player_needs.gd")
const GameClock = preload("res://scripts/systems/game_clock.gd")

@export var address: String = "Minato-Kasumi 2-Chome 7-1"
@export var residence_name: String = "Kasumi // Echo's Childhood Home"

var house_state: HouseState = HouseState.NEGLECTED
var photo_father_inspected: bool = false
var photo_mother_inspected: bool = false
var mother_photo_repaired: bool = false
var tv_on: bool = false
var fridge_open: bool = false
var stove_lit: bool = false
var curtains_opened: bool = false
var cleaning_tasks_done: int = 0
const TOTAL_CLEANING_TASKS: int = 3
var fridge_milk_stock: int = 2

var audio_player: AudioStreamPlayer3D = null

# Interior nodes with lazy resolution
var _tv_screen: MeshInstance3D = null
var tv_screen: MeshInstance3D:
	get:
		if not _tv_screen: _tv_screen = find_child("TVScreen", true, false) as MeshInstance3D
		return _tv_screen
	set(val): _tv_screen = val

var _tv_light: OmniLight3D = null
var tv_light: OmniLight3D:
	get:
		if not _tv_light: _tv_light = find_child("TVLight", true, false) as OmniLight3D
		return _tv_light
	set(val): _tv_light = val

var _fridge_door: MeshInstance3D = null
var fridge_door: MeshInstance3D:
	get:
		if not _fridge_door: _fridge_door = find_child("FridgeDoor", true, false) as MeshInstance3D
		return _fridge_door
	set(val): _fridge_door = val

var _fridge_light: OmniLight3D = null
var fridge_light: OmniLight3D:
	get:
		if not _fridge_light: _fridge_light = find_child("FridgeLight", true, false) as OmniLight3D
		return _fridge_light
	set(val): _fridge_light = val

var _stove_flame: MeshInstance3D = null
var stove_flame: MeshInstance3D:
	get:
		if not _stove_flame: _stove_flame = find_child("StoveFlame", true, false) as MeshInstance3D
		return _stove_flame
	set(val): _stove_flame = val

var _stove_light: OmniLight3D = null
var stove_light: OmniLight3D:
	get:
		if not _stove_light: _stove_light = find_child("StoveLight", true, false) as OmniLight3D
		return _stove_light
	set(val): _stove_light = val

var _sunlight: SpotLight3D = null
var sunlight: SpotLight3D:
	get:
		if not _sunlight: _sunlight = find_child("SunlightBeam", true, false) as SpotLight3D
		return _sunlight
	set(val): _sunlight = val

var _mother_photo_broken: Node3D = null
var mother_photo_broken: Node3D:
	get:
		if not _mother_photo_broken: _mother_photo_broken = find_child("MotherPhotoBroken", true, false) as Node3D
		return _mother_photo_broken
	set(val): _mother_photo_broken = val

var _mother_photo_restored: Node3D = null
var mother_photo_restored: Node3D:
	get:
		if not _mother_photo_restored: _mother_photo_restored = find_child("MotherPhotoRestored", true, false) as Node3D
		return _mother_photo_restored
	set(val): _mother_photo_restored = val

var _father_photo: Node3D = null
var father_photo: Node3D:
	get:
		if not _father_photo: _father_photo = find_child("FatherPhoto", true, false) as Node3D
		return _father_photo
	set(val): _father_photo = val

var _dust_layer: Node3D = null
var dust_layer: Node3D:
	get:
		if not _dust_layer:
			_dust_layer = get_node_or_null("DustLayer") as Node3D
			if not _dust_layer:
				_dust_layer = find_child("DustLayer", true, false) as Node3D
		return _dust_layer
	set(val): _dust_layer = val

const FATHER_PHOTO_TEXT: String = (
	"Echo picks up the dust-coated frame. In the photograph, young Echo stands beside Dr. Kinja outside Kasumi Central Lab.\n" +
	"Kinja is smiling warmly with his hand on Echo's shoulder—long before the Singularity experiments tore his humanity apart.\n" +
	"'Dad... you used to smile. Before Sector 11 consumed you.'"
)

const MOTHER_PHOTO_BROKEN_TEXT: String = (
	"On the tatami floor lies a shattered glass frame, face down among scattered shards.\n" +
	"Echo lifts it carefully. It's the only surviving portrait of his mother, taken in the Kasumi plum orchards.\n" +
	"The night Kinja and the Sector 11 enforcers dragged Echo away in the rain, the frame crashed to the floor. Nobody ever came back for it."
)

const MOTHER_PHOTO_RESTORED_TEXT: String = (
	"The repaired portrait of Echo's mother rests gently on the clean wooden altar shelf.\n" +
	"Her gentle smile brings a quiet warmth to the room, untouched by the shadows of Sector 11."
)

const TV_BROADCAST_TEXT: String = (
	"NHK Kasumi Evening Broadcast:\n" +
	"'...Seismic anomalies and electromagnetic pulses continue to register near the Sector 11 offshore perimeter.\n" +
	"The Ministry of Health has issued a reminder for Kasumi ward citizens to observe curfew and report any unauthorized fugitives...'"
)

func _ready() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.max_distance = 15.0
		add_child(audio_player)

	_apply_visual_states()

func _apply_visual_states() -> void:
	if tv_light:
		tv_light.visible = tv_on
	if tv_screen:
		var mat = tv_screen.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.emission_enabled = tv_on
			mat.emission = Color(0.6, 0.8, 1.0) if tv_on else Color.BLACK

	if fridge_light:
		fridge_light.visible = fridge_open
	if fridge_door:
		fridge_door.rotation_degrees.y = -75.0 if fridge_open else 0.0

	if stove_flame:
		stove_flame.visible = stove_lit
	if stove_light:
		stove_light.visible = stove_lit

	if dust_layer:
		dust_layer.visible = (house_state == HouseState.NEGLECTED)

	if mother_photo_broken:
		mother_photo_broken.visible = not mother_photo_repaired
	if mother_photo_restored:
		mother_photo_restored.visible = mother_photo_repaired

	if sunlight:
		sunlight.visible = curtains_opened

func inspect_father_photo(interactor: Node = null) -> Dictionary:
	photo_father_inspected = true
	emit_signal("photo_inspected", "father", FATHER_PHOTO_TEXT)
	return {
		"photo": "father_and_echo",
		"text": FATHER_PHOTO_TEXT,
		"inspected": true
	}

func inspect_mother_photo(interactor: Node = null) -> Dictionary:
	photo_mother_inspected = true
	var txt = MOTHER_PHOTO_RESTORED_TEXT if mother_photo_repaired else MOTHER_PHOTO_BROKEN_TEXT
	emit_signal("photo_inspected", "mother", txt)
	return {
		"photo": "mother",
		"repaired": mother_photo_repaired,
		"text": txt,
		"inspected": true
	}

func toggle_tv(interactor: Node = null) -> Dictionary:
	tv_on = not tv_on
	_apply_visual_states()

	if audio_player:
		if tv_on:
			audio_player.stream = ProceduralCinematicAudio.create_tv_static()
			audio_player.play()
		else:
			audio_player.stop()

	emit_signal("tv_state_changed", tv_on)
	return {
		"tv_on": tv_on,
		"broadcast": TV_BROADCAST_TEXT if tv_on else ""
	}

func toggle_fridge(interactor: Node = null) -> Dictionary:
	fridge_open = not fridge_open
	_apply_visual_states()

	if audio_player:
		audio_player.stream = ProceduralCinematicAudio.create_fridge_door_open()
		audio_player.play()

	emit_signal("fridge_state_changed", fridge_open)
	return {
		"fridge_open": fridge_open,
		"milk_stock": fridge_milk_stock
	}

func take_milk_from_fridge(interactor: Node = null) -> Dictionary:
	if not fridge_open:
		toggle_fridge(interactor)

	if fridge_milk_stock <= 0:
		return {
			"success": false,
			"reason": "fridge_empty",
			"message": "The refrigerator is empty. Only expired condiments remain."
		}

	fridge_milk_stock -= 1

	var inventory: PlayerInventory = null
	if interactor:
		if interactor.get("inventory") is PlayerInventory:
			inventory = interactor.inventory
		elif interactor.has_method("get_inventory"):
			inventory = interactor.get_inventory()

	if inventory:
		inventory.add_item("milk", 1)

	return {
		"success": true,
		"item_id": "milk",
		"remaining_stock": fridge_milk_stock,
		"message": "Echo took a cold glass bottle of Chilled Kasumi Milk."
	}

func toggle_stove(interactor: Node = null) -> Dictionary:
	stove_lit = not stove_lit
	_apply_visual_states()

	if audio_player:
		if stove_lit:
			audio_player.stream = ProceduralCinematicAudio.create_gas_ignite()
			audio_player.play()
		else:
			audio_player.stop()

	emit_signal("stove_state_changed", stove_lit)
	return {
		"stove_lit": stove_lit,
		"message": "Blue flame ignited on the kitchen range." if stove_lit else "Gas burner extinguished."
	}

func clean_house(interactor: Node = null) -> Dictionary:
	if house_state == HouseState.RESTORED:
		return {
			"success": false,
			"house_state": "RESTORED",
			"message": "The house is already clean and warm."
		}

	cleaning_tasks_done += 1

	var task_name: String = ""
	if cleaning_tasks_done == 1:
		task_name = "Dusting living room, wiping shelves, and sweeping away cobwebs."
	elif cleaning_tasks_done == 2:
		task_name = "Gathering broken glass shards, carefully repairing mother's portrait frame, and placing it on the altar."
		mother_photo_repaired = true
	else:
		task_name = "Sweeping tatami mats, tucking the futon, and sliding open the bedroom curtains."
		curtains_opened = true
		house_state = HouseState.RESTORED

	_apply_visual_states()

	if audio_player and curtains_opened:
		audio_player.stream = ProceduralCinematicAudio.create_morning_birds()
		audio_player.play()

	emit_signal("cleaning_progress_updated", cleaning_tasks_done, TOTAL_CLEANING_TASKS)
	if house_state == HouseState.RESTORED:
		emit_signal("house_state_changed", "RESTORED")

	return {
		"success": true,
		"tasks_done": cleaning_tasks_done,
		"total_tasks": TOTAL_CLEANING_TASKS,
		"task_description": task_name,
		"house_state": "RESTORED" if house_state == HouseState.RESTORED else "NEGLECTED",
		"mother_photo_repaired": mother_photo_repaired,
		"curtains_opened": curtains_opened
	}

func restore_entire_house() -> void:
	cleaning_tasks_done = TOTAL_CLEANING_TASKS
	mother_photo_repaired = true
	curtains_opened = true
	house_state = HouseState.RESTORED
	_apply_visual_states()
	emit_signal("house_state_changed", "RESTORED")

func use_bed(interactor: Node = null, clock: Object = null) -> Dictionary:
	# Advance clock by 8 hours to morning (07:00 AM)
	var new_hour: int = 7
	var new_minute: int = 0
	if clock:
		if clock.has_method("set_time"):
			var next_day: int = (clock.day + 1) if ("day" in clock) else 2
			clock.set_time(7, 0, next_day)
		elif clock.has_method("advance_time"):
			clock.advance_time(480.0) # 8 hours
			if "hour" in clock and clock.hour != null:
				new_hour = clock.hour
				new_minute = clock.minute

	# Restore player HP and Energy/Needs to full 100%
	var hp_restored: float = 100.0
	var energy_restored: float = 100.0

	if interactor:
		if "hp" in interactor and interactor.hp != null:
			interactor.hp = interactor.MAX_HP if ("MAX_HP" in interactor) else 200.0
		elif interactor.has_method("heal"):
			interactor.heal(100.0)
		elif "current_hp" in interactor and interactor.current_hp != null:
			interactor.current_hp = interactor.max_hp if ("max_hp" in interactor and interactor.max_hp != null) else 100.0

		# Needs recovery
		var needs: PlayerNeeds = null
		if interactor.get("needs") is PlayerNeeds:
			needs = interactor.needs
		elif interactor.has_method("get_needs"):
			needs = interactor.get_needs()

		if needs:
			needs.restore_energy(100.0)

	if audio_player:
		audio_player.stream = ProceduralCinematicAudio.create_morning_birds()
		audio_player.play()

	emit_signal("rested_in_bed", new_hour, hp_restored, energy_restored)

	return {
		"success": true,
		"time": "%02d:%02d" % [new_hour, new_minute],
		"restored_hp": hp_restored,
		"restored_energy": energy_restored,
		"message": "Echo rested deeply on the tatami futon. Morning birds chirp outside in Kasumi."
	}

func serialize() -> Dictionary:
	return {
		"house_state": "RESTORED" if house_state == HouseState.RESTORED else "NEGLECTED",
		"photo_father_inspected": photo_father_inspected,
		"photo_mother_inspected": photo_mother_inspected,
		"mother_photo_repaired": mother_photo_repaired,
		"tv_on": tv_on,
		"fridge_open": fridge_open,
		"stove_lit": stove_lit,
		"curtains_opened": curtains_opened,
		"cleaning_tasks_done": cleaning_tasks_done,
		"fridge_milk_stock": fridge_milk_stock
	}

func deserialize(data: Dictionary) -> void:
	if data.get("house_state", "") == "RESTORED":
		house_state = HouseState.RESTORED
	else:
		house_state = HouseState.NEGLECTED

	photo_father_inspected = data.get("photo_father_inspected", false)
	photo_mother_inspected = data.get("photo_mother_inspected", false)
	mother_photo_repaired = data.get("mother_photo_repaired", false)
	tv_on = data.get("tv_on", false)
	fridge_open = data.get("fridge_open", false)
	stove_lit = data.get("stove_lit", false)
	curtains_opened = data.get("curtains_opened", false)
	cleaning_tasks_done = int(data.get("cleaning_tasks_done", 0))
	fridge_milk_stock = int(data.get("fridge_milk_stock", 2))

	_apply_visual_states()
