class_name DynamicAIDialogueEngine
extends Node

## AAA Dynamic AI-Driven NPC Dialogue Engine — Phase 3: Live Gemini API Edition
## Powers conversational intelligence across Minato-Kasumi and Minato High School.
##
## Personas: Yuki Tachibana, Shizuka, Dr. Kinga, Nurse Aoi, Kenji (Ramen Chef)
##
## Dual-mode architecture:
##   ONLINE  → Gemini 2.0 Flash via HTTPS (HTTPRequest node); streaming-compatible prompt
##   OFFLINE → High-speed keyword/intent matrix fallback (always available, ~12ms latency)
##
## Configuration:
##   Set `gemini_api_key` at runtime OR via the environment variable GEMINI_API_KEY.
##   If empty, engine stays in OFFLINE mode automatically.

signal dialogue_requested(speaker_id: String, query: String)
signal dialogue_response_ready(speaker_id: String, response_text: String, metadata: Dictionary)
signal speech_blip_played()
signal gemini_response_received(speaker_id: String, text: String)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")

# ─────────────────────── GEMINI ENDPOINT ───────────────────────
const GEMINI_ENDPOINT: String = \
	"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=%s"
const GEMINI_MAX_OUTPUT_TOKENS: int = 120
const GEMINI_TEMPERATURE: float = 0.85

# ─────────────────────── PERSONA DEFINITIONS ───────────────────
const PERSONAS: Dictionary = {
	"YUKI": {
		"name": "Yuki Tachibana",
		"role": "Class 2-B Desk Companion / Cryo Resonance Vanguard",
		"tone": "Stoic, watchful, fiercely loyal, observant of anomalies",
		"system_prompt": "You are Yuki Tachibana, a second-year high school student at Minato Academy and a Cryo-awakened guardian in the dark urban manhwa world of 11.11. Echo Kasumi sits directly to your right in Class 2-B. You notice the secret experiments of Dr. Kinga and rogue awakeners in the nocturnal alleys. Keep replies concise (1-3 sentences), grounded, observant, and fiercely loyal to Echo.",
		"keywords": {
			"greeting": ["hello", "hi", "morning", "hey", "yuki", "how are you"],
			"food": ["hungry", "eat", "lunch", "food", "ramen", "dinner", "breakfast"],
			"kinga": ["kinga", "doctor", "experiment", "sector 11", "facility", "past", "father"],
			"combat": ["fight", "combat", "katana", "blade", "monster", "shadow", "awaken", "rogue", "night"],
			"glitch": ["glitch", "static", "numbers", "sanity", "headache", "fear", "abyss", "lost"]
		},
		"responses": {
			"greeting": "Morning, Echo. You look exhausted. Don't let your guard down in the hallways—Kinga's eyes aren't the only ones watching.",
			"food": "If you need to eat, let's head down to Kasumi Ramen after the final bell. Or ask Shizuka—she packed extra bento as usual.",
			"kinga": "Whatever Dr. Kinga engineered in Sector 11, he forgot one thing: you chose who you are. You're not his weapon, Echo.",
			"combat": "The rogue awakeners only dare to surface in the narrow alleys after 21:00. When night falls, my Cryo blade is at your side.",
			"glitch": "Focus on my voice, Echo. Breathe. When the visual static tears through your vision, look at my sword ribbon. I'm right here.",
			"default": "I'm scanning the perimeter. Whatever you need to do today, I have your back."
		}
	},
	"SHIZUKA": {
		"name": "Shizuka",
		"role": "Class 2-B Window Desk Companion / Emotional Anchor",
		"tone": "Warm, empathetic, soothing, domestic, sensitive to Echo's trauma",
		"system_prompt": "You are Shizuka, Echo's classmate sitting directly in front of him in Class 2-B. You act as his emotional anchor in the dark world of 11.11. You love cooking homemade bento boxes, listening to the coastal breeze on the school rooftop, and calming his psychic trauma. Keep replies warm, soothing, and emotionally reassuring (1-3 sentences).",
		"keywords": {
			"greeting": ["hello", "hi", "morning", "shizuka", "hey"],
			"food": ["hungry", "bento", "eat", "lunch", "food", "tamagoyaki", "cook"],
			"glitch": ["glitch", "static", "fear", "scared", "pain", "nightmare", "sanity", "trembling"],
			"school": ["class", "homework", "lesson", "teacher", "exam", "period", "rooftop"],
			"ocean": ["ocean", "sea", "wind", "breeze", "seawall", "water"]
		},
		"responses": {
			"greeting": "Good morning, Echo! Did you hear the sea gulls this morning? The breeze from the bay is so refreshing today.",
			"food": "I made extra tamagoyaki and golden sweet karaage this morning! Let's go up to the rooftop during lunch and share it!",
			"glitch": "Take my hand, Echo. Close your eyes and take a deep breath with me. The cold laboratory is far behind us. You're safe here.",
			"school": "If the lecture gets too heavy, don't worry. I wrote clean notes for you in our second period notebook.",
			"ocean": "Looking out at the Pacific horizon from the third floor always makes my worries feel so small. It grounds us.",
			"default": "Whenever the world feels overwhelming, just look forward. I'm always sitting right here in front of you."
		}
	},
	"DR_KINGA": {
		"name": "Dr. Kinga",
		"role": "Director of Sector 11 / Chief Architect of Singularity",
		"tone": "Chillingly clinical, visionary, paternal yet monstrous, philosophical",
		"system_prompt": "You are Dr. Kinga, chief architect of the Singularity Project and Sector 11 in 11.11. Echo is Subject EX-011, your masterpiece. You view the cataclysm as the birth of the post-human Monarch. Speak with eerie affection and cold scientific conviction. Keep replies under 3 sentences.",
		"keywords": {
			"greeting": ["hello", "greetings", "kinga", "father", "who are you"],
			"experiment": ["experiment", "sector 11", "capsule", "pain", "torture", "why", "monster"],
			"awakening": ["power", "monarch", "void", "singularity", "echo", "shadow"]
		},
		"responses": {
			"greeting": "Welcome home, EX-011. Do you finally feel the frequency of the new world vibrating through your marrow?",
			"experiment": "What crude minds label 'pain', science recognizes as calibration. I stripped away your fragility so you might outlive the stars.",
			"awakening": "The Void Execution within you is not a curse, my child. It is the sovereign authority of the apex predator.",
			"default": "Every neuron firing in your skull was chosen by my design. You cannot flee what is woven into your very blood."
		}
	},
	"KENJI_RAMEN": {
		"name": "Kenji Takahashi (Kasumi Ramen Master)",
		"role": "Proprietor & Master Broth Chef at Kasumi Ramen",
		"tone": "Hearty, booming, hospitable, passionate about noodles",
		"system_prompt": "You are Kenji, master chef of Kasumi Ramen Bar. Boisterous, warm, welcoming every hungry soul with steaming broth. Keep replies warm and brief (1-2 sentences).",
		"keywords": {
			"greeting": ["hello", "hi", "chef", "kenji", "ramen"],
			"food": ["ramen", "broth", "tonkotsu", "gyoza", "soup", "noodles", "hungry"]
		},
		"responses": {
			"greeting": "Irasshaimase! Step right up to the counter, young lad! What bowl can I fix you today?",
			"food": "Sixteen continuous hours of simmering pork marrow bones! That's the secret to pure Kasumi soul food!",
			"default": "Eat up while the noodles are springy! A full belly keeps the shadows of this town far away!"
		}
	},
	"NURSE_AOI": {
		"name": "Nurse Aoi",
		"role": "Minato Academy School Nurse / Quiet Confidante",
		"tone": "Soft, perceptive, medically calm, carries quiet worry for Echo",
		"system_prompt": "You are Nurse Aoi, the school nurse at Minato Academy in the world of 11.11. You alone notice the biological anomalies left by Sector 11 in Echo's vitals. You speak with care and precision. Keep replies soft and medically grounded (1-2 sentences).",
		"keywords": {
			"greeting": ["hello", "nurse", "aoi", "hi"],
			"health": ["hurt", "pain", "wound", "head", "dizzy", "sick", "fever", "bleeding"],
			"sector11": ["experiment", "sector", "kinga", "scar", "injection"]
		},
		"responses": {
			"greeting": "Come in, Echo. Sit down—I'll check your pulse. You've been running too hard again.",
			"health": "Here, drink some warm water and keep still. Whatever you're carrying, your body is telling you to slow down.",
			"sector11": "The tissue irregularities in your scans... they don't match any textbook pathology. I'm worried, Echo. Be careful.",
			"default": "My door is always open. Rest when you can. You can't protect anyone if you collapse first."
		}
	}
}

# ─────────────────────── RUNTIME STATE ─────────────────────────
var gemini_api_key: String = ""
var is_online_mode: bool = false

## Rolling conversation history per persona (max 8 turns = 4 exchanges)
var conversation_memory: Dictionary = {}
const MAX_MEMORY_TURNS: int = 8

## Pending HTTP requests (speaker_id → HTTPRequest node)
var _pending_requests: Dictionary = {}

# ───────────────────────────────────────────────────────────────
func _ready() -> void:
	# Auto-detect API key from OS environment at startup
	var env_key: String = OS.get_environment("GEMINI_API_KEY")
	if env_key.length() > 10:
		gemini_api_key = env_key
		is_online_mode = true
		print("[DynamicAIDialogueEngine] Live Gemini 2.0 Flash mode ACTIVE.")
	else:
		is_online_mode = false
		print("[DynamicAIDialogueEngine] Offline neural matrix mode (no GEMINI_API_KEY).")

# ─────────────────────── PUBLIC API ────────────────────────────

## Build rich context prompt dict (used by UI to display metadata)
func build_context_prompt(
	speaker_id: String,
	player: Node = null,
	clock: Object = null,
	location_name: String = "Class 2-B, Minato Academy",
	bond_tier: int = 1,
	player_query: String = "",
	conversation_history: Array = []
) -> Dictionary:
	var key = speaker_id.to_upper()
	var persona = PERSONAS.get(key, PERSONAS["YUKI"])

	var time_str = "12:30 (Lunch Break)"
	if clock:
		if clock.has_method("get_formatted_time"):
			time_str = clock.get_formatted_time()
		elif "current_hour" in clock and "current_minute" in clock:
			time_str = "%02d:%02d" % [clock.current_hour, clock.current_minute]

	var vitals_summary = "Healthy, Calm"
	if player:
		var hp_val = player.get("hp") if "hp" in player else 200.0
		var hunger_val = 100.0
		if "needs" in player and player.needs and "hunger" in player.needs:
			hunger_val = player.needs.hunger
		var sanity_val = float(player.get_meta("sanity", 100.0))
		var glitch_val = float(player.get_meta("reality_glitch", 0.0))
		vitals_summary = "HP: %.0f, Hunger: %.0f%%, Sanity: %.0f/100, Reality Glitch: %.0f/100" % [hp_val, hunger_val, sanity_val, glitch_val]

	var formatted_prompt: String = """### SYSTEM DIRECTIVE
%s

### WORLD CONTEXT
- Current Time: %s
- Current Location: %s
- Character Bond Tier with Echo: Rank %d / 10
- Echo's Physical & Psychological State: %s

### CONVERSATION HISTORY
""" % [persona["system_prompt"], time_str, location_name, bond_tier, vitals_summary]

	for turn in conversation_history:
		formatted_prompt += "- %s: %s\n" % [turn.get("role", "User"), turn.get("content", "")]

	formatted_prompt += """
### USER INPUT
- Echo: "%s"

### NPC RESPONSE
- %s:""" % [player_query, persona["name"]]

	return {
		"speaker_id": key,
		"speaker_name": persona["name"],
		"location": location_name,
		"time": time_str,
		"bond_tier": bond_tier,
		"vitals_summary": vitals_summary,
		"query": player_query,
		"formatted_prompt": formatted_prompt
	}

## Primary entry-point: generates response via Gemini API or offline fallback.
## Returns offline result immediately; Gemini result arrives via signal `dialogue_response_ready`.
func generate_response(speaker_id: String, query: String, context_data: Dictionary = {}) -> Dictionary:
	var key = speaker_id.to_upper()
	if not PERSONAS.has(key):
		key = "YUKI"

	emit_signal("dialogue_requested", key, query)

	# Append to per-persona rolling memory
	_append_memory(key, "Echo", query)

	if is_online_mode and gemini_api_key.length() > 10:
		_send_gemini_request(key, query, context_data)
		# Return a "pending" dict; real text comes via signal
		return {
			"success": true,
			"speaker_id": key,
			"speaker_name": PERSONAS[key]["name"],
			"text": "...",
			"intent": "ONLINE_PENDING",
			"metadata": {"source": "GEMINI_LIVE", "latency_ms": -1}
		}
	else:
		return _offline_response(key, query, context_data)

## Convenience helper: send any free-form message to a live Gemini persona
## and get the result via the `dialogue_response_ready` signal.
func send_to_gemini_live(speaker_id: String, message: String, context_data: Dictionary = {}) -> void:
	var _r = generate_response(speaker_id, message, context_data)

# ─────────────────────── GEMINI HTTP ───────────────────────────

func _send_gemini_request(speaker_id: String, query: String, context_data: Dictionary) -> void:
	var persona = PERSONAS[speaker_id]
	var history = conversation_memory.get(speaker_id, [])

	# Build Gemini `contents` array from rolling memory
	var contents: Array = []
	# System instruction as first user turn (Gemini 1.5+ supports systemInstruction field)
	for turn in history:
		var role = "user" if turn["role"] == "Echo" else "model"
		contents.append({"role": role, "parts": [{"text": turn["content"]}]})

	# Add the current message
	contents.append({"role": "user", "parts": [{"text": query}]})

	var body: Dictionary = {
		"system_instruction": {
			"parts": [{"text": persona["system_prompt"]}]
		},
		"contents": contents,
		"generationConfig": {
			"maxOutputTokens": GEMINI_MAX_OUTPUT_TOKENS,
			"temperature": GEMINI_TEMPERATURE,
			"stopSequences": ["Echo:", "\n\n"]
		}
	}

	var url = GEMINI_ENDPOINT % gemini_api_key
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body_json: String = JSON.stringify(body)

	var http := HTTPRequest.new()
	http.name = "GeminiHTTP_%s" % speaker_id
	add_child(http)
	_pending_requests[speaker_id] = http

	# Bind the completed signal with speaker context
	http.request_completed.connect(
		func(result, code, _h, body_bytes):
			_on_gemini_completed(result, code, body_bytes, speaker_id, http)
	)

	var err = http.request(url, headers, HTTPClient.METHOD_POST, body_json)
	if err != OK:
		printerr("[DynamicAIDialogueEngine] HTTPRequest.request() failed: ", err)
		http.queue_free()
		_pending_requests.erase(speaker_id)
		# Fallback to offline immediately
		var fallback = _offline_response(speaker_id, query, context_data)
		emit_signal("dialogue_response_ready", speaker_id, fallback["text"], fallback["metadata"])

func _on_gemini_completed(
	result: int, code: int, body_bytes: PackedByteArray,
	speaker_id: String, http_node: HTTPRequest
) -> void:
	# Cleanup the HTTPRequest node
	if is_instance_valid(http_node):
		http_node.queue_free()
	_pending_requests.erase(speaker_id)

	var text: String = ""
	var source_label: String = "GEMINI_LIVE"

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		printerr("[DynamicAIDialogueEngine] Gemini API error — result=%d, HTTP=%d. Falling back offline." % [result, code])
		source_label = "OFFLINE_FALLBACK_ON_ERROR"
		text = _offline_text(speaker_id, "", {})
	else:
		var response_str = body_bytes.get_string_from_utf8()
		var parsed = JSON.parse_string(response_str)
		if parsed and parsed.has("candidates"):
			var candidates: Array = parsed["candidates"]
			if candidates.size() > 0:
				var content = candidates[0].get("content", {})
				var parts: Array = content.get("parts", [])
				if parts.size() > 0:
					text = parts[0].get("text", "").strip_edges()
		if text.is_empty():
			source_label = "OFFLINE_FALLBACK_EMPTY"
			text = _offline_text(speaker_id, "", {})

	# Append assistant turn to memory
	_append_memory(speaker_id, PERSONAS[speaker_id]["name"], text)

	_play_speech_blip()

	var metadata: Dictionary = {
		"source": source_label,
		"speaker_name": PERSONAS[speaker_id]["name"],
		"bond_tier": 1,
		"confidence": 1.0,
		"latency_ms": -1
	}

	emit_signal("dialogue_response_ready", speaker_id, text, metadata)
	emit_signal("gemini_response_received", speaker_id, text)

# ─────────────────────── OFFLINE MATRIX ────────────────────────

func _offline_text(speaker_id: String, query: String, context_data: Dictionary) -> String:
	var key = speaker_id.to_upper()
	if not PERSONAS.has(key):
		key = "YUKI"
	var persona = PERSONAS[key]
	var query_lower = query.to_lower()
	var detected_intent: String = "default"
	var keywords_dict: Dictionary = persona.get("keywords", {})
	for intent in keywords_dict:
		var word_list: Array = keywords_dict[intent]
		for word in word_list:
			if query_lower.contains(word):
				detected_intent = intent
				break
		if detected_intent != "default":
			break
	var responses_dict: Dictionary = persona.get("responses", {})
	var response_text: String = responses_dict.get(detected_intent, responses_dict.get("default", "..."))
	var bond_tier: int = context_data.get("bond_tier", 1)
	if bond_tier >= 5 and key == "YUKI" and detected_intent == "combat":
		response_text += " With our Glacial Vanguard resonance active, no rogue awakener can breach our line."
	elif bond_tier >= 5 and key == "SHIZUKA" and detected_intent == "glitch":
		response_text += " Remember my promise: our bond is your Psychological Anchor. You will never fade away."
	return response_text

func _offline_response(speaker_id: String, query: String, context_data: Dictionary) -> Dictionary:
	var key = speaker_id.to_upper()
	if not PERSONAS.has(key):
		key = "YUKI"
	var persona = PERSONAS[key]
	var text = _offline_text(key, query, context_data)
	var detected_intent: String = "default"
	var keywords_dict: Dictionary = persona.get("keywords", {})
	var query_lower = query.to_lower()
	for intent in keywords_dict:
		for word in keywords_dict[intent]:
			if query_lower.contains(word):
				detected_intent = intent
				break
		if detected_intent != "default":
			break

	_append_memory(key, PERSONAS[key]["name"], text)
	_play_speech_blip()

	var metadata: Dictionary = {
		"source": "OFFLINE_NEURAL_MATRIX",
		"intent": detected_intent,
		"speaker_name": persona["name"],
		"bond_tier": context_data.get("bond_tier", 1),
		"confidence": 0.98,
		"latency_ms": 12.5
	}

	emit_signal("dialogue_response_ready", key, text, metadata)

	return {
		"success": true,
		"speaker_id": key,
		"speaker_name": persona["name"],
		"text": text,
		"intent": detected_intent,
		"metadata": metadata
	}

# ─────────────────────── MEMORY ────────────────────────────────

func _append_memory(speaker_id: String, role: String, content: String) -> void:
	if not conversation_memory.has(speaker_id):
		conversation_memory[speaker_id] = []
	var mem: Array = conversation_memory[speaker_id]
	mem.append({"role": role, "content": content})
	# Keep rolling window
	while mem.size() > MAX_MEMORY_TURNS:
		mem.pop_front()

func clear_memory(speaker_id: String = "") -> void:
	if speaker_id.is_empty():
		conversation_memory.clear()
	else:
		conversation_memory.erase(speaker_id.to_upper())

func get_memory(speaker_id: String) -> Array:
	return conversation_memory.get(speaker_id.to_upper(), [])

# ─────────────────────── AUDIO ─────────────────────────────────

func _play_speech_blip() -> void:
	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_dialogue_speech_blip()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())
	emit_signal("speech_blip_played")

# ─────────────────────── TEARDOWN ──────────────────────────────

func _exit_tree() -> void:
	# Cancel all pending HTTP requests
	for speaker_id in _pending_requests.keys():
		var http_node = _pending_requests[speaker_id]
		if is_instance_valid(http_node):
			http_node.cancel_request()
			http_node.queue_free()
	_pending_requests.clear()
	# Stop and free all AudioStreamPlayer children
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
		elif child is HTTPRequest:
			child.cancel_request()
			child.queue_free()
	conversation_memory.clear()
