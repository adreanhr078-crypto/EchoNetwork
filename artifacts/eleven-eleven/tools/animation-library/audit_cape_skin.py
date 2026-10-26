"""Independent actual triangle intersections from Godot's native skin export.

Run with Blender Python for mathutils.BVHTree and NumPy. This reads evidence
only; it never adjusts source vertices, animation keys or runtime state.
"""
import argparse
import json
from pathlib import Path
import sys

import numpy as np
from mathutils.bvhtree import BVHTree

p = argparse.ArgumentParser()
p.add_argument('--evidence', type=Path, required=True)
p.add_argument('--render-worst', action='store_true')
a = p.parse_args(sys.argv[sys.argv.index('--')+1:])
folder = a.evidence.resolve()
data = json.loads((folder/'skin-poses.json').read_text(encoding='utf-8'))

# Prove that this installed BVH tests triangles, not overlapping bounding boxes.
first = BVHTree.FromPolygons([(0,0,0),(2,0,0),(0,2,0)],[(0,1,2)],all_triangles=True)
apart = BVHTree.FromPolygons([(2,2,0),(2,.5,0),(.5,2,0)],[(0,1,2)],all_triangles=True)
assert not first.overlap(apart), 'Bounding-box-only overlap cannot prove a garment intersection'
crossing = BVHTree.FromPolygons([(.4,.4,-1),(.4,.4,1),(.8,.8,0)],[(0,1,2)],all_triangles=True)
assert first.overlap(crossing), 'The independent triangle crossing probe must be detected'

surfaces = []
for surface in data['surfaces']:
    prefix = folder/surface['prefix']
    vertices = np.fromfile(str(prefix)+'-vertices.bin', dtype='<f4').reshape(-1,3)
    joints = np.fromfile(str(prefix)+'-bones.bin', dtype='<i4').reshape(len(vertices),-1)
    weights = np.fromfile(str(prefix)+'-weights.bin', dtype='<f4').reshape(joints.shape)
    triangles = np.fromfile(str(prefix)+'-indices.bin', dtype='<i4')
    if not len(triangles): triangles = np.arange(len(vertices))
    triangles = triangles.reshape(-1,3)
    names = np.array([data['bone_names'][i] for i in surface['bind_ids']])
    cape = np.array([name.startswith('Cape_') for name in names])
    legs = np.array([name in {side+part for side in ['Left','Right'] for part in ['UpLeg','Leg','Foot','ToeBase']} for name in names])
    cloth_weight = (cape[joints]*weights).sum(axis=1)
    leg_weight = (legs[joints]*weights).sum(axis=1)
    cloth_faces = triangles[np.min(cloth_weight[triangles],axis=1)>.5]
    body_faces = triangles[np.min(leg_weight[triangles],axis=1)>.5]
    cloth_ids, local_cloth = np.unique(cloth_faces,return_inverse=True)
    body_ids, local_body = np.unique(body_faces,return_inverse=True)
    surfaces.append({'vertices':np.c_[vertices,np.ones(len(vertices),dtype=np.float32)],
                     'joints':joints,'weights':weights,
                     'cloth_ids':cloth_ids,'body_ids':body_ids,
                     'triangles':triangles,'cloth_mask':np.min(cloth_weight[triangles],axis=1)>.5,'leg_mask':np.min(leg_weight[triangles],axis=1)>.5,
                     'cloth_faces':local_cloth.reshape(-1,3).tolist(),
                     'body_faces':local_body.reshape(-1,3).tolist()})
assert sum(len(s['cloth_faces']) for s in surfaces) and sum(len(s['body_faces']) for s in surfaces), 'Actual garment and leg skin must be present across the avatar surfaces'

records = []
for pose in data['poses']:
    cloth_trees, body_trees = [], []
    for index, surface in enumerate(surfaces):
        transforms = np.array(pose['matrices'][index],dtype=np.float32)
        points = np.zeros((len(surface['vertices']),3),dtype=np.float32)
        for slot in range(surface['joints'].shape[1]):
            points += np.einsum('nij,nj->ni',transforms[surface['joints'][:,slot]],surface['vertices'])*surface['weights'][:,slot,None]
        assert np.isfinite(points).all()
        if surface['cloth_faces']:
            cloth_trees.append(BVHTree.FromPolygons(points[surface['cloth_ids']].tolist(),surface['cloth_faces'],all_triangles=True,epsilon=1e-7))
        if surface['body_faces']:
            body_trees.append(BVHTree.FromPolygons(points[surface['body_ids']].tolist(),surface['body_faces'],all_triangles=True,epsilon=1e-7))
    overlaps = sum(len(cloth.overlap(body)) for cloth in cloth_trees for body in body_trees)
    records.append({'clip':pose['clip'],'time':pose['time'],'crossing_triangle_pairs':overlaps})
summary = {}
for record in records:
    item = summary.setdefault(record['clip'],{'samples':0,'affected_samples':0,'maximum_crossing_pairs':0,'worst_time':0})
    item['samples'] += 1
    item['affected_samples'] += int(record['crossing_triangle_pairs']>0)
    if record['crossing_triangle_pairs'] > item['maximum_crossing_pairs']:
        item['maximum_crossing_pairs'] = record['crossing_triangle_pairs']
        item['worst_time'] = record['time']
report = {'status':'MEASURED_NOT_ART_ACCEPTANCE','scope':'Actual skinned triangles with all three cloth/leg vertex weights >0.5; seam/other body/cloth self-collision excluded. BVH triangle discrimination checked independently.',
          'source_hashes':data['source_hashes'],'protected_body_checks':data['protected_body_checks'],
          'source_only':data['source_only'],'reduced_motion':data['reduced_motion'],
          'geometry':[{'cloth_triangles':len(s['cloth_faces']),'leg_triangles':len(s['body_faces'])} for s in surfaces],
          'clips':summary,'poses':records}
(folder/'triangle-review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('CAPE_ACTUAL_TRIANGLES',json.dumps(summary),flush=True)

if a.render_worst:
    import bpy
    from mathutils import Vector
    for clip in ['IDLE','RUN']:
        pose = next(p for p in data['poses'] if p['clip']==clip and p['time']==summary[clip]['worst_time'])
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene = bpy.context.scene
        materials=[]
        for name,color in [('body',(.08,.10,.13,1)),('cloth',(.75,.70,.85,1)),('legs',(.15,.65,.8,1))]:
            material=bpy.data.materials.new(name)
            material.diffuse_color=color
            materials.append(material)
        bounds=[]
        for index,surface in enumerate(surfaces):
            transforms=np.array(pose['matrices'][index],dtype=np.float32)
            points=np.zeros((len(surface['vertices']),3),dtype=np.float32)
            for slot in range(surface['joints'].shape[1]):
                points+=np.einsum('nij,nj->ni',transforms[surface['joints'][:,slot]],surface['vertices'])*surface['weights'][:,slot,None]
            points=points[:,[0,2,1]]
            points[:,1]*=-1
            mesh=bpy.data.meshes.new('actual-skinned-triangles')
            mesh.from_pydata(points.tolist(),[],surface['triangles'].tolist())
            mesh.update()
            ob=bpy.data.objects.new('ActualGodotSkin',mesh)
            scene.collection.objects.link(ob)
            for material in materials:mesh.materials.append(material)
            ids=np.zeros(len(surface['triangles']),dtype=np.int32)
            ids[surface['cloth_mask']]=1
            ids[surface['leg_mask']]=2
            mesh.polygons.foreach_set('material_index',ids)
            bounds.extend([points.min(axis=0),points.max(axis=0)])
        low=np.min(bounds,axis=0);high=np.max(bounds,axis=0)
        center=Vector((low+high)*.5)
        scene.render.engine='BLENDER_WORKBENCH'
        scene.display.shading.light='STUDIO'
        scene.display.shading.color_type='MATERIAL'
        scene.display.shading.show_shadows=True
        scene.display.shading.show_cavity=True
        scene.world=bpy.data.worlds.new('DiagnosticWorld')
        scene.world.color=(.04,.05,.07)
        scene.render.resolution_x=640;scene.render.resolution_y=800;scene.render.resolution_percentage=100
        scene.render.image_settings.file_format='PNG'
        camera=bpy.data.objects.new('DiagnosticCamera',bpy.data.cameras.new('DiagnosticCamera'))
        scene.collection.objects.link(camera);scene.camera=camera
        camera.data.type='ORTHO';camera.data.ortho_scale=float(max(high-low)*1.18)
        for view,offset in [('rear',(0,4,0)),('side',(4,0,0)),('front',(0,-4,0))]:
            camera.location=center+Vector(offset)
            camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath=str(folder/f'{clip}-{view}-actual-skin.png')
            bpy.ops.render.render(write_still=True)
