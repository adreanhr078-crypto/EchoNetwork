"""Read-only upward-surface measurement from the preserved complete room."""
import bpy
import json
from pathlib import Path
import numpy as np

A=Path(__file__).resolve().parents[2]
G=A/'art/production/maintenance-parkour-rebuild-20261027'
report=json.loads((G/'raw-room-geometry-report.json').read_text())
scale=18/report['size_blender'][0]
scene=bpy.data.scenes['NEW_STORMWORKS_ROOM_RAW_REVIEW_20261027']
records=[]
for obj in scene.objects:
    if obj.type!='MESH':continue
    mesh=obj.data
    n=len(mesh.polygons)
    if len(mesh.loops)!=3*n:continue
    normals=np.empty(n*3,dtype=np.float32);mesh.polygons.foreach_get('normal',normals)
    centers=np.empty(n*3,dtype=np.float32);mesh.polygons.foreach_get('center',centers)
    areas=np.empty(n,dtype=np.float32);mesh.polygons.foreach_get('area',areas)
    m=np.asarray(obj.matrix_world,dtype=np.float64)
    normal_matrix=np.asarray(obj.matrix_world.to_3x3().inverted().transposed(),dtype=np.float64)
    world_normals=normals.reshape((-1,3))@normal_matrix.T
    world_centers=(centers.reshape((-1,3))@m[:3,:3].T+m[:3,3])*scale
    up=world_normals[:,2]>.96
    levels=np.rint(world_centers[:,2]/.05).astype(np.int32)
    candidates=[]
    vertices=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',vertices)
    vertices=(vertices.reshape((-1,3))@m[:3,:3].T+m[:3,3])*scale
    indices=np.empty(len(mesh.loops),dtype=np.int32);mesh.loops.foreach_get('vertex_index',indices)
    indices=indices.reshape((-1,3))
    for level in np.unique(levels[up]):
        selected=up&(levels==level)
        area=float(areas[selected].sum())*scale*scale
        if area<.3:continue
        points=vertices[indices[selected].reshape(-1)]
        candidates.append({'height_blender_z_m':round(float(level)*.05,3),
                           'surface_area_m2':round(area,3),'triangle_count':int(selected.sum()),
                           'min_blender_m':np.min(points,axis=0).round(4).tolist(),
                           'max_blender_m':np.max(points,axis=0).round(4).tolist()})
    candidates.sort(key=lambda r:r['surface_area_m2'],reverse=True)
    records.append({'part':obj.name,'upward_surfaces':candidates[:12]})
out={'status':'MEASURED_SOURCE_SURFACES_NOT_PLAYABILITY_ACCEPTED',
     'source_sha256':report['source_sha256'],'uniform_scale':scale,
     'axes':'Blender XYZ;Z is vertical. Native entrance/orientation not assumed.',
     'parts':records}
(G/'upward-surface-measurements.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print('UPWARD_SURFACES '+json.dumps(out))
