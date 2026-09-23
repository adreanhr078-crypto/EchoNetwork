class_name HouseholdManager
extends RefCounted

const GameClock = preload("res://scripts/systems/game_clock.gd")

var households: Dictionary = {
	"HOUSE_001": {
		"id": "HOUSE_001",
		"family_name": "Sato Residence // 佐藤",
		"address": "Minato-Kasumi 2-Chome 4-1",
		"resident_name": "Mika Sato",
		"occupation": "Homemaker (Dr. Sato: Clinic Physician)",
		"ring_count": 0,
		"familiarity": 0,
		"is_home_fixed": true
	},
	"HOUSE_002": {
		"id": "HOUSE_002",
		"family_name": "Tanaka Residence // 田中",
		"address": "Minato-Kasumi 2-Chome 4-3",
		"resident_name": "Aoi Tanaka",
		"occupation": "Hospital Outpatient Nurse (NPC_AOI_01)",
		"ring_count": 0,
		"familiarity": 0,
		"home_start_hour": 19,
		"home_end_hour": 8
	},
	"HOUSE_003": {
		"id": "HOUSE_003",
		"family_name": "Yamada Residence // 山田",
		"address": "Minato-Kasumi 2-Chome 5-2",
		"resident_name": "Daiki Yamada",
		"occupation": "Retired Carpenter (NPC_DAIKI_02)",
		"ring_count": 0,
		"familiarity": 0,
		"stroll_start_hour": 16,
		"stroll_end_hour": 19
	},
	"HOUSE_004": {
		"id": "HOUSE_004",
		"family_name": "Takahashi Residence // 高橋",
		"address": "Minato-Kasumi 2-Chome 5-5",
		"resident_name": "Ren Takahashi",
		"occupation": "Systems Analyst Commuter (NPC_REN_03)",
		"ring_count": 0,
		"familiarity": 0,
		"home_start_hour": 20,
		"home_end_hour": 8
	},
	"HOUSE_005": {
		"id": "HOUSE_005",
		"family_name": "Kobayashi Residence // 小林",
		"address": "Minato-Kasumi 2-Chome 6-1",
		"resident_name": "Haruko Kobayashi",
		"occupation": "Elderly Bonsai Gardener",
		"ring_count": 0,
		"familiarity": 0,
		"wake_hour": 7,
		"sleep_hour": 21
	},
	"HOUSE_ECHO": {
		"id": "HOUSE_ECHO",
		"family_name": "Kasumi Residence // 霞 (Echo's Home)",
		"address": "Minato-Kasumi 2-Chome 7-1",
		"resident_name": "Echo Kasumi",
		"occupation": "Sector 11 Subject EX-000",
		"ring_count": 0,
		"familiarity": 100,
		"is_home_fixed": true
	}
}

func is_resident_at_home(household_id: String, current_hour: int) -> bool:
	if not households.has(household_id):
		return false
	var h = households[household_id]

	match household_id:
		"HOUSE_001":
			return true # Mika Sato is always home with the baby
		"HOUSE_002":
			# Nurse Aoi Tanaka is home 19:00 to 08:00
			return current_hour >= h["home_start_hour"] or current_hour < h["home_end_hour"]
		"HOUSE_003":
			# Daiki Yamada is on stroll between 16:00 and 19:00
			return current_hour < h["stroll_start_hour"] or current_hour >= h["stroll_end_hour"]
		"HOUSE_004":
			# Ren Takahashi is home only after 20:00 until 08:00
			return current_hour >= h["home_start_hour"] or current_hour < h["home_end_hour"]
		"HOUSE_005":
			# Haruko Kobayashi awake between 07:00 and 21:00
			return current_hour >= h["wake_hour"] and current_hour < h["sleep_hour"]
		_:
			return true

func ring_doorbell(household_id: String, current_hour: int = 17, interactor: Node = null) -> Dictionary:
	if not households.has(household_id):
		return {"success": false, "response": "... (Unoccupied dwelling.)"}

	var h = households[household_id]
	h["ring_count"] += 1
	var count: int = h["ring_count"]
	var is_home = is_resident_at_home(household_id, current_hour)
	var response: String = ""

	if not is_home:
		match household_id:
			"HOUSE_002":
				response = "... (Intercom auto-reply: 'Tanaka is currently on duty at Minato-Kasumi Hospital.')"
			"HOUSE_003":
				response = "... (No answer. Daiki's porch light is on, but his slippers are absent from the entrance.)"
			"HOUSE_004":
				response = "... (No answer. The Takahashi apartment windows remain completely dark.)"
			"HOUSE_005":
				response = "... (Silence. The elderly resident is already fast asleep for the night.)"
			_:
				response = "... (No answer. Nobody appears to be home.)"
	else:
		var contact = h.get("contact_count", 0) + 1
		h["contact_count"] = contact
		count = contact

		match household_id:
			"HOUSE_001":
				if count == 1:
					response = "Hello? Can I help you? ...Oh, are you an outpatient from the hospital down the road?"

				elif count == 2:
					response = "Yes? If you're looking for Dr. Sato, he's at the clinic until six."
				elif count == 3:
					response = "Please stop ringing the bell! The baby is sleeping!"
				else:
					response = "... (Silence. No answer. The resident is ignoring the bell.)"
			"HOUSE_002":
				if count == 1:
					response = "Yes? Who is it? ...Oh, Echo! You made it out of the ward. Did you come by for your medication reminder?"
				elif count == 2:
					response = "Rest up tonight, the sea wind can be harsh on recovering patients."
				else:
					response = "I really need to get some sleep before tomorrow's hospital shift..."
			"HOUSE_003":
				if count == 1:
					response = "Yo! Yamada here. What's troubling you so late? Need a hand with anything around the neighborhood?"
				else:
					response = "Take it easy out there, Echo! Keep your coat zipped against the coastal damp."
			"HOUSE_004":
				if count == 1:
					response = "Hello? Sorry, I just got back from the coastal tram. Can I help you?"
				else:
					response = "I'm reheating my dinner right now, talk to you tomorrow!"
			"HOUSE_005":
				if count == 1:
					response = "Oh my, a visitor! Good evening dear. Aren't the hydrangeas blooming beautifully by the seawall?"
				else:
					response = "Be mindful walking near the road at night, dearie."
			"HOUSE_ECHO":
				response = "... (Echo's own childhood home. The door key is in his pocket.)"

	return {
		"success": true,
		"household_id": household_id,
		"family_name": h["family_name"],
		"address": h["address"],
		"resident_name": h["resident_name"],
		"is_home": is_home,
		"ring_count": count,
		"response": response
	}

func get_household(household_id: String) -> Dictionary:
	return households.get(household_id, {})

func serialize() -> Dictionary:
	var result = {}
	for k in households.keys():
		result[k] = households[k].duplicate()
	return {"households": result}

func deserialize(data: Dictionary) -> void:
	if data.has("households") and data["households"] is Dictionary:
		for k in data["households"].keys():
			if households.has(k):
				households[k]["ring_count"] = data["households"][k].get("ring_count", 0)
				households[k]["familiarity"] = data["households"][k].get("familiarity", 0)
