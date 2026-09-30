"""Write a repeatable Godot visual/kinematic review scene for a derived clip."""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--clip", default="walk-pilot.glb")
parser.add_argument("--action", default="Walk_Forward")
parser.add_argument("--prefix", default="walk")
args = parser.parse_args()

root = Path.cwd() / ".tmp/master-animation-library/godot-review"
source = r'''extends SceneTree
func _initialize() -> void:
 call_deferred("inspect")
func inspect() -> void:
 var scene = Node3D.new()
 root.add_child(scene)
 var model = load("res://walk-pilot.glb").instantiate()
 scene.add_child(model)
 var skeleton = model.find_child("Skeleton3D",true,false) as Skeleton3D
 var ap = model.find_child("AnimationPlayer",true,false) as AnimationPlayer
 if not ap: push_error("No AnimationPlayer"); quit(1); return
 var names = ap.get_animation_list()
 print("REVIEW_ANIMATIONS "+str(names))
 if not names.has("Walk_Forward"): push_error("Retargeted Walk_Forward missing"); quit(1); return
 var selected = "Walk_Forward"
 var anim = ap.get_animation(selected)
 var light = DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-30,-25,0)
 light.light_energy = 1.3
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
 camera.position = Vector3(0,0.9,-3)
 scene.add_child(camera)
 camera.look_at(Vector3(0,0.9,0),Vector3.UP)
 camera.current = true
 root.content_scale_size = Vector2i(1280,720)
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
 root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
 var left = skeleton.find_bone("mixamorig_LeftToeBase")
 var right = skeleton.find_bone("mixamorig_RightToeBase")
 var poses = []
 for i in range(31):
  var t = anim.length * i/30.0
  ap.play(selected)
  ap.seek(t,true)
  await process_frame
  var lp = skeleton.to_global(skeleton.get_bone_global_pose(left).origin)
  var rp = skeleton.to_global(skeleton.get_bone_global_pose(right).origin)
  poses.append({"time":t,"left":[lp.x,lp.y,lp.z],"right":[rp.x,rp.y,rp.z]})
  if i in [0,8,15,23,30]:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://walk-%02d.png" % i)
 var file = FileAccess.open("res://walk-poses.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"animation":selected,"duration":anim.length,"poses":poses},"\t"))
 file.close()
 print("REVIEW_MOTION_DONE frames="+str(poses.size())+" duration="+str(anim.length))
 quit()
'''
source = source.replace("walk-pilot.glb", args.clip).replace("Walk_Forward", args.action)
source = source.replace("walk-%02d.png", args.prefix+"-%02d.png").replace("walk-poses.json", args.prefix+"-poses.json")
(root / "review_motion.gd").write_text(source, encoding="utf-8")
print(root / "review_motion.gd")
