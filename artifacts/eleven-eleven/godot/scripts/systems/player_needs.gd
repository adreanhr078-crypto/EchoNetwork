class_name PlayerNeeds
extends RefCounted

signal needs_changed(hunger: float, thirst: float, energy: float)
signal hunger_state_changed(new_state: int)
signal thirst_state_changed(new_state: int)
signal energy_state_changed(new_state: int)

enum HungerState {
	SATIATED,     # > 75
	NORMAL,       # 40 - 75
	HUNGRY,       # 15 - 40
	VERY_HUNGRY   # < 15
}

enum ThirstState {
	HYDRATED,     # > 75
	NORMAL,       # 40 - 75
	THIRSTY,      # 15 - 40
	VERY_THIRSTY  # < 15
}

enum EnergyState {
	ENERGETIC,    # > 75
	NORMAL,       # 40 - 75
	TIRED,        # 15 - 40
	EXHAUSTED     # < 15
}

const MAX_NEED: float = 100.0

var hunger: float = 85.0
var thirst: float = 85.0
var energy: float = 90.0

var _last_hunger_state: HungerState = HungerState.SATIATED
var _last_thirst_state: ThirstState = ThirstState.HYDRATED
var _last_energy_state: EnergyState = EnergyState.ENERGETIC

func _init() -> void:
	_update_states(false)

func get_hunger_state() -> HungerState:
	if hunger > 75.0:
		return HungerState.SATIATED
	elif hunger >= 40.0:
		return HungerState.NORMAL
	elif hunger >= 15.0:
		return HungerState.HUNGRY
	else:
		return HungerState.VERY_HUNGRY

func get_thirst_state() -> ThirstState:
	if thirst > 75.0:
		return ThirstState.HYDRATED
	elif thirst >= 40.0:
		return ThirstState.NORMAL
	elif thirst >= 15.0:
		return ThirstState.THIRSTY
	else:
		return ThirstState.VERY_THIRSTY

func get_energy_state() -> EnergyState:
	if energy > 75.0:
		return EnergyState.ENERGETIC
	elif energy >= 40.0:
		return EnergyState.NORMAL
	elif energy >= 15.0:
		return EnergyState.TIRED
	else:
		return EnergyState.EXHAUSTED

func process_needs(delta_seconds: float, is_running: bool = false) -> void:
	# Life simulation rates: realistic and non-intrusive
	var hunger_decay = 0.05 * delta_seconds
	var thirst_decay = 0.08 * delta_seconds
	var energy_decay = (0.07 if is_running else 0.04) * delta_seconds

	hunger = max(0.0, hunger - hunger_decay)
	thirst = max(0.0, thirst - thirst_decay)
	energy = max(0.0, energy - energy_decay)

	_update_states(true)

func consume_food(hunger_gain: float, energy_gain: float = 0.0, thirst_delta: float = 0.0) -> Dictionary:
	var prev_hunger = hunger
	var prev_energy = energy
	var prev_thirst = thirst

	hunger = clamp(hunger + hunger_gain, 0.0, MAX_NEED)
	energy = clamp(energy + energy_gain, 0.0, MAX_NEED)
	thirst = clamp(thirst + thirst_delta, 0.0, MAX_NEED)

	_update_states(true)

	return {
		"hunger_gain": hunger - prev_hunger,
		"energy_gain": energy - prev_energy,
		"thirst_delta": thirst - prev_thirst,
		"hunger": hunger,
		"energy": energy,
		"thirst": thirst
	}

func consume_drink(thirst_gain: float, energy_gain: float = 0.0) -> Dictionary:
	var prev_thirst = thirst
	var prev_energy = energy

	thirst = clamp(thirst + thirst_gain, 0.0, MAX_NEED)
	energy = clamp(energy + energy_gain, 0.0, MAX_NEED)

	_update_states(true)

	return {
		"thirst_gain": thirst - prev_thirst,
		"energy_gain": energy - prev_energy,
		"thirst": thirst,
		"energy": energy
	}

func restore_energy(amount: float) -> void:
	energy = clamp(energy + amount, 0.0, MAX_NEED)
	_update_states(true)

func is_hungry() -> bool:
	return get_hunger_state() >= HungerState.HUNGRY

func is_thirsty() -> bool:
	return get_thirst_state() >= ThirstState.THIRSTY

func is_exhausted() -> bool:
	return get_energy_state() == EnergyState.EXHAUSTED

func _update_states(emit_signals: bool) -> void:
	var cur_h = get_hunger_state()
	var cur_t = get_thirst_state()
	var cur_e = get_energy_state()

	if emit_signals:
		emit_signal("needs_changed", hunger, thirst, energy)
		if cur_h != _last_hunger_state:
			emit_signal("hunger_state_changed", cur_h)
		if cur_t != _last_thirst_state:
			emit_signal("thirst_state_changed", cur_t)
		if cur_e != _last_energy_state:
			emit_signal("energy_state_changed", cur_e)

	_last_hunger_state = cur_h
	_last_thirst_state = cur_t
	_last_energy_state = cur_e

func serialize() -> Dictionary:
	return {
		"hunger": hunger,
		"thirst": thirst,
		"energy": energy
	}

func deserialize(data: Dictionary) -> void:
	if data.has("hunger"):
		hunger = float(data["hunger"])
	if data.has("thirst"):
		thirst = float(data["thirst"])
	if data.has("energy"):
		energy = float(data["energy"])
	_update_states(true)
