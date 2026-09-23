class_name EconomyManager
extends RefCounted

signal yen_changed(new_balance: int, delta: int)

var yen_balance: int = 1000

func get_yen() -> int:
	return yen_balance

func has_funds(amount: int) -> bool:
	return yen_balance >= amount

func spend_yen(amount: int) -> bool:
	if amount <= 0:
		return true
	if not has_funds(amount):
		return false
	yen_balance -= amount
	emit_signal("yen_changed", yen_balance, -amount)
	return true

func add_yen(amount: int) -> void:
	if amount > 0:
		yen_balance += amount
		emit_signal("yen_changed", yen_balance, amount)

func serialize() -> Dictionary:
	return {"yen": yen_balance}

func deserialize(data: Dictionary) -> void:
	if data.has("yen"):
		yen_balance = int(data["yen"])
