"""Content-addressed native lab;no production scene/import setting is written."""
import hashlib,json,shutil,subprocess
from pathlib import Path
APP=Path(__file__).resolve().parents[2]
case=APP/'art/production/echo-school-rebuild-20261029/face/blink-retopology-20261102'
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
source=case/'diagnostic-blink.glb';report=json.loads((case/'diagnostic-export.json').read_text())
assert sha(source)==report['glb_sha256']
project=APP/'.tmp/echo-character-lab/cases'/('blink-'+sha(source)[:12]+'-godot');project.mkdir(parents=True,exist_ok=True)
if not (project/'candidate.glb').exists() or sha(project/'candidate.glb')!=sha(source):shutil.copy2(source,project/'candidate.glb')
(project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Isolated School65 blink diagnostic"\n[display]\nwindow/size/viewport_width=960\nwindow/size/viewport_height=960\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
(project/'native_profile.gd').write_text('''extends SceneTree
func _initialize() -> void:
 var config:=ConfigFile.new()
 assert(config.load("res://candidate.glb.import")==OK)
 assert(config.has_section_key("params","meshes/force_disable_compression"))
 config.set_value("params","meshes/force_disable_compression",true)
 config.set_value("params","meshes/generate_lods",false)
 assert(config.save("res://candidate.glb.import")==OK)
 var methods:=ClassDB.class_get_method_list("MeshInstance3D",true)
 var keep:=[]
 for method in methods:
  if str(method.name).contains("bake_mesh") or str(method.name).contains("blend_shape"):keep.append(method)
 var file:=FileAccess.open("res://mesh-api.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(keep,"\\t"));file.close()
 print("BLINK_ISOLATED_IMPORT_PROFILE_PASS")
 quit()
''',encoding='utf-8')
godot='C:/Tools/Godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe'
def run(name,args):
 with (project/(name+'.log')).open('w',encoding='utf-8') as file:result=subprocess.run([godot,'--headless','--path',str(project),*args],stdout=file,stderr=subprocess.STDOUT,timeout=120)
 text=(project/(name+'.log')).read_text(encoding='utf-8',errors='replace')
 if result.returncode or 'SCRIPT ERROR:' in text or 'ERROR:' in text:raise RuntimeError(name+':'+text[-1500:])
run('import',['--editor','--import']);run('profile',['--script','res://native_profile.gd']);run('reimport',['--editor','--import'])
(case/'native-lab-project.json').write_text(json.dumps({'project':str(project),'source_glb_sha256':sha(source),'renderer':'Compatibility','force_disable_mesh_compression':True,'generate_lods':False,'runtime_integrated':False},indent=2)+'\n')
print('BLINK_NATIVE_LAB_READY',project)
