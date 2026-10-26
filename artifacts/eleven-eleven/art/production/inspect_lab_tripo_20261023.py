"""Read-only source geometry audit and neutral four-angle Blender inspection."""
import bpy, sys, json, hashlib, math
from pathlib import Path
from mathutils import Vector

args=sys.argv[sys.argv.index('--')+1:]
source=Path(args[0]).resolve(); out=Path(args[1]).resolve();out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
report={'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'bytes':source.stat().st_size,'bounds_blender_m':[list(lo),list(hi)],'extent_m':list(hi-lo),
 'objects':[],'images':[],'note':'Neutral source inspection; no game/rig/art acceptance.'}
for o in meshes:
 o.data.calc_loop_triangles()
 corners=[o.matrix_world@Vector(c) for c in o.bound_box]
 report['objects'].append({'name':o.name,'vertices':len(o.data.vertices),'triangles':len(o.data.loop_triangles),
  'materials':[m.name if m else None for m in o.data.materials], 'uv_layers':len(o.data.uv_layers),
  'bounds_blender_m':[[min(p[i] for p in corners) for i in range(3)],[max(p[i] for p in corners) for i in range(3)]]})
for im in bpy.data.images:
 report['images'].append({'name':im.name,'size':list(im.size),'packed':bool(im.packed_file)})
report['triangles']=sum(o['triangles'] for o in report['objects'])
(out/'source-audit.json').write_text(json.dumps(report,indent=2)+'\n')
if '--save-blend' in args:bpy.ops.wm.save_as_mainfile(filepath=str(out/'inspected-source.blend'))
if '--audit-only' in args:
 print('SOURCE_AUDIT_ONLY',report['triangles'],len(meshes));sys.exit(0)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=720;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world.color=(.16,.16,.16)
scene.view_settings.view_transform='AgX'
center=(hi+lo)*.5;radius=max(hi-lo)
for name,offset,power,size in [('Key',(-2,-3,4),950,3),('Fill',(3,-1,2),600,3),('Rim',(1,3,3),1000,2)]:
 data=bpy.data.lights.new(name,'AREA');data.energy=power*radius*radius;data.shape='DISK';data.size=size*radius
 light=bpy.data.objects.new(name,data);scene.collection.objects.link(light)
 light.location=center+Vector(offset)*radius
 light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
camdata=bpy.data.cameras.new('InspectionCamera');cam=bpy.data.objects.new('InspectionCamera',camdata)
scene.collection.objects.link(cam);scene.camera=cam;camdata.type='ORTHO';camdata.ortho_scale=radius*1.65
for index,deg in enumerate([35,125,215,305],1):
 angle=math.radians(deg);cam.location=center+Vector((math.sin(angle)*2.6,math.cos(angle)*2.6,1.4))*radius
 cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(out/f'angle-{index:02}.png');bpy.ops.render.render(write_still=True)
print('SOURCE_AUDIT',json.dumps({'triangles':report['triangles'],'extent_m':report['extent_m'],'objects':len(meshes)}))
