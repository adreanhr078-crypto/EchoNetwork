extends SceneTree
## Preserve mocap keys while reviewing. Runtime compression needs its own contact gate.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected one candidate GLB in the isolated review project")
		quit(1)
		return
	var path := args[0]+".import"
	var config := ConfigFile.new()
	if config.load(path) != OK:
		push_error("Import candidate once before configuring the review profile")
		quit(1)
		return
	var model: Node = load(args[0]).instantiate()
	var player := model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if not player:
		model.free()
		quit(1)
		return
	var identifier := str(player.get_meta("import_id","PATH:"+str(model.get_path_to(player))))
	var subresources: Dictionary = config.get_value("params","_subresources",{})
	var nodes: Dictionary = subresources.get("nodes",{})
	var settings: Dictionary = nodes.get(identifier,{})
	settings["optimizer/enabled"] = false
	settings["compression/enabled"] = false
	nodes[identifier] = settings
	subresources["nodes"] = nodes
	config.set_value("params","_subresources",subresources)
	var error := config.save(path)
	model.free()
	print("CONTACT_REVIEW_IMPORT_PROFILE "+identifier+" result="+str(error))
	quit(0 if error == OK else 1)
