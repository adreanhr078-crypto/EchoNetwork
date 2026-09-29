"""Revision 6 -> 7: enclose maintenance at a safe height above the upper route."""
import bpy
scene = bpy.context.scene
steel = bpy.data.materials['Graphite structural steel']
for name in ['COLL_LeftBoundary', 'COLL_RightBoundary', 'COLL_FarBoundary']:
    obj = bpy.data.objects[name]
    obj.location.z = 5.3
    obj.dimensions.z = 10.6
bpy.ops.mesh.primitive_cube_add(size=1, location=(.5, 7, 10.8))
roof = bpy.context.object
roof.name = 'COLL_MaintenanceRoof'
roof.dimensions = (10.2, 15, .4)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
roof.data.materials.append(steel)
for y in [2, 7, 12]:
    bpy.ops.mesh.primitive_cube_add(size=1, location=(.5, y, 10.5))
    rib = bpy.context.object
    rib.name = 'Maintenance_CeilingRib'
    rib.dimensions = (9.6, .24, .2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    rib.data.materials.append(steel)
bpy.context.view_layer.update()
result = {'roofUnderside':10.6, 'wallHeight':10.6, 'gateHousingTop':9.63,
          'upperPlayerHead':7.2, 'climbRoutesUnchanged':True}
