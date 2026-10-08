extends CharacterBody3D

## Canon: Kinja is overwhelmed after the pact, not a laser/shield boss.
signal pressure_changed(contacts: int)
signal collar_requested
var player: EchoPlayer
var active := false
var contacts := 0
var completed := false
var verb:=InteractableComponent.InteractionVerb.TALK
var prompt_target_name:="كينجا"
var _recoil := Vector3.ZERO
var trauma_pose: Node3D
const REVENGE_RIG_PATH := "res://assets/characters/kinja_revenge_rig_v1.glb"

func _ready() -> void:
	add_to_group("damageable")
	set_meta("interaction_label_ar","كينجا")
	set_meta("interaction_label_en","Kinja")
	_install_reviewed_rig()
	var area:=Area3D.new()
	area.collision_layer=0
	# Match the actual current EchoPlayer layer; the old assumed layer 2 never entered.
	area.collision_mask=1
	var col:=CollisionShape3D.new()
	var shape:=SphereShape3D.new()
	shape.radius=2.1
	col.shape=shape
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(func(body: Node3D):
		if body.has_method("register_nearby_interactable"): body.register_nearby_interactable(self))
	area.body_exited.connect(func(body: Node3D):
		if body.has_method("unregister_nearby_interactable"): body.unregister_nearby_interactable(self))
	for node in ["HexShield","NeuralLaserBeam","SyringeGlow"]:
		var prop:=get_node_or_null(node) as Node3D
		if prop: prop.hide()

func _install_reviewed_rig() -> void:
	var original:=get_node_or_null("Model") as Node3D
	if not original: return
	# Read-only sections of the preserved source prove that its face is +X.
	# Align the visual to the actor's existing +Z facing convention.
	original.rotation.y=-PI/2
	if not ResourceLoader.exists(REVENGE_RIG_PATH): return
	var scene:=load(REVENGE_RIG_PATH) as PackedScene
	if not scene: return
	var model:=scene.instantiate() as Node3D
	var rig:=_find_rig(model)
	if not rig:
		model.free()
		return
	model.name="KinjaReviewedRevengeRig"
	model.transform=original.transform
	add_child(model)
	var pose:=preload("res://scripts/cinematics/kinja_trauma_pose.gd").new()
	add_child(pose)
	if not pose.setup(rig):
		pose.queue_free()
		model.queue_free()
		return
	trauma_pose=pose
	pose.set_contact_count(contacts)
	original.hide()

func _find_rig(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found:=_find_rig(child)
		if found: return found
	return null

func _process(_delta: float) -> void:
	if trauma_pose:
		trauma_pose.reduced_motion=bool(get_parent().get("reduced_motion"))

func _physics_process(delta: float) -> void:
	if not player or completed: return
	velocity.y-=20.0*delta
	if is_on_floor(): velocity.y=0
	velocity.x=_recoil.x
	velocity.z=_recoil.z
	move_and_slide()
	_recoil=_recoil.move_toward(Vector3.ZERO,8.0*delta)
	var toward:=player.global_position-global_position
	toward.y=0
	if toward.length()>0.2:
		rotation.y=lerp_angle(rotation.y,atan2(toward.x,toward.z),delta*4)

func take_damage(_amount: float, from: Vector3=Vector3.ZERO) -> void:
	if not active or completed or contacts>=3: return
	contacts+=1
	if trauma_pose: trauma_pose.set_contact_count(contacts)
	_recoil=(global_position-from).normalized()*0.75
	_recoil.y=0
	pressure_changed.emit(contacts)

func get_verb_string() -> String:
	return "قبض على كينجا" if contacts>=3 else "واجه كينجا"

func get_interaction_verb(language:String) -> String:
	if language=="ar": return "اقبض عليه" if contacts>=3 else "واجهه"
	return "Seize him" if contacts>=3 else "Confront him"

func trigger_interaction(interactor: Node=null) -> Dictionary:
	if not active or completed or contacts<3 or interactor!=player or global_position.distance_to(player.global_position)>2.2:
		return {"success":false,"reason":"confrontation_not_ready"}
	if trauma_pose: trauma_pose.begin_collar()
	collar_requested.emit()
	return {"success":true,"collar_requested":true}
