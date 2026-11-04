"""Review a real mesh-edge skin rim before any local eye retopology.

Anatomical iris/sclera outlines seed the search. Mesh paths, not an axis-aligned
box, define the candidate region. This script never changes source geometry.
"""
from collections import Counter,defaultdict
import argparse
import heapq
import json
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Vector

APP=Path(__file__).resolve().parents[2]
out=APP/'art/production/echo-school-rebuild-20261029/face/intake-20261102'
parser=argparse.ArgumentParser();parser.add_argument('--no-render',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
bpy.ops.wm.open_mainfile(filepath=str(out/'head-topology-diagnostic.blend'))
mesh=next(obj for obj in bpy.context.scene.objects if obj.type=='MESH')
mesh.modifiers['DiagnosticWireOnly'].show_render=False
components=json.loads((out/'component-vertices.json').read_text())
mask=json.loads((out/'blink-whole-eye-mask-preview.json').read_text())
ocular=json.loads((out/'ocular-regions.json').read_text())
vids=mask['original_to_welded']
points=[mesh.matrix_world@vertex.co for vertex in mesh.data.vertices]
unique={vids[index]:point for index,point in enumerate(points)}
skin=set(components[0])
graph=defaultdict(dict);edge_faces=defaultdict(set)
vertex_faces=defaultdict(set)
for polygon in mesh.data.polygons:
    if not all(index in skin for index in polygon.vertices):continue
    indices=[vids[index] for index in polygon.vertices]
    for index in indices:vertex_faces[index].add(polygon.index)
    for first,second in zip(indices,indices[1:]+indices[:1]):
        if first==second:continue
        graph[first][second]=(unique[first]-unique[second]).length
        graph[second][first]=graph[first][second]
        edge_faces[tuple(sorted((first,second)))].add(polygon.index)
source_hole_adjacent=defaultdict(set)
for (first,second),faces in edge_faces.items():
    if len(faces)==1:source_hole_adjacent[first].add(second);source_hole_adjacent[second].add(first)
source_holes={};remaining=set(source_hole_adjacent)
while remaining:
    todo=[min(remaining)];nodes=set()
    while todo:
        index=todo.pop()
        if index in nodes:continue
        nodes.add(index);todo.extend(source_hole_adjacent[index]-nodes)
    remaining.difference_update(nodes)
    edges={tuple(sorted((first,second))) for first in nodes for second in source_hole_adjacent[first]}
    for index in nodes:source_holes[index]=edges
# The first candidate exposed existing broken/nonmanifold skin edges. Route
# around them rather than accepting a rim that cannot bound a connected patch.
for first in list(graph):
    graph[first]={second:length for second,length in graph[first].items()
                  if len(edge_faces[tuple(sorted((first,second)))])==2}
warm=set()
for row in ocular['nearby_polygons']:
    if row['component']==0 and row['rgb'][0]-row['rgb'][2]>=.035:
        warm.update(vids[index] for index in mesh.data.polygons[row['polygon']].vertices)
assert warm

def segment_distance(point,first,second):
    direction=second-first
    t=max(0,min(1,(point-first).dot(direction)/max(direction.length_squared,1e-12)))
    return (point-first-t*direction).length

def corridor_costs(curve):
    # Local anatomical curve/depth corridor bounds this diagnosis, not a box.
    costs={};center=sum(curve,Vector())/len(curve)
    for index in graph:
        if (unique[index]-center).length>.045:continue
        distance=min(segment_distance(unique[index],a,b) for a,b in zip(curve,curve[1:]+curve[:1]))
        if distance<.010:costs[index]=1+(distance/.0025)**2+(0 if index in warm else 16)
    return costs

def shortest(first,last,costs):
    todo=[(0,first)];dist={first:0};previous={}
    while todo:
        distance,index=heapq.heappop(todo)
        if distance!=dist[index]:continue
        if index==last:break
        for neighbor,length in graph[index].items():
            if neighbor not in costs:continue
            proposed=distance+length*(costs[index]+costs[neighbor])*.5
            if proposed<dist.get(neighbor,float('inf')):
                dist[neighbor]=proposed;previous[neighbor]=index;heapq.heappush(todo,(proposed,neighbor))
    if last not in dist:raise ValueError('No real skin-edge path between semantic rim anchors')
    path=[last]
    while path[-1]!=first:path.append(previous[path[-1]])
    return list(reversed(path))

results={}
for side,eye in mask['eyes'].items():
    lower=eye['lower_silhouette'];upper=eye['upper_silhouette']
    outline=lower+list(reversed(upper))[1:-1]
    center=Vector((sum(p[0] for p in outline)/len(outline),sum(p[1] for p in outline)/len(outline)))
    eye_indices=[index for cid in eye['eye_components'] for index in components[cid]]
    anchors=[];curve=[]
    for x,z in outline:
        radial=Vector((x,z))-center
        if radial.length<1e-8:continue
        p=Vector((x,z))+radial.normalized()*.0045
        nearest=min(eye_indices,key=lambda index:(points[index].x-x)**2+(points[index].z-z)**2)
        anchor=Vector((p.x,points[nearest].y,p.y))
        curve.append(anchor)
        index=min(warm,key=lambda index:(unique[index]-anchor).length_squared)
        if not anchors or anchors[-1]!=index:anchors.append(index)
    if anchors[-1]==anchors[0]:anchors.pop()
    loop=[]
    costs=corridor_costs(curve)
    for first,last in zip(anchors,anchors[1:]+anchors[:1]):loop.extend(shortest(first,last,costs)[:-1])
    unfiltered_duplicates=len(loop)-len(set(loop))
    simple=[]
    for index in loop:
        if index in simple:simple=simple[:simple.index(index)]
        simple.append(index)
    loop=simple
    duplicates=len(loop)-len(set(loop))
    blocked={tuple(sorted(edge)) for edge in zip(loop,loop[1:]+loop[:1])}
    face_graph=defaultdict(set)
    for edge,faces in edge_faces.items():
        if edge in blocked:continue
        for pid in faces:face_graph[pid].update(faces-{pid})
    center3=sum((points[index] for index in eye_indices),Vector())/len(eye_indices)
    seed=min((row for row in ocular['nearby_polygons'] if row['component']==0),key=lambda row:(Vector(row['center'])-center3).length)['polygon']
    group=set();todo=[seed]
    while todo and len(group)<2000:
        pid=todo.pop()
        if pid in group:continue
        group.add(pid);todo.extend(face_graph[pid]-group)
    path_loop=loop[:]
    # Edge-manifold alone is insufficient at pinched/nonmanifold vertices:the
    # previous path included edges with no cut face on either side. Derive the
    # weld rim from the actual bounded face region,expanding at most3 face rings.
    region_loops=[];growth=0;boundary_diagnoses=[]
    for attempt in range(8):
        counts=Counter()
        for pid in group:
            indices=[vids[index] for index in mesh.data.polygons[pid].vertices]
            for first,second in zip(indices,indices[1:]+indices[:1]):
                if first!=second:counts[tuple(sorted((first,second)))]+=1
        boundary={edge for edge,count in counts.items() if count==1}
        adjacent=defaultdict(set)
        for first,second in boundary:adjacent[first].add(second);adjacent[second].add(first)
        remaining=set(adjacent);cycles=[]
        while remaining:
            todo=[min(remaining)];nodes=set()
            while todo:
                index=todo.pop()
                if index in nodes:continue
                nodes.add(index);todo.extend(adjacent[index]-nodes)
            remaining.difference_update(nodes)
            if not all(len(adjacent[index])==2 for index in nodes):continue
            cycle=[min(nodes)];previous=None
            while True:
                nxt=min(adjacent[cycle[-1]]-({previous} if previous is not None else set()))
                if nxt==cycle[0]:break
                previous=cycle[-1];cycle.append(nxt)
                if len(cycle)>len(nodes):raise ValueError('Malformed boundary traversal')
            if len(cycle)==len(nodes):cycles.append(cycle)
        if cycles:
            candidate=max(cycles,key=lambda cycle:sum((unique[a]-unique[b]).length for a,b in zip(cycle,cycle[1:]+cycle[:1])))
            candidate_edges={tuple(sorted(edge)) for edge in zip(candidate,candidate[1:]+candidate[:1])}
            unhandled=[edge for edge in boundary-candidate_edges if len(edge_faces[edge])>1]
            boundary_diagnoses.append({'attempt':attempt,'faces':len(group),'boundary_edges':len(boundary),
                                      'non_degree2_vertices':{index:len(neighbors) for index,neighbors in adjacent.items() if len(neighbors)!=2},
                                      'cycle_lengths':[len(cycle) for cycle in cycles],
                                      'largest_cycle_nonmanifold_edges':[edge for edge in candidate_edges if len(edge_faces[edge])!=2],
                                      'unhandled_interior_edges':unhandled})
            if len(candidate)>12 and all(len(edge_faces[edge])==2 for edge in candidate_edges) and not unhandled:
                loop=candidate;blocked=candidate_edges;region_loops=cycles;break
        else:
            boundary_diagnoses.append({'attempt':attempt,'faces':len(group),'boundary_edges':len(boundary),
                                      'non_degree2_vertices':{index:len(neighbors) for index,neighbors in adjacent.items() if len(neighbors)!=2},
                                      'cycle_lengths':[]})
        if attempt==7:break
        added=set()
        # A source crack touching the cut must be swallowed whole by the local
        # replacement,otherwise its open edge cannot weld to any outside face.
        # Preserve these source cracks in the original;repair only the derivative.
        touched={edge for edge in boundary if len(edge_faces[edge])!=2}
        for edge in touched:
            added.update(edge_faces[edge])
            if len(edge_faces[edge])==1:
                hole=source_holes[edge[0]]
                if len(hole)>64 or max((unique[index]-center3).length for pair in hole for index in pair)>.040:
                    raise ValueError('Source crack exits the reviewed anatomical eye neighborhood')
                for pair in hole:added.update(edge_faces[pair])
        for index,neighbors in adjacent.items():
            if len(neighbors)!=2:added.update(vertex_faces[index])
        if not added-group:
            for edge,faces in edge_faces.items():
                if faces&group:added.update(faces)
        boundary_diagnoses[-1]['added_faces']=len(added-group)
        group.update(added);growth+=1
    duplicates=len(loop)-len(set(loop))
    safe=bool(region_loops) and len(loop)>12 and duplicates==0 and 30<len(group)<1500 and all(len(edge_faces[edge])==2 for edge in blocked)
    results[side]={'status':'CAPTURED_CANDIDATE_PENDING_REVIEW' if safe else 'REJECTED_TOPOLOGY_GATE',
                   'anatomical_anchors':anchors,'loop_welded_vertices':loop,'duplicate_loop_vertices':duplicates,
                   'loop_erased_spurs':unfiltered_duplicates,
                   'initial_path_loop':path_loop,'face_region_growth_rings':growth,
                   'boundary_diagnoses':boundary_diagnoses,
                   'cut_region_polygons':sorted(group) if len(group)<1500 else [],'flood_count':len(group),
                   'nonmanifold_rim_edges':[edge for edge in blocked if len(edge_faces[edge])!=2],
                   'loop_positions':[list(unique[index]) for index in loop]}
    curve_data=bpy.data.curves.new('SemanticRim_'+side,'CURVE');curve_data.dimensions='3D';curve_data.bevel_depth=.00028
    spline=curve_data.splines.new('POLY');spline.points.add(len(loop)-1);spline.use_cyclic_u=True
    for point,index in zip(spline.points,loop):point.co=(*unique[index],1)
    obj=bpy.data.objects.new(curve_data.name,curve_data);bpy.context.scene.collection.objects.link(obj)
    mat=bpy.data.materials.new(curve_data.name);mat.diffuse_color=(1,.15,.4,1);curve_data.materials.append(mat)

attribute=mesh.data.color_attributes.new(name='EyeRimCutCandidate',type='FLOAT_COLOR',domain='CORNER')
chosen=set(pid for row in results.values() for pid in row['cut_region_polygons'])
for polygon in mesh.data.polygons:
    color=(.1,.7,.8) if polygon.index in chosen else (.48,.50,.54)
    for index in polygon.loop_indices:attribute.data[index].color=(*color,1)
mesh.data.color_attributes.active_color=attribute
scene=bpy.context.scene;scene.display.shading.color_type='VERTEX';camera=scene.camera
center=sum((Vector(point) for point in ocular['eyes'].values()),Vector())/2;camera.data.ortho_scale=.17
for view,offset in [('front',(0,-3,0)),('threequarter',(1.5,-3,0)),('reverse-threequarter',(-1.5,-3,0))]:
    camera.location=center+Vector(offset);camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    if not args.no_render:
        scene.render.filepath=str(out/f'eye-rim-region-{view}.png');bpy.ops.render.render(write_still=True)
(out/'eye-rim-region-preview.json').write_text(json.dumps({'status':'REVIEW_ONLY_NO_RETOPOLOGY_OR_MORPHS','source_sha256':mask['source_sha256'],'method':'Anatomical outline -> existing warm-skin anchors -> mesh paths -> bounded faceflood -> actual region boundary with bounded topological ring growth;no geometry change','eyes':results},indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'eye-rim-region-diagnostic.blend'))
print('EYE_RIMS',json.dumps({side:{k:row[k] for k in ['status','duplicate_loop_vertices','flood_count']} for side,row in results.items()}))
