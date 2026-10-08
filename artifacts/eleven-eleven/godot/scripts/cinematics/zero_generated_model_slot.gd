extends Node3D

## A measured imported source replaces the temporary body only. Textures,
## rests and native animation keys stay intact; this node owns no story state.
var model_root: Node3D
var skeleton: Skeleton3D
var source_player: AnimationPlayer
var source_idle := ""
var source_pact := ""
var body_animation_verified := false
var body_animation_kind := "none"
var _articulation: RefCounted
var _stage := "dormant"
var _restoring := false
var _energy: ShaderMaterial
var _eye_materials: Array[ShaderMaterial] = []
var _material_presentation: Dictionary = {}

func load_profile(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var profile=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not profile is Dictionary: return false
	var asset: String=str(profile.get("scene_path",""))
	if not asset.begins_with("res://assets/characters/") or not ResourceLoader.exists(asset): return false
	var scene:=load(asset) as PackedScene
	if not scene: return false
	return configure(scene.instantiate(),profile)

func configure(model: Node3D, profile: Dictionary) -> bool:
	var height: float=float(profile.get("source_height",0.0))
	if height<0.1 or height>50.0:
		model.free()
		return false
	var pivot:=Node3D.new()
	pivot.name="MeasuredGeneratedSource"
	var ratio:=6.2/height
	pivot.scale=Vector3.ONE*ratio
	pivot.position.y=-float(profile.get("source_base_y",0.0))*ratio
	pivot.rotation.y=float(profile.get("facing_y_radians",0.0))
	add_child(pivot)
	pivot.add_child(model)
	model_root=model
	skeleton=_find_skeleton(model)
	source_player=_find_player(model)
	source_idle=str(profile.get("idle_animation",""))
	source_pact=str(profile.get("pact_animation",""))
	_material_presentation=profile.get("material_presentation",{})
	_load_event_library(str(profile.get("pact_library_path","")))
	body_animation_verified=_has_skeletal_clip(source_idle)
	if body_animation_verified: body_animation_kind="imported_native_clip"
	elif skeleton and bool(profile.get("allow_articulated_fallback",false)):
		var pose:=preload("res://scripts/cinematics/zero_measured_body_pose.gd").new()
		if pose.setup(skeleton,profile):
			_articulation=pose
			body_animation_verified=true
			body_animation_kind="measured_native_articulation"
	if source_player:
		source_player.stop()
		source_player.animation_finished.connect(_source_clip_finished)
	_build_energy_overlay()
	_install_overlays(model)
	for eye in profile.get("eyes",[]):
		if eye is Dictionary: _install_eye(eye)
	return true

func _load_event_library(path: String) -> void:
	if not source_player or not path.begins_with("res://assets/animations/zero/") or not ResourceLoader.exists(path): return
	var library:=load(path) as AnimationLibrary
	if not library: return
	var animation_root:=source_player.get_node(source_player.root_node)
	for label in library.get_animation_list():
		var animation:=library.get_animation(label)
		for track in animation.get_track_count():
			var target:=animation_root.get_node_or_null(NodePath(animation.track_get_path(track).get_concatenated_names()))
			if not target: return
			if target is Skeleton3D:
				var bone_path:=animation.track_get_path(track)
				if bone_path.get_subname_count()>0 and target.find_bone(bone_path.get_subname(0))<0: return
	# Same exact source skeleton and track paths were verified before extraction.
	# Namespacing keeps the original agree label and every stored key untouched.
	source_player.add_animation_library("pact",library)

func tick(phase: float, still: bool, stage: String, delta:=0.0) -> void:
	if not model_root: return
	if _energy:
		_energy.set_shader_parameter("phase",phase)
		_energy.set_shader_parameter("pact_energy",1.0 if stage=="accepted" else 0.0)
		_energy.set_shader_parameter("field_origin",global_position)
	for material in _eye_materials:
		material.set_shader_parameter("phase",phase)
		material.set_shader_parameter("pact_energy",1.0 if stage=="accepted" else 0.0)
	var visible_stage: bool=stage in ["manifested","accepted"]
	if _articulation and visible_stage: _articulation.tick(phase,still,stage=="accepted",delta)
	if source_player:
		if visible_stage and stage!=_stage:
			var clip:=source_pact if stage=="accepted" and not _restoring and _has_skeletal_clip(source_pact) else source_idle
			if _has_skeletal_clip(clip):
				source_player.play(clip)
				source_player.seek(0.0,true)
		if still or not visible_stage: source_player.pause()
		elif visible_stage and not source_player.is_playing() and _has_skeletal_clip(source_player.assigned_animation):
			# Resume the exact saved source sample after reduced motion; no rebake,
			# source-rate relabel, animation optimization or invented motion keys.
			source_player.play(source_player.assigned_animation)
	_stage=stage
	_restoring=false

func set_stage_hint(restoring: bool) -> void:
	# A restored pact resumes ambient source acting, not its event gesture.
	_restoring=restoring

func _source_clip_finished(_clip: StringName) -> void:
	if _stage in ["manifested","accepted"] and _has_skeletal_clip(source_idle):
		source_player.play(source_idle)
		source_player.seek(0.0,true)

func _has_skeletal_clip(label: String) -> bool:
	if not skeleton or not source_player or label=="" or not source_player.has_animation(label): return false
	var animation:=source_player.get_animation(label)
	for index in animation.get_track_count():
		if animation.track_get_type(index)!=Animation.TYPE_ROTATION_3D: continue
		var path:=animation.track_get_path(index)
		if path.get_subname_count()>0 and skeleton.find_bone(path.get_subname(path.get_subname_count()-1))>=0: return true
	return false

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found:=_find_skeleton(child)
		if found: return found
	return null

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found:=_find_player(child)
		if found: return found
	return null

func _build_energy_overlay() -> void:
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode blend_add,unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform float phase=0.0;
uniform float pact_energy=0.0;
uniform vec3 field_origin=vec3(0.0);
varying vec3 field_point;
float hash3(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise3(vec3 p) {
 vec3 c=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
 float a=mix(mix(hash3(c),hash3(c+vec3(1,0,0)),f.x),mix(hash3(c+vec3(0,1,0)),hash3(c+vec3(1,1,0)),f.x),f.y);
 float b=mix(mix(hash3(c+vec3(0,0,1)),hash3(c+vec3(1,0,1)),f.x),mix(hash3(c+vec3(0,1,1)),hash3(c+vec3(1,1,1)),f.x),f.y);
 return mix(a,b,f.z);
}
void vertex() { field_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz-field_origin; }
void fragment() {
 float warp=noise3(field_point*1.4);
 float line=1.0-smoothstep(0.025,0.10,abs(noise3(field_point*5.8+warp*1.8)-0.5));
 float mask=line*smoothstep(0.66,0.82,noise3(field_point*1.9+3.7));
 if (mask<0.025) discard;
 float life=0.90+0.10*sin(phase*0.85+field_point.y*1.2);
 vec3 signal=mix(vec3(0.44,0.025,0.13),vec3(0.29,0.075,0.75),smoothstep(-1.4,0.2,field_point.x));
 ALBEDO=vec3(0.0);
 EMISSION=signal*mask*life*(0.35+pact_energy*0.22);
 ALPHA=mask*0.42;
}"""
	_energy=ShaderMaterial.new()
	_energy.shader=shader

func _install_overlays(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh:=node as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var original:=mesh.get_active_material(surface)
			if original:
				var material:=original.duplicate() as Material
				if material is StandardMaterial3D and not _material_presentation.is_empty():
					# The generated glTF defaults to 100% metal. A source-preserving
					# local PBR multiplier restores diffuse limb detail in this lab;
					# all original colour, normal and ORM textures remain attached.
					material.metallic=minf(material.metallic,float(_material_presentation.get("metallic_cap",1.0)))
					material.roughness=maxf(material.roughness,float(_material_presentation.get("roughness_factor_min",0.0)))
				material.next_pass=_energy
				mesh.set_surface_override_material(surface,material)
	for child in node.get_children(): _install_overlays(child)

func _install_eye(profile: Dictionary) -> void:
	var point_data=profile.get("source_position",[])
	var direction_data=profile.get("source_forward",[])
	if point_data.size()!=3 or direction_data.size()!=3: return
	var point:=Vector3(point_data[0],point_data[1],point_data[2])
	var direction:=Vector3(direction_data[0],direction_data[1],direction_data[2]).normalized()
	if direction.length()<0.9: return
	var eye_transform:=Transform3D(Basis.looking_at(direction,Vector3.UP,true),point)
	var parent: Node3D=model_root
	var bone_name: String=str(profile.get("bone_name",""))
	if skeleton and bone_name!="":
		var index:=skeleton.find_bone(bone_name)
		if index<0: return
		var attachment:=BoneAttachment3D.new()
		attachment.bone_name=bone_name
		skeleton.add_child(attachment)
		var model_to_rig:=skeleton.global_transform.affine_inverse()*model_root.global_transform
		eye_transform=skeleton.get_bone_global_rest(index).affine_inverse()*model_to_rig*eye_transform
		parent=attachment
	elif skeleton: return # A living head needs a measured binding, never a floating eye guess.
	var visual:=MeshInstance3D.new()
	visual.name="MeasuredLivingEye"
	var quad:=QuadMesh.new()
	quad.size=Vector2(float(profile.get("width",0.03)),float(profile.get("height",0.009)))
	visual.mesh=quad
	visual.transform=eye_transform
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled;
uniform vec4 signal:source_color=vec4(0.5,0.08,0.9,1.0);
uniform float phase=0.0;
uniform float pact_energy=0.0;
void fragment() {
 vec2 p=abs(UV-0.5)*2.0;
 if (pow(p.x,0.75)+p.y>1.0) discard;
 ALBEDO=signal.rgb;
 EMISSION=signal.rgb*(2.0+pact_energy*0.6)*(0.93+0.07*sin(phase*0.7));
}"""
	var material:=ShaderMaterial.new()
	material.shader=shader
	var color_data=profile.get("color",[0.50,0.08,0.90])
	if color_data.size()==3: material.set_shader_parameter("signal",Color(color_data[0],color_data[1],color_data[2]))
	visual.material_override=material
	parent.add_child(visual)
	_eye_materials.append(material)
