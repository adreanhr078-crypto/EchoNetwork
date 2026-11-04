import bpy,pathlib,json,hashlib
from mathutils import Vector
P=pathlib.Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\decon-redesign-20261028\whole-v2');bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(P/'source.glb'));objs=[o for o in bpy.data.objects if o.type=='MESH']
def bounds(objects):
 pts=[o.matrix_world@Vector(c) for o in objects for c in o.bound_box];return Vector(tuple(min(v[i] for v in pts) for i in range(3))),Vector(tuple(max(v[i] for v in pts) for i in range(3)))
lo,hi=bounds(objs);center=(lo+hi)*.5;diag=(hi-lo).length
parts=[]
for o in objs:
 a,b=bounds([o]);parts.append({'name':o.name,'min':list(a),'max':list(b),'size':list(b-a),'center':list((a+b)*.5),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons)})
report={'source_sha256':hashlib.sha256((P/'source.glb').read_bytes()).hexdigest(),'parts':parts,'bounds':[list(lo),list(hi)],'size':list(hi-lo),'triangles':sum(p['triangles'] for p in parts),'source':'source.glb','scope':'Actual imported geometry,not thumbnail or reference;no native acceptance'}
(P/'raw-inspection.json').write_text(json.dumps(report,indent=2));bpy.ops.wm.save_as_mainfile(filepath=str(P/'source.blend'))
grey=bpy.data.materials.new('Neutral geometry inspection only');grey.diffuse_color=(.45,.48,.50,1);grey.use_nodes=True;grey.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.45,.48,.50,1);grey.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.62
for o in objs:o.data.materials.clear();o.data.materials.append(grey)
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=1280;s.render.resolution_y=960;s.render.resolution_percentage=100;s.world=bpy.data.worlds.new('Neutral inspection');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.14,.17,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.6
s.eevee.taa_render_samples=32
for loc,energy,size in [((1,-2,3),400,4),((-2,1,3),300,4),((2,2,2),350,3)]:
 bpy.ops.object.light_add(type='AREA',location=center+Vector(loc)*diag);o=bpy.context.object;o.data.energy=energy;o.data.shape='DISK';o.data.size=size*diag;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;s.camera=cam;cam.data.type='ORTHO';cam.data.clip_start=.001;cam.data.ortho_scale=diag*.92
for name,offset in [('front',(1,-1.4,1.45)),('back',(-1,1.4,1.45)),('top',(0,0,2.5))]:
 cam.location=center+Vector(offset)*diag;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(P/('geometry-'+name+'.png'));bpy.ops.render.render(write_still=True)
print('WHOLE_V2_INSPECTED',len(objs),report['triangles'],report['size'])
