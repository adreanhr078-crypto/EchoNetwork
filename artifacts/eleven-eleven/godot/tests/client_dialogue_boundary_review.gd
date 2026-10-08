extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var engine:=preload("res://scripts/systems/dynamic_ai_dialogue_engine.gd").new()
	root.add_child(engine)
	engine.gemini_api_key="test-sentinel-no-network"
	assert(engine.gemini_api_key.is_empty() and not engine.is_online_mode,"Exported client must neither retain nor activate a provider key")
	var responses:Array=[]
	engine.dialogue_response_ready.connect(func(_speaker:String,text:String,_meta:Dictionary): responses.append(text))
	var result:=engine.generate_response("YUKI","hello")
	assert(result.success and not result.text.is_empty() and responses.size()==1,"Local dialogue must remain available")
	engine.send_to_gemini_live("SHIZUKA","hello")
	assert(responses.size()==2 and engine.find_children("*","HTTPRequest",true,false).is_empty(),"Historical live API must never create a provider request")
	engine.queue_free()
	await process_frame
	await create_timer(0.2,true,false,true).timeout
	print("PASS client dialogue: provider key discarded, no direct provider requests, local response and historical callback remain available")
	quit()
