extends Node

## Room-owned shadow presentation. The opening facility is still instantiated
## upstream and its legacy geometry projected false shadow patches into this
## independent room. Scope the key's casters to this room and the live actor,
## while preserving real local shadows and every previous owner's property.
const CASTER_LAYER := 1 << 17 # Dedicated maintenance shadow scope;not mirror20.
var room:Node3D
var _key:DirectionalLight3D
var _leased:=false
var _prior:=0.0
var _owned:=0.0
var _prior_mask:=0
var _owned_mask:=0
var _mask_leased:=false
var _casters:Array[Dictionary]=[]
var _scene:SceneTree
var _actor:Node
var _probe:ReflectionProbe
var _probe_home:=Vector3.ZERO
var _capture_serial:=0
var _shaft_fog:FogVolume

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	_key=room.get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	_actor=room.get_parent().get_node_or_null("EchoPlayer")
	_scene=get_tree()
	_probe=room.get_node_or_null("MaintenanceMechanicalDressing/MaintenanceInteriorReflection") as ReflectionProbe
	if is_instance_valid(_probe):_probe_home=_probe.position
	_shaft_fog=room.get_node_or_null("MaintenanceMechanicalDressing/MaintenanceDeepShaftAtmosphere") as FogVolume
	room.service_opened.connect(_refresh_reflection)

func _process(_delta:float)->void:
	if not is_instance_valid(_key):
		_release();return
	var inside:bool=is_instance_valid(room) and is_instance_valid(room.presentation) and room.presentation._inside_room
	if inside and not _leased:
		_prior=_key.light_angular_distance;_owned=maxf(_prior,1.25)
		_key.light_angular_distance=_owned;_leased=true
		_prior_mask=_key.shadow_caster_mask
		# A prior owner may deliberately exclude this reserved layer. Preserve
		# that restriction rather than silently re-enabling forbidden casters.
		if (_prior_mask & CASTER_LAYER)!=0:
			_owned_mask=CASTER_LAYER;_key.shadow_caster_mask=_owned_mask;_mask_leased=true
			for node in room.find_children("*","GeometryInstance3D",true,false):_tag_geometry(node)
			if is_instance_valid(_actor):
				for node in _actor.find_children("*","GeometryInstance3D",true,false):_tag_geometry(node)
			if not _scene.node_added.is_connected(_on_node_added):_scene.node_added.connect(_on_node_added)
		if is_instance_valid(_shaft_fog):_shaft_fog.show()
		_refresh_reflection()
	elif not inside:_release()

func _refresh_reflection()->void:
	if not _leased or not is_instance_valid(_probe):return
	# UPDATE_ONCE captures six faces and then stops. A tiny probe-only
	# transform change refreshes a re-entry or the existing opened gate;
	# no source animation key,time,actor transform or gameplay state changes.
	_capture_serial+=1;_probe.position=_probe_home+Vector3(0,.0001 if _capture_serial%2 else 0,0)
	_probe.show()

func _on_node_added(node:Node)->void:
	if _mask_leased and node is GeometryInstance3D:_tag_geometry.call_deferred(node)

func _tag_geometry(node:Node)->void:
	if not _mask_leased or not is_instance_valid(node) or not node is GeometryInstance3D:return
	if not (is_instance_valid(room) and room.is_ancestor_of(node)) and not (is_instance_valid(_actor) and _actor.is_ancestor_of(node)):return
	for record in _casters:
		if record.node.get_ref()==node:return
	_casters.append({"node":weakref(node),"prior":node.layers})
	node.layers|=CASTER_LAYER

func _release()->void:
	if _leased and is_instance_valid(_key) and is_equal_approx(_key.light_angular_distance,_owned):_key.light_angular_distance=_prior
	if _mask_leased and is_instance_valid(_key) and _key.shadow_caster_mask==_owned_mask:_key.shadow_caster_mask=_prior_mask
	if is_instance_valid(_scene) and _scene.node_added.is_connected(_on_node_added):_scene.node_added.disconnect(_on_node_added)
	for record in _casters:
		var node:GeometryInstance3D=record.node.get_ref() as GeometryInstance3D
		if is_instance_valid(node) and (int(record.prior)&CASTER_LAYER)==0:node.layers&=~CASTER_LAYER
	_casters.clear();_mask_leased=false;_leased=false
	if is_instance_valid(_probe):_probe.hide()
	if is_instance_valid(_shaft_fog):_shaft_fog.hide()

func _exit_tree()->void:_release()
