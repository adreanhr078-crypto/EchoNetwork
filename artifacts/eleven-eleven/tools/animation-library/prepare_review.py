"""Isolate unapproved character/animation review from the live Godot project."""
import json
from pathlib import Path
import shutil


root = Path.cwd()
work = root / ".tmp/master-animation-library/godot-review"
work.mkdir(parents=True, exist_ok=True)
source = root / "art/production/echo-master-character/prepared-v1/echo-master-review-lod.glb"
shutil.copy2(source, work / "target.glb")
(work / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Echo Animation Review"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
script = r'''extends SceneTree
var scene: Node3D
func _initialize() -> void:
 call_deferred("inspect")
func inspect() -> void:
 scene = Node3D.new()
 root.add_child(scene)
 var model = load("res://target.glb").instantiate()
 scene.add_child(model)
 var skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
 var bones: Array = []
 for i in range(skeleton.get_bone_count()):
  var rest = skeleton.get_bone_rest(i)
  var global_rest = skeleton.get_bone_global_rest(i)
  var q = rest.basis.get_rotation_quaternion()
  var p = skeleton.get_bone_pose_rotation(i)
  bones.append({"index":i,"name":skeleton.get_bone_name(i),"parent":skeleton.get_bone_parent(i),"local_position":[rest.origin.x,rest.origin.y,rest.origin.z],"local_rotation_xyzw":[q.x,q.y,q.z,q.w],"local_scale":[rest.basis.get_scale().x,rest.basis.get_scale().y,rest.basis.get_scale().z],"pose_rotation_xyzw":[p.x,p.y,p.z,p.w],"global_rest_origin":[global_rest.origin.x,global_rest.origin.y,global_rest.origin.z]})
 var output = {"bones":bones,"skeleton_path":String(model.get_path_to(skeleton)),"source":"new Tripo Echo review LOD"}
 var mesh_bounds: AABB
 var have_mesh := false
 for node in model.find_children("*", "MeshInstance3D", true, false):
  var box: AABB = node.global_transform * node.get_aabb()
  if not have_mesh:
   mesh_bounds = box
   have_mesh = true
  else:
   mesh_bounds = mesh_bounds.merge(box)
 var left_toe := skeleton.find_bone("mixamorig_LeftToeBase")
 var right_toe := skeleton.find_bone("mixamorig_RightToeBase")
 if left_toe < 0 or right_toe < 0 or not have_mesh:
  push_error("Missing character mesh or toe bones")
  quit(1)
  return
 var left_foot_y := skeleton.to_global(skeleton.get_bone_global_rest(left_toe).origin).y
 var right_foot_y := skeleton.to_global(skeleton.get_bone_global_rest(right_toe).origin).y
 output["validation"] = {"mesh_floor_y":mesh_bounds.position.y,"mesh_height_m":mesh_bounds.size.y,
  "left_toe_y":left_foot_y,"right_toe_y":right_foot_y}
 if abs(mesh_bounds.position.y) > 0.05 or abs(mesh_bounds.size.y - 1.76) > 0.05:
  push_error("Echo mesh floor/height failed: "+str(output["validation"]))
  quit(1)
  return
 if abs(left_foot_y - mesh_bounds.position.y) > 0.08 or abs(right_foot_y - mesh_bounds.position.y) > 0.08:
  push_error("Echo toe bones do not align with sole: "+str(output["validation"]))
  quit(1)
  return
 var file = FileAccess.open("res://rig.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(output,"\t"))
 file.close()
 var light = DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-30,-25,0)
 light.light_energy = 1.2
 scene.add_child(light)
 var env = WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color(0.16,0.18,0.22)
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color(0.85,0.87,0.95)
 env.environment.ambient_light_energy = 0.75
 scene.add_child(env)
 var camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 2.2
 scene.add_child(camera)
 camera.current = true
 root.content_scale_size = Vector2i(1280,720)
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
 root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
 for side in ["front","side"]:
  camera.position = Vector3(0,0.9,-3.0) if side=="front" else Vector3(-3,0.9,0)
  camera.look_at(Vector3(0,0.9,0),Vector3.UP)
  for i in range(6): await process_frame
  await RenderingServer.frame_post_draw
  var image = root.get_texture().get_image()
  var result = image.save_png("res://echo-"+side+".png")
  if result != OK: push_error("Capture failed"); quit(1); return
 print("NEW_ECHO_REVIEW_PASS bones="+str(bones.size())+" floor="+str(mesh_bounds.position.y)+" height="+str(mesh_bounds.size.y))
 scene.queue_free()
 await process_frame
 quit()
'''
(work / "review.gd").write_text(script, encoding="utf-8")
print(json.dumps({"review_project": str(work), "source_preserved": True}))
