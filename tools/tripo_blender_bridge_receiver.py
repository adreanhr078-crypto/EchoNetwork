"""Persist a Tripo DCC Bridge import into the Echo Network source archive.

Run this script with the portable Blender GUI.  It waits for the Tripo bridge
to finish importing a substantial mesh, then saves the untouched source scene.
The timer keeps all Blender work on the main thread, matching the bridge's
import requirements.
"""

from pathlib import Path
import time

import bpy


OUTPUT_BLEND = Path(
    r"C:\Users\yasmo\Documents\Codex\2026-09-11\create-an-image-of-3"
    r"\EchoNetwork\artifacts\eleven-eleven\art\production"
    r"\echo-tripo-hd-v31-8k\Echo_Tripo_HD_v31_8K_Source.blend"
)
READY_MARKER = OUTPUT_BLEND.with_suffix(".ready.txt")

_last_signature = None
_stable_since = None
_saved = False


def _scene_signature():
    mesh_objects = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    polygons = sum(len(obj.data.polygons) for obj in mesh_objects)
    vertices = sum(len(obj.data.vertices) for obj in mesh_objects)
    return len(mesh_objects), polygons, vertices


def _save_when_stable():
    global _last_signature, _stable_since, _saved

    if _saved:
        return None

    signature = _scene_signature()
    mesh_count, polygons, vertices = signature

    # Ignore Blender's startup cube and wait for the high-resolution source.
    if mesh_count == 0 or polygons < 500_000:
        _last_signature = signature
        _stable_since = None
        return 2.0

    if signature != _last_signature:
        _last_signature = signature
        _stable_since = time.monotonic()
        return 2.0

    if _stable_since is None:
        _stable_since = time.monotonic()
        return 2.0

    if time.monotonic() - _stable_since < 6.0:
        return 2.0

    OUTPUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND), check_existing=False)
    READY_MARKER.write_text(
        f"saved={time.strftime('%Y-%m-%dT%H:%M:%S')}\n"
        f"mesh_objects={mesh_count}\n"
        f"polygons={polygons}\n"
        f"vertices={vertices}\n",
        encoding="utf-8",
    )
    _saved = True
    print(f"TRIPO_SOURCE_SAVED {OUTPUT_BLEND} {signature}", flush=True)
    return None


bpy.app.timers.register(_save_when_stable, first_interval=2.0, persistent=True)
print("TRIPO_RECEIVER_READY", flush=True)
