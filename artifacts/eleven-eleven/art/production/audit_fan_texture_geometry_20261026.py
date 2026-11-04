"""Run inside the saved Blender project;read-only role/vertex audit,not art acceptance."""
import bpy,json,pathlib,math
from mathutils.kdtree import KDTree

def audit():
    records=[]
    for source_name,textured_name in [('Fan_FrameMesh','FanPBRFrame'),('Fan_RotorMesh','FanPBRRotor')]:
        a=bpy.data.objects[source_name];b=bpy.data.objects[textured_name]
        counts=[sum(len(p.vertices)-2 for p in o.data.polygons) for o in [a,b]]
        assert counts[0]==counts[1],(source_name,counts)
        distances=[]
        for target,probe in [(a,b),(b,a)]:
            tree=KDTree(len(target.data.vertices))
            for i,v in enumerate(target.data.vertices):tree.insert(target.matrix_world@v.co,i)
            tree.balance();worst=0.;squares=0.
            for v in probe.data.vertices:
                distance=tree.find(probe.matrix_world@v.co)[2]
                worst=max(worst,distance);squares+=distance*distance
            distances.append({'target':target.name,'probe':probe.name,'vertices':len(probe.data.vertices),'max_distance_m':worst,'rms_distance_m':math.sqrt(squares/max(1,len(probe.data.vertices)))})
        assert all(d['max_distance_m']<.0002 for d in distances),(source_name,distances)
        records.append({'canonical':source_name,'textured':textured_name,'triangles_each':counts[0],'distances':distances})
    return {'status':'PASS','scope':'Same triangle count per rigid role and full bidirectional vertex-nearest error <.2mm after documented normalization restore. Does not prove identical indices,continuous collision,texture quality or Godot acceptance.','roles':records,'pivot_at_world_origin':list(bpy.data.objects['FanPBRRotorPivot'].matrix_world.translation)}

if __name__=='__main__':
    result=audit()
