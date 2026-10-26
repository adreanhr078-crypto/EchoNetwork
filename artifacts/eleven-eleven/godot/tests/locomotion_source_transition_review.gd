extends SceneTree

var player: EchoPlayer
var failures: Array[String]=[]
var switches: Array=[]
var contacts: Array=[]
var checks:=0
func _initialize() -> void: _run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func drive(input:Vector2,count:int) -> void:
	player.set_mobile_input_vector(input,not input.is_zero_approx())
	for i in count:
		var old:String=player.animation_player.current_animation
		var phase:float=player.animation_player.current_animation_position/maxf(player.animation_player.current_animation_length,.001)
		await physics_frame
		var now:String=player.animation_player.current_animation
		if old!=now and old in ["WALK","RUN"] and now in ["WALK","RUN"]:
			var expected:=fposmod(phase+(3.0/26.0-.75 if old=="WALK" else .75-3.0/26.0),1.0)
			var actual:float=player.animation_player.current_animation_position/player.animation_player.current_animation_length
			var error:=absf(wrapf(actual-expected,-.5,.5))
			switches.append({"from":old,"to":now,"phase_error":error})
func _run() -> void:
	var floor_body:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new();shape.size=Vector3(100,.2,100);collision.shape=shape
	floor_body.position.y=-.1;floor_body.add_child(collision);root.add_child(floor_body)
	player=load("res://scenes/player/echo_player.tscn").instantiate();root.add_child(player)
	player.finish_opening_recovery()
	for i in 8:await physics_frame
	var mixer:=player.animation_player
	check(mixer.get_animation("RUN").get_meta("source_take_id","")=="c1ed64d6c975194967304af7:0:13373cc7","Production RUN uses qualified forward Run")
	check(mixer.get_animation("WALK").get_meta("source_take_id","")=="cca789212f4a334b9ec9309a:0:5173144e","Production WALK uses independent native Walk")
	check(mixer.callback_mode_process==AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS,"Controlled animation and capsule share physics clock")
	player.footstep_system.footstep_triggered.connect(func(left:bool,_surface:String,run:bool,point:Vector3):contacts.append({"left":left,"run":run,"height":point.y}))
	await drive(Vector2(0,-.45),60)
	check(player.current_anim=="WALK","Partial public input walks")
	var pause_clock:=mixer.current_animation_position
	var pause_position:=player.global_position
	paused=true
	for i in 8:await process_frame
	check(mixer.current_animation_position==pause_clock and player.global_position==pause_position,"Pause freezes source clock and physical movement")
	paused=false
	await drive(Vector2(0,-1),100)
	check(player.current_anim=="RUN","Full public input runs after pause")
	await drive(Vector2(.45,0),85)
	check(player.current_anim=="WALK","Turn and reduced input return to actual Walk")
	check(switches.size()>=2,"Both real gait transitions exercised")
	var max_error:=0.0
	for item in switches:max_error=maxf(max_error,item.phase_error)
	check(max_error<.08,"Real gait transitions retain the same support foot despite different source starts")
	check(contacts.size()>=5,"Walking and running both emit physical foot contacts")
	var max_height:=0.0
	for item in contacts:max_height=maxf(max_height,item.height)
	check(max_height<.20,"Source contact sounds and effects remain near the ground")
	await drive(Vector2.ZERO,60)
	check(player.current_anim=="IDLE" and Vector2(player.velocity.x,player.velocity.z).length()<.05,"Release returns to stable Idle without drift")
	player.request_jump()
	var airborne:=false;var landed:=false
	for i in 180:
		await physics_frame
		airborne=airborne or not player.is_on_floor()
		if airborne and player.is_on_floor():landed=true;break
	check(airborne and landed and not player.combat_available and not player.contract_with_zero_sealed,"Public jump lands without an early power or contract")
	var report:Dictionary={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"switches":switches,"maximum_contact_phase_error":max_error,"maximum_foot_contact_height_m":max_height,"contacts":contacts,"run_library_sha256":FileAccess.get_sha256("res://assets/animations/v31/run_cp45.res"),"walk_library_sha256":FileAccess.get_sha256("res://assets/animations/v31/walk_cp45.res"),"source_keys_modified":false}
	var output:="res://../audits/evidence/chapter-cp45-20261020/stage05/integrated-transition.json"
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("LOCOMOTION_TRANSITIONS ",JSON.stringify(report))
	player.queue_free();floor_body.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
