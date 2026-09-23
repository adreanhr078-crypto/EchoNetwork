class_name KingaTortureSequence
extends Node3D

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const CineCameraDirector = preload("res://scripts/cinematics/cine_camera_director.gd")
const VolumetricFogController = preload("res://scripts/effects/volumetric_fog_controller.gd")
const HospitalEgressHatch = preload("res://scripts/props/hospital_egress_hatch.gd")
const RealityGlitchOverlay = preload("res://scripts/ui/reality_glitch_overlay.gd")
const DrKinga = preload("res://scripts/characters/dr_kinga.gd")
const RestraintChair = preload("res://scripts/props/restraint_chair.gd")
const EchoPlayer = preload("res://scripts/player/echo_player.gd")

signal phase_changed(new_phase: int)
signal dialogue_prompt_ready(speaker: String, text: String, choices: Array)
signal player_struggled(struggle_count: int)
signal zero_pact_sealed()
signal hospital_awakening_completed()
signal simulation_anomaly_exposed()
signal hospital_escaped()

enum CinematicPhase {
	IDLE,
	KINGA_CONFRONTATION,
	NEURAL_INJECTION_COLLAPSE,
	CHAIR_RESTRAINT_TORTURE,
	PSYCHOLOGICAL_ILLUSION,
	DESPAIR_ABYSS_FALL,
	ZERO_MEETING_COVENANT,
	PACT_SEALED_EXPLOSION,
	SYSTEM_INTERVENTION,
	HOSPITAL_AWAKENING,
	SIMULATION_BREACH
}

var current_phase: CinematicPhase = CinematicPhase.IDLE

var struggle_count: int = 0
var struggle_required: int = 3
var voltage_level: float = 0.0

var _audio_synth: ProceduralCinematicAudio
var audio_synth: ProceduralCinematicAudio:
	get:
		if not _audio_synth:
			_audio_synth = get_node_or_null("ProceduralAudio") as ProceduralCinematicAudio
			if not _audio_synth:
				_audio_synth = find_child("ProceduralAudio", true, false) as ProceduralCinematicAudio
			if not _audio_synth:
				_audio_synth = ProceduralCinematicAudio.new()
				_audio_synth.name = "ProceduralAudio"
				add_child(_audio_synth)
		return _audio_synth
	set(val):
		_audio_synth = val

var _cam_director: CineCameraDirector
var cam_director: CineCameraDirector:
	get:
		if not _cam_director:
			_cam_director = get_node_or_null("CineCameraDirector") as CineCameraDirector
			if not _cam_director:
				_cam_director = find_child("CineCameraDirector", true, false) as CineCameraDirector
			if not _cam_director:
				_cam_director = CineCameraDirector.new()
				_cam_director.name = "CineCameraDirector"
				add_child(_cam_director)
		return _cam_director
	set(val):
		_cam_director = val

var _fog_controller: VolumetricFogController
var fog_controller: VolumetricFogController:
	get:
		if not _fog_controller:
			_fog_controller = get_node_or_null("VolumetricFogController") as VolumetricFogController
			if not _fog_controller:
				_fog_controller = find_child("VolumetricFogController", true, false) as VolumetricFogController
			if not _fog_controller:
				_fog_controller = VolumetricFogController.new()
				_fog_controller.name = "VolumetricFogController"
				add_child(_fog_controller)
		return _fog_controller
	set(val):
		_fog_controller = val

var _dark_matter: GPUParticles3D
var dark_matter: GPUParticles3D:
	get:
		if not _dark_matter:
			_dark_matter = get_node_or_null("VoidDarkMatter") as GPUParticles3D
			if not _dark_matter:
				_dark_matter = find_child("VoidDarkMatter", true, false) as GPUParticles3D
		return _dark_matter
	set(val):
		_dark_matter = val

var _egress_hatch: HospitalEgressHatch
var egress_hatch: HospitalEgressHatch:
	get:
		if not _egress_hatch:
			_egress_hatch = find_child("HospitalEgressHatch", true, false) as HospitalEgressHatch
		return _egress_hatch
	set(val):
		_egress_hatch = val

var _glitch_overlay: RealityGlitchOverlay
var glitch_overlay: RealityGlitchOverlay:
	get:
		if not _glitch_overlay:
			_glitch_overlay = find_child("RealityGlitchOverlay", true, false) as RealityGlitchOverlay
			if not _glitch_overlay and get_parent():
				_glitch_overlay = get_parent().find_child("RealityGlitchOverlay", true, false) as RealityGlitchOverlay
		return _glitch_overlay
	set(val):
		_glitch_overlay = val

var _kinga_actor: DrKinga
var kinga_actor: DrKinga:
	get:
		if not _kinga_actor:
			_kinga_actor = get_node_or_null("DrKinga") as DrKinga
			if not _kinga_actor:
				_kinga_actor = find_child("DrKinga", true, false) as DrKinga
		return _kinga_actor
	set(val):
		_kinga_actor = val

var _restraint_chair: RestraintChair
var restraint_chair: RestraintChair:
	get:
		if not _restraint_chair:
			_restraint_chair = get_node_or_null("RestraintChair") as RestraintChair
			if not _restraint_chair:
				_restraint_chair = find_child("RestraintChair", true, false) as RestraintChair
		return _restraint_chair
	set(val):
		_restraint_chair = val

var _player_actor: EchoPlayer
var player_actor: EchoPlayer:
	get:
		if not _player_actor:
			_player_actor = get_node_or_null("EchoPlayer") as EchoPlayer
			if not _player_actor and get_parent():
				_player_actor = get_parent().find_child("EchoPlayer", true, false) as EchoPlayer
			if not _player_actor and is_inside_tree() and get_tree() and get_tree().root:
				_player_actor = get_tree().root.find_child("EchoPlayer", true, false) as EchoPlayer
		return _player_actor
	set(val):
		_player_actor = val

var _hospital_bed_node: Node3D
var hospital_bed_node: Node3D:
	get:
		if not _hospital_bed_node:
			_hospital_bed_node = get_node_or_null("HospitalBed") as Node3D
			if not _hospital_bed_node:
				_hospital_bed_node = find_child("HospitalBed", true, false) as Node3D
		return _hospital_bed_node
	set(val):
		_hospital_bed_node = val

# Visual Lighting References
var _lab_lights: Node3D
var lab_lights: Node3D:
	get:
		if not _lab_lights:
			_lab_lights = get_node_or_null("LabLighting") as Node3D
			if not _lab_lights:
				_lab_lights = find_child("LabLighting", true, false) as Node3D
		return _lab_lights
	set(val):
		_lab_lights = val

var _abyss_lights: Node3D
var abyss_lights: Node3D:
	get:
		if not _abyss_lights:
			_abyss_lights = get_node_or_null("AbyssLighting") as Node3D
			if not _abyss_lights:
				_abyss_lights = find_child("AbyssLighting", true, false) as Node3D
		return _abyss_lights
	set(val):
		_abyss_lights = val

var _hospital_lights: Node3D
var hospital_lights: Node3D:
	get:
		if not _hospital_lights:
			_hospital_lights = get_node_or_null("HospitalLighting") as Node3D
			if not _hospital_lights:
				_hospital_lights = find_child("HospitalLighting", true, false) as Node3D
		return _hospital_lights
	set(val):
		_hospital_lights = val

func _ensure_references() -> void:
	var _a = audio_synth
	var _c = cam_director
	var _f = fog_controller
	var _k = kinga_actor
	var _r = restraint_chair
	var _p = player_actor
	var _h = hospital_bed_node
	var _d = dark_matter
	var _e = egress_hatch

func _ready() -> void:
	_ensure_references()
	_set_environment_visibility(true, false, false)
	if egress_hatch:
		egress_hatch.hatch_breached.connect(_on_hatch_breached)

func _set_environment_visibility(lab: bool, abyss: bool, hospital: bool) -> void:
	if lab_lights: lab_lights.visible = lab
	if abyss_lights: abyss_lights.visible = abyss
	if hospital_lights: hospital_lights.visible = hospital

## Step 1: Start Kinga Confrontation
func start_confrontation() -> void:
	_ensure_references()
	current_phase = CinematicPhase.KINGA_CONFRONTATION
	emit_signal("phase_changed", current_phase)
	
	if fog_controller:
		fog_controller.apply_profile(VolumetricFogController.FogProfile.SECTOR11_LAB)
	if kinga_actor:
		kinga_actor.start_confrontation()
	if audio_synth:
		audio_synth.play_kinga_voice()

	var choices = [
		"أبي؟ ما الذي فعلته بهذا المكان وبنا؟! // Father... what have you done to us?!",
		"لن أسمح لك بإجراء تجاربك علي مجدداً! // I will destroy your experiments!"
	]
	emit_signal("dialogue_prompt_ready", "DR. KINJA // كينجا", "لقد كبرت يا بني... لكنك لست هنا كابن، بل كأعظم إنجاز بشري: التجربة EX-011.", choices)

## Step 2: Kinga Injects Neuro-Toxin, Echo Collapses
func trigger_neural_injection() -> void:
	_ensure_references()
	current_phase = CinematicPhase.NEURAL_INJECTION_COLLAPSE
	emit_signal("phase_changed", current_phase)
	if kinga_actor:
		kinga_actor.prepare_injection()
		kinga_actor.administer_injection()

	if cam_director:
		cam_director.apply_trauma(0.45)
		cam_director.set_dutch_tilt(-3.5)

	if audio_synth:
		audio_synth.play_neural_shock()

## Step 3: Echo Awakens Strapped to Restraint Chair
func enter_restraint_torture() -> void:
	_ensure_references()
	current_phase = CinematicPhase.CHAIR_RESTRAINT_TORTURE
	emit_signal("phase_changed", current_phase)
	struggle_count = 0
	voltage_level = 35.0

	if restraint_chair:
		restraint_chair.restrain_subject("ECHO_EX011")
		restraint_chair.trigger_neural_surge(1.2)

	if cam_director:
		cam_director.apply_trauma(0.5)

	if audio_synth:
		audio_synth.play_neural_shock()

## Player Struggles Against Restraints
func player_struggle_pulse() -> void:
	struggle_count += 1
	voltage_level = min(100.0, voltage_level + 20.0)
	emit_signal("player_struggled", struggle_count)
	
	if cam_director:
		cam_director.apply_trauma(0.35)
		cam_director.punch_fov(64.0, 0.05, 0.25)

	if audio_synth:
		audio_synth.play_neural_shock()

	if struggle_count >= struggle_required:
		trigger_psychological_illusion()

## Step 4: Psychological Hallucination of Yuki & Shizuka
func trigger_psychological_illusion() -> void:
	_ensure_references()
	current_phase = CinematicPhase.PSYCHOLOGICAL_ILLUSION
	emit_signal("phase_changed", current_phase)

	var choices = [
		"لن أخسر أحداً منهما... سأحطمك وأحطم هذا النظام! // I refuse your impossible choice!",
		"Yuki... Shizuka... سامحوني... // Forgive me..."
	]
	emit_signal("dialogue_prompt_ready", "SYSTEM HARVEST // محاكاة العذاب النفسي", "قرار مستحيل: اختر التضحية إما بـ YUKI أو SHIZUKA لإنهاء عذاب الصدمات العصبية.", choices)

## Step 5: Sinking into the Dark Ocean Abyss of Despair
func enter_despair_abyss() -> void:
	_ensure_references()
	current_phase = CinematicPhase.DESPAIR_ABYSS_FALL
	emit_signal("phase_changed", current_phase)
	_set_environment_visibility(false, true, false)

	if fog_controller:
		fog_controller.apply_profile(VolumetricFogController.FogProfile.ABYSS_VOID)

	if cam_director:
		cam_director.punch_fov(58.0, 0.8, 1.2)

	if audio_synth:
		audio_synth.play_abyss_ambience()

## Step 6: Meeting Zero in Human / Shadow Form & Forging Covenant
func trigger_zero_covenant_dialogue() -> void:
	_ensure_references()
	current_phase = CinematicPhase.ZERO_MEETING_COVENANT
	emit_signal("phase_changed", current_phase)

	if audio_synth:
		audio_synth.play_zero_whisper()
		audio_synth.play_covenant_chime()

	var choices = [
		"نعم... أعطني القوة، سأحرقهم جميعاً! // Give me the power... I accept the pact!",
		"مهما كان الثمن، سأخرج من هذا الجحيم! // Whatever the cost, I seal the contract!"
	]
	emit_signal("dialogue_prompt_ready", "ZERO // زيرو", "هل تريد الانتقام؟... الإنسان الضعيف الذي عجز عن حماية نفسه لن يغير شيئاً بمفرده. سأمنحك القوة، لكن الثمن هو إنسانيتك... هل تقبل؟", choices)

## Step 7: Covenant Sealed: Singularity Eye + Shadow Wing Manifestation & Explosion
func seal_zero_pact() -> void:
	_ensure_references()
	current_phase = CinematicPhase.PACT_SEALED_EXPLOSION
	emit_signal("phase_changed", current_phase)
	_set_environment_visibility(true, false, false)

	# Awaken Zero's Eye & Shadow Wing on EchoPlayer
	if player_actor and player_actor.has_method("awaken_zero_pact"):
		player_actor.awaken_zero_pact(2.2)

	# Shatter Restraint Chair
	if restraint_chair and restraint_chair.has_method("break_restraints"):
		restraint_chair.break_restraints()

	# Terrify Kinga
	if kinga_actor and kinga_actor.has_method("react_to_zero_singularity"):
		kinga_actor.react_to_zero_singularity()

	# Erupt Void Dark Matter Particles
	if dark_matter:
		dark_matter.emitting = true

	# Trigger CineCam Awakening Preset
	if cam_director:
		cam_director.preset_zero_awakening()

	if audio_synth:
		audio_synth.play_echo_laugh()
		audio_synth.play_covenant_chime()

	emit_signal("zero_pact_sealed")

## Step 8: Solo Leveling System Intervention & Wish
func trigger_system_intervention() -> void:
	_ensure_references()
	current_phase = CinematicPhase.SYSTEM_INTERVENTION
	emit_signal("phase_changed", current_phase)

	var choices = [
		"«الخروج من النظام... مهما كان الثمن» // Escape the System, whatever the price."
	]
	emit_signal("dialogue_prompt_ready", "THE SYSTEM // النظام المركزي", "تحذير: لقد تجاوزت حدود طاقتك البشرية المصرح بها. ما هي أمنيتك الأخيرة؟", choices)

## Step 9: Hospital Awakening (Physical Scars remain, Eye softly extinguishes)
var hospital_eye_fading: bool = false
var hospital_eye_intensity: float = 1.0

func trigger_hospital_awakening() -> void:
	_ensure_references()
	current_phase = CinematicPhase.HOSPITAL_AWAKENING
	emit_signal("phase_changed", current_phase)
	_set_environment_visibility(false, false, true)

	if fog_controller:
		fog_controller.apply_profile(VolumetricFogController.FogProfile.HOSPITAL_SUNLIGHT)

	if cam_director:
		cam_director.preset_hospital_awakening()

	hospital_eye_fading = true
	hospital_eye_intensity = 0.8

	# Play medical heart monitor rhythm
	if audio_synth:
		audio_synth.play_heart_beep()

	# Softly fade out Echo's right eye singularity while keeping physical scars visible
	if player_actor:
		var tree = get_tree() if is_inside_tree() else null
		if tree:
			var tween = tree.create_tween()
			tween.tween_method(func(val: float):
				if player_actor and player_actor.has_method("set_zero_eye_active"):
					player_actor.set_zero_eye_active(val > 0.05, val)
			, 0.8, 0.0, 1.8)
			tween.tween_callback(func():
				hospital_eye_fading = false
				emit_signal("hospital_awakening_completed")
			)
		else:
			if player_actor.has_method("set_zero_eye_active"):
				player_actor.set_zero_eye_active(false)
			hospital_eye_fading = false
			emit_signal("hospital_awakening_completed")

## Step 10: Seamless Reality Shifting & Hospital Simulation Glitch
func trigger_simulation_anomaly() -> void:
	_ensure_references()
	current_phase = CinematicPhase.SIMULATION_BREACH
	emit_signal("phase_changed", current_phase)

	if audio_synth:
		audio_synth.play_reality_glitch()

	if cam_director:
		cam_director.apply_trauma(0.65)
		cam_director.set_dutch_tilt(3.2)

	if glitch_overlay:
		glitch_overlay.show_simulation_anomaly_alert("[CRITICAL WARNING: CONSCIOUSNESS DESYNCHRONIZATION DETECTED - SIMULATION CORRUPTED BY ENTITY ZERO]", 4.5)

	if egress_hatch:
		egress_hatch.expose_simulation_anomaly()

	emit_signal("simulation_anomaly_exposed")

func _on_hatch_breached() -> void:
	if cam_director:
		cam_director.apply_trauma(0.8)
		cam_director.punch_fov(50.0, 0.1, 0.4)
	if audio_synth:
		audio_synth.play_reality_glitch()
	emit_signal("hospital_escaped")
