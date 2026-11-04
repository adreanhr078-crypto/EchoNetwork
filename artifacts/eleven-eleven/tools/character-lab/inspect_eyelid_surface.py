"""Trace texture-connected ocular surface islands; still no facial edits."""
from collections import Counter,defaultdict
import json
from pathlib import Path
import bpy
from mathutils import Vector

APP=Path(__file__).resolve().parents[2]
out=APP/'art/production/echo-school-rebuild-20261029/face/intake-20261102'
bpy.ops.wm.open_mainfile(filepath=str(out/'ocular-surface-diagnostic.blend'))
mesh=next(obj for obj in bpy.context.scene.objects if obj.type=='MESH')
rows=json.loads((out/'ocular-regions.json').read_text())
points=[mesh.matrix_world@vertex.co for vertex in mesh.data.vertices]
position_ids,unique,vids={},[],[]
for point in points:
    key=tuple(round(value,6) for value in point)
    if key not in position_ids: position_ids[key]=len(unique);unique.append(point)
    vids.append(position_ids[key])
eligible={row['polygon']:row for row in rows['nearby_polygons'] if row['blue_gray_candidate']}
edges=defaultdict(set)
for pid in eligible:
    vertices=[vids[index] for index in mesh.data.polygons[pid].vertices]
    for first,second in zip(vertices,vertices[1:]+vertices[:1]): edges[tuple(sorted((first,second)))].add(pid)
graph=defaultdict(set)
for faces in edges.values():
    for pid in faces: graph[pid].update(faces-{pid})
remaining=set(eligible)
islands=[]
while remaining:
    todo,group=[min(remaining)],set()
    while todo:
        pid=todo.pop()
        if pid in group:continue
        group.add(pid);todo.extend(graph[pid]-group)
    remaining.difference_update(group);islands.append(sorted(group))
centers={side:Vector(point) for side,point in rows['eyes'].items()}
selected={side:min(range(len(islands)),key=lambda index:min((Vector(eligible[pid]['center'])-center).length for pid in islands[index]))
          for side,center in centers.items()}
chosen=set(pid for island in selected.values() for pid in islands[island])
boundary=[]
for edge,faces in edges.items():
    if len(faces&chosen)==1:boundary.append(edge)
attribute=mesh.data.color_attributes.new(name='ConnectedOcularIslands',type='FLOAT_COLOR',domain='CORNER')
for polygon in mesh.data.polygons:
    color=(.05,.8,.8) if polygon.index in chosen else (.45,.47,.50)
    for index in polygon.loop_indices:attribute.data[index].color=(*color,1)
mesh.data.color_attributes.active_color=attribute
curve=bpy.data.curves.new('MeasuredOcularBoundary','CURVE');curve.dimensions='3D';curve.bevel_depth=.00022
for first,second in boundary:
    spline=curve.splines.new('POLY');spline.points.add(1)
    for point,index in zip(spline.points,[first,second]):point.co=(*unique[index],1)
obj=bpy.data.objects.new(curve.name,curve);bpy.context.scene.collection.objects.link(obj)
mat=bpy.data.materials.new('BoundaryOrange');mat.diffuse_color=(1,.25,.05,1);curve.materials.append(mat)
scene=bpy.context.scene;scene.display.shading.color_type='VERTEX';camera=scene.camera
center=sum(centers.values(),Vector())/2;camera.data.ortho_scale=.14
for view,offset in [('front',(0,-3,0)),('threequarter',(1.5,-3,0))]:
    camera.location=center+Vector(offset);camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/f'ocular-islands-{view}.png');bpy.ops.render.render(write_still=True)
adj=defaultdict(set)
for first,second in boundary:adj[first].add(second);adj[second].add(first)
report={'status':'OCULAR_TOPOLOGY_DIAGNOSIS_NOT_APPROVED_EYELID_MASK','source_sha256':rows['source_sha256'],
        'texture_connected_islands':len(islands),'island_sizes':[len(island) for island in islands],
        'selected_iris_nearest_islands':selected,'selected_polygons':sorted(chosen),
        'boundary_edges':boundary,'boundary_positions':{index:list(unique[index]) for index in adj},
        'non_degree2_boundary_vertices':{index:len(neighbors) for index,neighbors in adj.items() if len(neighbors)!=2},
        'vertices_changed':False,'morphs_created':False}
(out/'ocular-islands.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'ocular-island-diagnostic.blend'))
print('OCULAR_ISLANDS',len(islands),selected,[len(islands[i]) for i in selected.values()],len(report['non_degree2_boundary_vertices']))
