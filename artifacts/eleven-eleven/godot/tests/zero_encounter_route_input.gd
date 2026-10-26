extends RefCounted

## Shared public UI driver for the current eight-step contract. No checkpoint
## flags, presentation clocks, positions or power grants are manufactured here.
static func _check(tree,ok:bool,message:String) -> bool:
	return bool(tree.call("_check",ok,message))

static func _press(tree,main,index:int) -> bool:
	var window:Node=main.hud.find_child("SystemWindow",true,false)
	if not _check(tree,window.visible and window._modal and window.stats_box.get_child_count()>index,"Current encounter decision button unavailable"):return false
	window.stats_box.get_child(index).pressed.emit()
	for tick in 4:await tree.physics_frame
	return true

static func play(tree,main,room,capture:Callable=Callable()) -> bool:
	var pact:Node=room.story_presentation
	if room.contract_done and pact.encounter_step==8:
		return _check(tree,main.player.combat_available,"Restored explicit pact lost its combat state")
	for expected in 4:
		if not _check(tree,pact.encounter_live and pact.encounter_step==expected and not room.contract_done and not main.player.combat_available,"Route skipped a pre-consent encounter beat"):return false
		if not await _press(tree,main,0):return false
	for index in 3:
		if not await _press(tree,main,index):return false
		if not _check(tree,pact.encounter_step==4 and pact.encounter_answer==index,"Route question answer was not recorded"):return false
		if not await _press(tree,main,0):return false
	if not _check(tree,pact.encounter_questions==7 and not room.contract_done,"Questions granted or lost consent"):return false
	if not await _press(tree,main,3):return false
	if not _check(tree,pact.encounter_step==5 and not main.player.combat_available,"Consent menu unlocked combat before a decision"):return false
	if not await _press(tree,main,0):return false
	if not _check(tree,pact.encounter_step==6 and room.contract_done and main.player.contract_with_zero_sealed,"Explicit route acceptance did not persist the contract"):return false
	if capture.is_valid():await capture.call("contract-integration")
	if not await _press(tree,main,0):return false
	if not _check(tree,pact.encounter_step==7 and main.player.player_camera.current and not main.player.control_locked,"Integration did not return the real gameplay camera/input"):return false
	pact._encounter_power.button_down.emit()
	for tick in 120:
		if main.player.iai_charge>=.8:break
		await tree.physics_frame
	if not _check(tree,main.player.is_charging_iai and main.player.iai_charge>=.8,"Route power button did not accumulate a real charge"):return false
	pact._encounter_power.button_up.emit()
	for tick in 240:
		if pact.encounter_step==8:break
		await tree.physics_frame
	return _check(tree,pact.encounter_step==8 and not pact.encounter_live and room.contract_done and not room.wish_done and main.player.combat_available,"Current encounter did not complete independently of the wish")

static func wait_melee_recovery(tree,player,capture:Callable=Callable()) -> bool:
	var captured:=false
	for tick in 240:
		await tree.physics_frame
		if capture.is_valid() and not captured and player.animation_player.current_animation_position>=.93:
			captured=true
			await capture.call()
		if player._attack_recovery<=0.0 and not player.is_attacking:return true
	return _check(tree,false,"Native melee did not complete its original bounded recovery")
