"""Measure evaluated shoe skin and full-take loop seams, without source writes."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Vector


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--clip', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    metadata = json.loads(args.clip.with_suffix('.json').read_text(encoding='utf-8'))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.clip.resolve()))
    rig = next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    action = rig.animation_data.action
    meshes = [o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    selections = {}
    for side in ['Left','Right']:
        weighted = []
        for mesh in meshes:
            group_ids = {g.index for g in mesh.vertex_groups if g.name.rsplit(':',1)[-1] in [side+'Foot',side+'ToeBase']}
            for vertex in mesh.data.vertices:
                if sum(group.weight for group in vertex.groups if group.group in group_ids) >= .65:
                    world = mesh.matrix_world @ vertex.co
                    weighted.append((mesh,vertex.index,world.z))
        if not weighted:
            raise ValueError('No independent shoe skin weights for '+side)
        bottom = min(item[2] for item in weighted)
        selections[side] = [(mesh,index) for mesh,index,z in weighted if z <= bottom+.012]
    rig.data.pose_position = 'POSE'
    bpy.context.scene.render.fps = 30
    gaps = {side:[] for side in selections}
    endpoints = []
    for index in range(metadata['samples']):
        bpy.context.scene.frame_set(index)
        bpy.context.view_layer.update()
        if index in [0, metadata['samples']-1]:
            endpoints.append({bone.name:(rig.matrix_world @ bone.matrix).copy() for bone in rig.pose.bones})
        graph = bpy.context.evaluated_depsgraph_get()
        evaluated = {mesh:mesh.evaluated_get(graph).to_mesh() for mesh in meshes}
        for side, vertices in selections.items():
            heights = [(mesh.matrix_world @ evaluated[mesh].vertices[i].co).z for mesh,i in vertices]
            time = index/30
            planted = any(interval['start']-1e-6 <= time <= interval['end']+1e-6 for interval in metadata['contact_intervals'][side.lower()])
            gaps[side].append({'time':time, 'planted':planted, 'lowest_sole_m':min(heights),
                               'sole_height_10th_percentile_m':float(np.quantile(heights,.1))})
        for mesh in meshes:
            mesh.evaluated_get(graph).to_mesh_clear()
    angular = {}
    for name in endpoints[0]:
        angle = math.degrees(endpoints[0][name].to_quaternion().rotation_difference(endpoints[1][name].to_quaternion()).angle)
        angular[name] = min(angle,360-angle)  # q and -q represent the same rotation.
    positional = {name:(endpoints[0][name].translation-endpoints[1][name].translation).length for name in endpoints[0]}
    report = {'status':'MEASURED', 'action':action.name, 'samples':metadata['samples'],
              'sole_vertex_counts':{side:len(vertices) for side,vertices in selections.items()},
              'sole_measurements':gaps, 'loop_max_joint_angle_degrees':max(angular.values()),
              'loop_max_joint_position_delta_m':max(positional.values()), 'loop_angles':angular,
              'stance_summary':{},
              'limits':'Lowest evaluated shoe skin versus flat Z=0; inferred source stance; full-take endpoints without trimming/blending. This does not approve sole traction, loop playback, clothing, face, fingers or gameplay.'}
    for side in gaps:
        samples = [sample for sample in gaps[side] if sample['planted']]
        report['stance_summary'][side] = {'samples':len(samples),
            'min_lowest_sole_m':min((sample['lowest_sole_m'] for sample in samples),default=None),
            'max_lowest_sole_m':max((sample['lowest_sole_m'] for sample in samples),default=None)}
    args.output.write_text(json.dumps(report,indent=2)+'\n', encoding='utf-8')
    print('SKIN_REVIEW '+json.dumps({key:report[key] for key in ['sole_vertex_counts','stance_summary','loop_max_joint_angle_degrees','loop_max_joint_position_delta_m']}), flush=True)


if __name__ == '__main__': main()
