class_name PlayerInventory
extends RefCounted

signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal item_consumed(item_id: String, effect: Dictionary)

const ITEM_DEFINITIONS := {
	"water": {
		"name": "Natural Mineral Water // 天然水",
		"desc": "Cold, refreshing spring water from Mount Kasumi.",
		"category": "drink",
		"price": 120,
		"thirst_restore": 40.0,
		"energy_restore": 0.0,
		"stamina_restore": 25.0
	},
	"tea": {
		"name": "Iced Green Tea // 緑茶",
		"desc": "Traditional unsweetened brewed green tea in a chilled can.",
		"category": "drink",
		"price": 140,
		"thirst_restore": 45.0,
		"energy_restore": 5.0,
		"stamina_restore": 35.0
	},
	"juice": {
		"name": "Kasumi Citrus Juice // 柑橘ジュース",
		"desc": "Locally harvested sweet-tart Japanese citrus blend.",
		"category": "drink",
		"price": 160,
		"thirst_restore": 50.0,
		"energy_restore": 10.0,
		"stamina_restore": 45.0
	},
	"coffee": {
		"name": "Boss Boss Drip Coffee // ドリップコーヒー",
		"desc": "Rich roasted black canned coffee with a sharp aroma.",
		"category": "drink",
		"price": 130,
		"thirst_restore": 30.0,
		"energy_restore": 25.0,
		"stamina_restore": 20.0
	},
	"energy_drink": {
		"name": "Kasumi Energy // カスミエナジー",
		"desc": "High-taurine carbonated stimulant drink for late nights.",
		"category": "drink",
		"price": 210,
		"thirst_restore": 35.0,
		"energy_restore": 60.0,
		"stamina_restore": 50.0
	},
	"onigiri": {
		"name": "Salmon Onigiri // 鮭おにぎり",
		"desc": "Savory grilled salmon wrapped in seasoned rice and crispy nori.",
		"category": "food",
		"price": 150,
		"hunger_restore": 35.0,
		"energy_restore": 15.0,
		"thirst_restore": 0.0
	},
	"milk": {
		"name": "Chilled Kasumi Milk // 冷たい牛乳",
		"desc": "Fresh bottle of chilled whole milk from Hokkaido.",
		"category": "drink",
		"price": 110,
		"thirst_restore": 45.0,
		"energy_restore": 20.0,
		"stamina_restore": 30.0
	},
	"sando": {
		"name": "Egg Salad Sando // たまごサンド",
		"desc": "Creamy Japanese egg salad on crustless milk bread.",
		"category": "food",
		"price": 220,
		"hunger_restore": 45.0,
		"energy_restore": 20.0,
		"thirst_restore": 0.0
	},
	"bento": {
		"name": "Tonkatsu Bento // とんかつ弁当",
		"desc": "Crispy breaded pork cutlet served with rice, pickles, and sauce.",
		"category": "food",
		"price": 540,
		"hunger_restore": 80.0,
		"energy_restore": 35.0,
		"thirst_restore": 0.0
	},
	"ramen": {
		"name": "Shoyu Cup Ramen // 醤油ラーメン",
		"desc": "Instant soy-broth noodles with scallions and bamboo shoots.",
		"category": "food",
		"price": 180,
		"hunger_restore": 50.0,
		"energy_restore": 15.0,
		"thirst_restore": -10.0
	},
	"pocky": {
		"name": "Matcha Chocolate Snack // 抹茶チョコ",
		"desc": "Crispy biscuit sticks generously coated in sweet Uji matcha chocolate.",
		"category": "food",
		"price": 160,
		"hunger_restore": 20.0,
		"energy_restore": 30.0,
		"thirst_restore": 0.0
	},
	"dark_neural_fragment": {
		"name": "Dark Neural Fragment // 暗黒神経の破片",
		"desc": "Crystallized neural residue from Dr. Kinga's illicit stasis experiments.",
		"category": "lore_artifact",
		"price": 2500,
		"hunger_restore": 0.0,
		"energy_restore": 0.0,
		"thirst_restore": 0.0
	},
	"astral_resonance_shard": {
		"name": "Astral Resonance Shard // 星屑の残照",
		"desc": "Pristine dimensional crystal forged by high-resonance awakening. Can be exchanged for rare fates.",
		"category": "currency",
		"price": 0,
		"hunger_restore": 0.0,
		"energy_restore": 0.0,
		"thirst_restore": 0.0
	},
	"capsule_golden_tanuki": {
		"name": "Golden Tanuki Lucky Mascot // 金の狸",
		"desc": "Ultra-rare gold-plated tanuki figurine from the Kasumi gacha machine.",
		"category": "collectible",
		"price": 3000,
		"hunger_restore": 0.0,
		"energy_restore": 0.0,
		"thirst_restore": 0.0
	},
	"capsule_mini_katana": {
		"name": "Miniature Shadow Katana Figurine // ミニ刀",
		"desc": "Detailed die-cast miniature katana with a crimson scabbard.",
		"category": "collectible",
		"price": 1200,
		"hunger_restore": 0.0,
		"energy_restore": 0.0,
		"thirst_restore": 0.0
	},
	"capsule_crystal_bell": {
		"name": "Mount Kasumi Crystal Wind Bell // 風鈴",
		"desc": "Hand-blown glass chime that rings with a crisp coastal melody.",
		"category": "collectible",
		"price": 800,
		"hunger_restore": 0.0,
		"energy_restore": 0.0,
		"thirst_restore": 0.0
	},
	"capsule_sakura_badge": {
		"name": "Minato Academy Enamel Pin // 桜の校章",
		"desc": "Official polished brass and sakura enamel pin of Minato High School.",
		"category": "collectible",
		"price": 600,
		"hunger_restore": 0.0,
		"energy_restore": 0.0,
		"thirst_restore": 0.0
	},
	"capsule_milk_cap": {
		"name": "Retro Strawberry Milk Bottle Cap // 苺牛乳キャップ",
		"desc": "Collectible paper milk bottle cap with a retro seal.",
		"category": "collectible",
		"price": 250,
		"hunger_restore": 0.0,
		"energy_restore": 0.0,
		"thirst_restore": 0.0
	}
}

var items: Dictionary = {}

func add_item(item_id: String, count: int = 1) -> bool:
	if count <= 0:
		return false
	var current = items.get(item_id, 0)
	items[item_id] = current + count
	emit_signal("item_added", item_id, count)
	return true

func remove_item(item_id: String, count: int = 1) -> bool:
	if count <= 0:
		return false
	var current = items.get(item_id, 0)
	if current < count:
		return false
	items[item_id] = current - count
	if items[item_id] <= 0:
		items.erase(item_id)
	emit_signal("item_removed", item_id, count)
	return true

func has_item(item_id: String) -> bool:
	return items.get(item_id, 0) > 0

func get_item_count(item_id: String) -> int:
	return items.get(item_id, 0)

func get_all_items() -> Dictionary:
	return items.duplicate()

func use_item(item_id: String, target_actor: Node = null) -> Dictionary:
	if not has_item(item_id):
		return {"success": false, "reason": "item_not_found"}
	
	var def = ITEM_DEFINITIONS.get(item_id, {})
	var category = def.get("category", "consumable")
	var hunger_gain = def.get("hunger_restore", 0.0)
	var thirst_gain = def.get("thirst_restore", 0.0)
	var energy_gain = def.get("energy_restore", 0.0)
	var stamina_gain = def.get("stamina_restore", 0.0)
	
	# Apply Stamina effect to target actor
	if stamina_gain > 0.0:
		if target_actor and target_actor.has_method("restore_stamina"):
			target_actor.restore_stamina(stamina_gain)
		elif target_actor and "stamina" in target_actor:
			target_actor.stamina = min(100.0, target_actor.stamina + stamina_gain)

	# Apply Needs effect to target actor
	if target_actor:
		if target_actor.has_method("restore_hunger") and hunger_gain > 0.0:
			target_actor.restore_hunger(hunger_gain)
		if target_actor.has_method("restore_thirst") and thirst_gain != 0.0:
			target_actor.restore_thirst(thirst_gain)
		if target_actor.has_method("restore_energy") and energy_gain > 0.0:
			target_actor.restore_energy(energy_gain)
		elif "needs" in target_actor and target_actor.needs != null:
			if hunger_gain > 0.0:
				target_actor.needs.consume_food(hunger_gain, energy_gain, thirst_gain)
			elif thirst_gain > 0.0:
				target_actor.needs.consume_drink(thirst_gain, energy_gain)
	
	remove_item(item_id, 1)
	
	var effect = {
		"success": true,
		"item_id": item_id,
		"item_name": def.get("name", item_id),
		"category": category,
		"hunger_gain": hunger_gain,
		"thirst_gain": thirst_gain,
		"energy_gain": energy_gain,
		"stamina_gain": stamina_gain,
		"message": "Consumed %s." % def.get("name", item_id)
	}
	emit_signal("item_consumed", item_id, effect)
	return effect

func serialize() -> Dictionary:
	return {"items": items.duplicate()}

func deserialize(data: Dictionary) -> void:
	if data.has("items") and data["items"] is Dictionary:
		items = data["items"].duplicate()
