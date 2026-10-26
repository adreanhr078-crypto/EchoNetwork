extends SceneTree
var checks:=0
var failures:=0
var prompts:Array=[]
func _initialize() -> void:_run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func _run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(10,.2,10);collider.shape=box;ground.position.y=-.1;ground.add_child(collider);world.add_child(ground)
	var player:EchoPlayer=load("res://scenes/player/echo_player.tscn").instantiate();world.add_child(player);player.finish_opening_recovery()
	player.nearby_interactable_changed.connect(func(target:Node):prompts.append(target))
	var area:=InteractableComponent.new();var sensor:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=2;sensor.shape=sphere;area.add_child(sensor);area.position=Vector3(0,.8,0);world.add_child(area)
	for i in 8:await physics_frame
	check(player.get_nearest_interactable()==area,"Actual overlapping player registers an eligible component")
	area.is_enabled=false
	check(player.get_nearest_interactable()==null and prompts.back()==null,"Disabling inside the area clears target and live HUD signal immediately")
	check(not area.is_focused and area.current_interactor==null,"Disabled component releases focus and interactor")
	check(not area.trigger_interaction(player).success,"Disabled device cannot execute an input")
	area.is_enabled=true
	check(player.get_nearest_interactable()==area and area.is_focused,"Re-enable while still overlapping works without leaving the area")
	area.set_meta("interaction_verb_en","CONNECT CIRCUIT");area.set_meta("interaction_verb_ar","صل الدارة")
	check(area.get_interaction_verb("en")=="CONNECT CIRCUIT" and area.get_interaction_verb("ar")=="صل الدارة","Human circuit action has bilingual wording")
	area.queue_free()
	for i in 3:await physics_frame
	check(player.get_nearest_interactable()==null and prompts.back()==null,"Unloading a focused device clears the prompt without an orphan")
	check(not player.combat_available and not player.contract_with_zero_sealed,"Eligibility changes never grant a story state")
	world.queue_free();for i in 3:await process_frame
	print("INTERACTION_ELIGIBILITY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
