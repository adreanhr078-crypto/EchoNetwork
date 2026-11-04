extends SceneTree

var checks := 0
var failures: Array[String] = []
var samples: Array = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func _run() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var arm := SpringArm3D.new()
	body.add_child(arm)
	var camera := Camera3D.new()
	arm.add_child(camera)
	camera.make_current()
	var rig := DynamicActionCameraRig.new()
	body.add_child(rig)
	rig.configure(body,camera,arm)
	rig.base_fov=65
	var peaks: Array[float] = []
	for hz in [30,60,120]:
		rig.set_reduced_motion(true)
		rig.set_reduced_motion(false)
		rig.combat_impact(.85,Vector3.BACK)
		var low := 65.0
		var angle := 0.0
		for frame in hz*2:
			rig.tick_lens(1.0/hz)
			low=minf(low,camera.fov)
			angle=maxf(angle,camera.rotation.length())
		peaks.append(low)
		samples.append({"hz":hz,"lowest_fov":low,"max_angle_degrees":rad_to_deg(angle),"return_fov":camera.fov})
		check(low<64.6 and low>=60.0,"Confirmed heavy contact has a bounded lens impulse at%dHz"%hz)
		check(rad_to_deg(angle)<1.5 and absf(camera.fov-65.0)<.03,"Directed response settles without orbit drift at%dHz"%hz)
	check(absf(peaks[0]-peaks[2])<.25,"30/60/120Hz lens impulse remains consistent")
	rig.combat_impact(1,Vector3.BACK)
	rig.set_reduced_motion(true)
	rig.tick_lens(.01)
	check(is_equal_approx(camera.fov,65) and camera.rotation.is_zero_approx() and is_zero_approx(rig.trauma),"Reduced Motion clears lens and shake immediately")
	rig.set_reduced_motion(false)
	rig.combat_impact(1,Vector3.BACK)
	rig.tick_lens(.05,true)
	check(is_zero_approx(rig._combat_lens) and is_zero_approx(rig._combat_pulse),"Cinematic suspension removes stale combat impulse")
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"samples":samples,"scope":"Analytic camera response only;actual gameplay framing,collision,visual impact and performance reviewed separately."}
	var args := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(args[0])
	var file := FileAccess.open(args[0].path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
