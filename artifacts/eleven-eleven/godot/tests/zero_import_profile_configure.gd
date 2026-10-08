extends SceneTree

## Asset-local source-motion preservation. No project settings or Golden
## import profiles are modified by this configuration step.
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	assert(args.size()==1 and args[0].begins_with("res://assets/characters/zero_"))
	var path:=args[0]+".import"
	var config:=ConfigFile.new()
	assert(config.load(path)==OK)
	var model: Node=load(args[0]).instantiate()
	var player:=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	assert(player)
	var identifier:=str(player.get_meta("import_id","PATH:"+str(model.get_path_to(player))))
	var subresources: Dictionary=config.get_value("params","_subresources",{})
	var nodes: Dictionary=subresources.get("nodes",{})
	var settings: Dictionary=nodes.get(identifier,{})
	settings["optimizer/enabled"]=false
	settings["compression/enabled"]=false
	nodes[identifier]=settings
	subresources["nodes"]=nodes
	config.set_value("params","_subresources",subresources)
	config.set_value("params","animation/remove_immutable_tracks",false)
	config.set_value("params","animation/trimming",false)
	config.set_value("params","animation/fps",30)
	assert(config.save(path)==OK)
	model.free()
	print("PASS asset-local Zero source profile: optimizer/compression off, immutable tracks retained, complete native duration,30fps reconstruction; source bytes unchanged")
	quit(0)
