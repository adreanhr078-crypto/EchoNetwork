"""Revision 5 -> 6: conceal the raised service panel behind its mechanical housing."""
import bpy
obj = bpy.data.objects['ServiceAccess_HeaderCover']
obj.location = (0, 12.66, 8.48)
obj.dimensions = (2.7, .42, 2.3)
bpy.context.view_layer.update()
result = {'cover':{'location':list(obj.location), 'dimensions':list(obj.dimensions)},
          'doorOpenTop':9.41, 'housingTop':9.63, 'routeUnchanged':True}
