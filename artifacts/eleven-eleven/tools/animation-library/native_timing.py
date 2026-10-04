"""Read original FBX TimeMode without importing/altering animation or scene FPS."""
import importlib
from pathlib import Path
import sys
import types


def read_native_fps(path):
    folder = Path('C:/Tools/Blender-5.2.2-portable/blender-5.2.2-windows-x64/5.2/scripts/addons_core/io_scene_fbx')
    name = '_echo_native_fbx'
    if name not in sys.modules:
        package = types.ModuleType(name)
        package.__path__ = [str(folder)]
        sys.modules[name] = package
    parser = importlib.import_module(name+'.parse_fbx')
    root,version = parser.parse(str(path))
    settings = next(n for n in root.elems if n.id == b'GlobalSettings')
    properties = next(n for n in settings.elems if n.id == b'Properties70')
    values = {n.props[0].decode():n.props[4] for n in properties.elems
              if n.id == b'P' and n.props[0] in [b'TimeMode',b'CustomFrameRate']}
    # Same documented table as this pinned Blender FBX importer.
    rates = {1:120,2:100,3:60,4:50,5:48,6:30,7:30,8:30/1.001,9:30/1.001,
             10:25,11:24,13:24/1.001,15:96,16:72,17:60/1.001,18:120/1.001}
    fps = rates.get(values.get('TimeMode'),values.get('CustomFrameRate',-1))
    if fps <= 0:
        raise ValueError('Native FBX frame rate is unspecified; isolate timing')
    return {'fbx_version':version,'time_mode':values['TimeMode'],'custom_frame_rate':values.get('CustomFrameRate'),
            'native_fps':fps,'evidence':'Original binary FBX GlobalSettings, no FPS relabeling'}


def validate_timing(scene_fps,candidate,first,last,native):
    if (scene_fps != 30 or candidate['fps'] != 30 or native['native_fps'] != 30
            or first != 1 or int(last) != last or [first,last] != candidate['source_frame_range']):
        raise ValueError('Native/metadata/import timing differs from Golden 30fps/start-1 contract; isolate before proceeding')
