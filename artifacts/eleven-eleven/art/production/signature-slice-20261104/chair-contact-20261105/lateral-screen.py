"""Screen straight lateral approach lines against the reviewed chair geometry."""
import json, math, sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path.cwd() / "tools/character-lab"))
from author_chair_contact import CHAIR, CHAIR_SCALE, digest, import_mesh

packet = Path("art/production/signature-slice-20261104/chair-contact-20261105")
contact = json.loads((packet / "blender-contact.json").read_text())
chair_hash = digest(CHAIR)
assert chair_hash in contact["sources"].values()
bpy.ops.wm.read_factory_settings(use_empty=True)
chair = next(obj for obj in import_mesh(CHAIR) if obj.type == "MESH")
world = Matrix.Rotation(-math.pi/2, 4, "Z") @ Matrix.Scale(CHAIR_SCALE, 4) @ chair.matrix_world
bvh = BVHTree.FromPolygons([world @ v.co for v in chair.data.vertices], [tuple(p.vertices) for p in chair.data.polygons])
_, seat_y, hip_z = contact["pelvis"]
offsets = (-.40, -.30, 0.0)
samples = []
for side in (-1, 1):
    for offset in offsets:
        hits = []
        for y_tick in range(-15, 16):
            y = seat_y + offset + .01*y_tick
            for z_tick in range(-10, 11):
                z = hip_z + .01*z_tick
                hit, *_ = bvh.ray_cast(Vector((side*.75, y, z)), Vector((-side,0,0)), .45)
                if hit is not None:
                    hits.append([round(float(c), 4) for c in hit])
        samples.append(dict(side=side, center_y_offset_m=offset, rays=651, blocked=len(hits), nearest_hit=max(hits, key=lambda p: abs(p[0])) if hits else None))
assert all(row["blocked"] > 0 for row in samples if row["center_y_offset_m"] == 0)
record = dict(status="CENTERED_LATERAL_SCREEN_OBSTRUCTED", chair_sha256=chair_hash,
              review_space=contact["chair_review_space"], hip_z_m=hip_z, seat_y_m=seat_y,
              sample_spacing_m=.01, x_abs_range_m=[.30,.75], window_width_y_m=.30, window_height_z_m=.20,
              samples=samples, scope="Chair-only sagittal window rays. Forward offsets screen an initial approach only. Full body, pivot, foot placement and room clearance remain untested.")
(packet / "lateral-screen.json").write_text(json.dumps(record, indent=2) + "\n")
print("LATERAL_SCREEN", json.dumps(samples), flush=True)
