class_name MinatoHighSchool
extends Node3D

## AAA Minato High School 3-Story Campus
## Comprehensive Japanese anime school campus featuring:
## - Floor 1: Shoe locker foyer (Geta-bako), staff room, gymnasium
## - Floor 2: Class 2-B (Echo, Yuki, Shizuka desks), science lab, nurse office
## - Floor 3: Library archives, art studio, and iconic fenced panoramic Rooftop
## - Schedule controller & Westminster PA bell chimes

signal campus_entered(player: Node)
signal shoes_swapped(is_indoor: bool)
signal class_attended(subject: String, focus_bonus: float)
signal rooftop_accessed()
signal nurse_treated(hp_healed: float)

const ProceduralCinematicAudio = preload("res://scripts/audio/procedural_cinematic_audio.gd")
const SchoolScheduleControllerScript = preload("res://scripts/systems/school_schedule_controller.gd")
const YukiCompanionScript = preload("res://scripts/characters/yuki_companion.gd")
const ShizukaCompanionScript = preload("res://scripts/characters/shizuka_companion.gd")
const CompanionBondManagerScript = preload("res://scripts/systems/companion_bond_manager.gd")
const ClassroomLessonQuizEngineScript = preload("res://scripts/systems/classroom_lesson_quiz_engine.gd")

var schedule_controller: SchoolScheduleControllerScript = null
var yuki_companion: YukiCompanionScript = null
var shizuka_companion: ShizukaCompanionScript = null
var bond_manager: CompanionBondManagerScript = null
var lesson_quiz_engine: ClassroomLessonQuizEngineScript = null
var is_wearing_indoor_slippers: bool = false
var is_rooftop_door_open: bool = false
var total_classes_attended: int = 0

# Student Desk Mapping in Class 2-B
const CLASS_2B_DESKS: Dictionary = {
	"ECHO": {
		"seat": "Window seat, Row 4 (Classic Anime Protagonist Desk)",
		"character": "Echo Kasumi",
		"pos": Vector3(-4.5, 3.8, 2.5)
	},
	"YUKI": {
		"seat": "Aisle seat, Row 4 (Directly left of Echo)",
		"character": "Yuki Tachibana",
		"pos": Vector3(-2.8, 3.8, 2.5)
	},
	"SHIZUKA": {
		"seat": "Window seat, Row 3 (Directly in front of Echo)",
		"character": "Shizuka",
		"pos": Vector3(-4.5, 3.8, 4.2)
	}
}

func _ready() -> void:
	_setup_school_nodes()

func _setup_school_nodes() -> void:
	if not schedule_controller:
		schedule_controller = find_child("SchoolScheduleController", true, false) as SchoolScheduleControllerScript
		if not schedule_controller:
			schedule_controller = SchoolScheduleControllerScript.new()
			schedule_controller.name = "SchoolScheduleController"
			add_child(schedule_controller)

	if not bond_manager:
		bond_manager = find_child("CompanionBondManager", true, false) as CompanionBondManagerScript
		if not bond_manager:
			bond_manager = CompanionBondManagerScript.new()
			bond_manager.name = "CompanionBondManager"
			add_child(bond_manager)

	if not yuki_companion:
		yuki_companion = find_child("YukiCompanion", true, false) as YukiCompanionScript
		if not yuki_companion:
			yuki_companion = YukiCompanionScript.new()
			yuki_companion.name = "YukiCompanion"
			add_child(yuki_companion)

	if not shizuka_companion:
		shizuka_companion = find_child("ShizukaCompanion", true, false) as ShizukaCompanionScript
		if not shizuka_companion:
			shizuka_companion = ShizukaCompanionScript.new()
			shizuka_companion.name = "ShizukaCompanion"
			add_child(shizuka_companion)

	_setup_visual_architecture()

func _setup_visual_architecture() -> void:
	# Floor 1 Foyer Lantern / Fluorescent Light
	var f1_light = find_child("FoyerLight", true, false) as OmniLight3D
	if not f1_light:
		f1_light = OmniLight3D.new()
		f1_light.name = "FoyerLight"
		f1_light.light_color = Color(0.95, 0.98, 1.0, 1.0)
		f1_light.light_energy = 2.0
		f1_light.position = Vector3(0, 3.0, 0)
		add_child(f1_light)

	# Geta-bako Shoe Locker Unit Mesh
	var getabako = find_child("GetaBakoLockerMesh", true, false)
	if not getabako:
		var locker := MeshInstance3D.new()
		locker.name = "GetaBakoLockerMesh"
		var box := BoxMesh.new()
		box.size = Vector3(2.4, 1.8, 0.6)
		locker.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.22, 0.14, 1.0) # Lacquered wood school lockers
		mat.roughness = 0.4
		locker.material_override = mat
		locker.position = Vector3(-3.0, 0.9, -2.0)
		add_child(locker)

	# Floor 2 Class 2-B Blackboard Mesh
	var blackboard = find_child("BlackboardMesh", true, false)
	if not blackboard:
		var board := MeshInstance3D.new()
		board.name = "BlackboardMesh"
		var bbox := BoxMesh.new()
		bbox.size = Vector3(3.6, 1.4, 0.08)
		board.mesh = bbox
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.08, 0.18, 0.12, 1.0) # Traditional dark green chalkboard
		bmat.roughness = 0.6
		board.material_override = bmat
		board.position = Vector3(0, 4.8, 6.0)
		add_child(board)

	# Floor 3 Rooftop Chain-Link Fence & Horizon Viewport
	var roof_fence = find_child("RooftopFenceMesh", true, false)
	if not roof_fence:
		var fence := MeshInstance3D.new()
		fence.name = "RooftopFenceMesh"
		var fbox := BoxMesh.new()
		fbox.size = Vector3(12.0, 2.2, 0.1)
		fence.mesh = fbox
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(0.65, 0.68, 0.72, 0.65) # Metallic chain-link mesh
		fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fence.material_override = fmat
		fence.position = Vector3(0, 8.5, -8.0)
		add_child(fence)

## Switches player footwear between outdoor shoes and school indoor slippers (Uwabaki)
func swap_shoes(player: Node = null) -> Dictionary:
	is_wearing_indoor_slippers = not is_wearing_indoor_slippers

	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_shoe_locker_click()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("shoes_swapped", is_wearing_indoor_slippers)
	return {
		"success": true,
		"is_indoor_slippers": is_wearing_indoor_slippers,
		"footwear": "Uwabaki Slippers" if is_wearing_indoor_slippers else "Outdoor Loafers"
	}

## Player attends class in room 2-B, gaining mental stability and focus
func attend_class_2b(player: Node = null) -> Dictionary:
	total_classes_attended += 1
	var subject: String = "Modern Cataclysm & Neural Resonance"

	if player:
		# Restore energy / sanity
		if "hp" in player:
			player.hp = minf(200.0, player.hp + 20.0)
		if player.has_method("restore_stamina"):
			player.restore_stamina(30.0)

	emit_signal("class_attended", subject, 25.0)
	return {
		"success": true,
		"subject": subject,
		"classroom": "Class 2-B",
		"focus_bonus": 25.0,
		"total_attended": total_classes_attended
	}

## Opens heavy steel door to the iconic school rooftop
func access_rooftop(player: Node = null) -> Dictionary:
	is_rooftop_door_open = true

	if is_inside_tree():
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio.stream = ProceduralCinematicAudio.create_rooftop_wind_sfx()
		audio.play()
		audio.finished.connect(func(): audio.queue_free())

	emit_signal("rooftop_accessed")
	return {
		"success": true,
		"rooftop_unlocked": true,
		"view": "Panoramic Pacific Ocean & Minato Town Vista",
		"elevation_meters": 12.5
	}

## Visit School Nurse's Office for First Aid & Rest
func visit_nurse_office(player: Node) -> Dictionary:
	var heal_amount: float = 75.0
	if "hp" in player:
		player.hp = minf(200.0, player.hp + heal_amount)
		if player.has_signal("hp_changed"):
			player.emit_signal("hp_changed", player.hp, 200.0)

	if player.has_method("restore_energy"):
		player.restore_energy(40.0)

	emit_signal("nurse_treated", heal_amount)
	return {
		"success": true,
		"hp_healed": heal_amount,
		"nurse_name": "Nurse Chiyo",
		"location": "Floor 2 Health Bay"
	}

func get_desk_info(character_key: String) -> Dictionary:
	return CLASS_2B_DESKS.get(character_key.to_upper(), {})

func get_schedule() -> SchoolScheduleControllerScript:
	if not schedule_controller:
		_setup_school_nodes()
	return schedule_controller

func get_yuki_companion() -> YukiCompanionScript:
	if not yuki_companion:
		_setup_school_nodes()
	return yuki_companion

func get_shizuka_companion() -> ShizukaCompanionScript:
	if not shizuka_companion:
		_setup_school_nodes()
	return shizuka_companion

func get_bond_manager() -> CompanionBondManagerScript:
	if not bond_manager:
		_setup_school_nodes()
	return bond_manager

func get_lesson_quiz_engine() -> ClassroomLessonQuizEngineScript:
	if not lesson_quiz_engine:
		lesson_quiz_engine = ClassroomLessonQuizEngineScript.new()
		lesson_quiz_engine.name = "ClassroomLessonQuizEngine"
		add_child(lesson_quiz_engine)
	return lesson_quiz_engine


