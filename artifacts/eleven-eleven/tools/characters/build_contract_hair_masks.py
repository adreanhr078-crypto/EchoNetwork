"""Bake instance-local hair masks from authored head topology and atlas.

No model, texture, UV, skin, animation or Golden input is modified. These are
scalar shader masks; they follow existing native skinning without new meshes.
"""
from pathlib import Path
from io import BytesIO
import hashlib
import json
import struct

import numpy as np
from PIL import Image, ImageDraw

APP = Path(__file__).resolve().parents[2]
OUT = APP / 'godot/assets/characters/contract'
EVIDENCE = APP / 'art/production/contract-hair-20261009'
CASES = [
    ('echo_opening_v13', APP / 'godot/assets/characters/echo_opening_uniform_v13.glb', 'tripo::Head_1'),
    ('echo_v31_authored_68', APP / 'audits/evidence/quality-execution-20261006/current-target/supplied-v31-20261007/source-reference-v8/echo-v31-measured-reference.glb', 'Head'),
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bake(profile, path, head_name):
    before = digest(path)
    blob = path.read_bytes()
    assert blob[:4] == b'glTF'
    json_size = struct.unpack_from('<I', blob, 12)[0]
    data = json.loads(blob[20:20 + json_size])
    binary = blob[28 + json_size:]
    dimensions = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
    dtypes = {5121: np.uint8, 5123: '<u2', 5125: '<u4', 5126: '<f4'}

    def accessor(index):
        entry = data['accessors'][index]
        view = data['bufferViews'][entry['bufferView']]
        dtype = np.dtype(dtypes[entry['componentType']])
        size = dimensions[entry['type']]
        offset = view.get('byteOffset', 0) + entry.get('byteOffset', 0)
        stride = view.get('byteStride', dtype.itemsize * size)
        return np.ndarray((entry['count'], size), dtype=dtype, buffer=binary,
                          offset=offset, strides=(stride, dtype.itemsize)).copy()

    model = next(node for node in data['nodes'] if 'mesh' in node and 'skin' in node)
    primitive = data['meshes'][model['mesh']]['primitives'][0]
    attr = primitive['attributes']
    vertices = accessor(attr['POSITION'])
    uv = accessor(attr['TEXCOORD_0'])
    joints = accessor(attr['JOINTS_0'])
    weights = accessor(attr['WEIGHTS_0'])
    names = [data['nodes'][i]['name'] for i in data['skins'][model['skin']]['joints']]
    head_index = names.index(head_name)
    head_weights = (weights * (joints == head_index)).sum(axis=1)
    triangles = accessor(primitive['indices']).reshape(-1, 3)
    # Both measured avatars use the same authored eye height. Warm forehead
    # and eye white are removed by the original atlas, not by guessing a face
    # overlay. Bangs can extend below the upper forehead.
    head_cohort = (head_weights > 0.35) & (vertices[:, 1] > 0.885)
    # Protect the measured eye aperture geometrically as well as by chroma.
    # Hair highlights can be cyan too; cyan alone cannot identify an iris.
    face_forward = vertices[:, 0] > .04 if profile == 'echo_opening_v13' else vertices[:, 2] > .038
    face_lateral = np.abs(vertices[:, 2]) < .05 if profile == 'echo_opening_v13' else np.abs(vertices[:, 0]) < .04
    eye_region = face_forward & face_lateral & (vertices[:, 1] < .912) & (vertices[:, 1] > .875)
    chosen = triangles[np.all(head_cohort[triangles], axis=1)]
    assert len(chosen) > 20, 'No measured head region; fail closed'
    mask = Image.new('L', (1024, 1024), 0)
    drawing = ImageDraw.Draw(mask)
    for triangle in chosen:
        points = [(float(uv[i, 0] * 1023), float(uv[i, 1] * 1023)) for i in triangle]
        drawing.polygon(points, fill=255)
    eye_mask = Image.new('L', (1024, 1024), 0)
    eye_drawing = ImageDraw.Draw(eye_mask)
    for triangle in triangles[np.any(eye_region[triangles], axis=1)]:
        eye_drawing.polygon([(float(uv[i, 0] * 1023), float(uv[i, 1] * 1023)) for i in triangle], fill=255)
    material = data['materials'][primitive.get('material', 0)]
    texture_index = material['pbrMetallicRoughness']['baseColorTexture']['index']
    image_index = data['textures'][texture_index]['source']
    view = data['bufferViews'][data['images'][image_index]['bufferView']]
    offset = view.get('byteOffset', 0)
    atlas = Image.open(BytesIO(binary[offset:offset + view['byteLength']])).convert('RGB')
    atlas.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
    atlas = atlas.resize((1024, 1024), Image.Resampling.LANCZOS)
    rgb = np.asarray(atlas, dtype=np.float32) / 255.0
    skin = (rgb[:, :, 0] > .25) & (rgb[:, :, 0] - rgb[:, :, 2] > .025) & (rgb[:, :, 0] - rgb[:, :, 1] > .008)
    neutral_light = rgb.max(axis=2) > .65
    mask_array = np.asarray(mask).copy()
    mask_array[skin | neutral_light | (np.asarray(eye_mask) > 0)] = 0
    selected = mask_array > 0
    assert 50 < selected.sum() < 150000, 'Unexpected hair footprint; fail closed'
    assert not np.any(selected & skin), 'Skin contamination'
    output = OUT / f'{profile}_hair_mask.png'
    Image.fromarray(mask_array).save(output)
    # Inspection is required even though the geometry and chroma guards pass.
    preview = np.asarray(atlas).copy()
    preview[selected] = (.4 * preview[selected] + .6 * np.array([170, 55, 225])).astype(np.uint8)
    Image.fromarray(preview).save(EVIDENCE / f'{profile}_atlas_review.png')
    assert digest(path) == before
    return {'profile': profile, 'source': str(path.relative_to(APP)),
            'source_sha256': before, 'head_bone': head_name,
            'head_triangles': len(chosen), 'mask_texels': int(selected.sum()),
            'warm_skin_texels_changed': 0, 'eye_aperture_texels_changed': 0,
            'mask': str(output.relative_to(APP)),
            'mask_sha256': digest(output), 'source_modified': False,
            'native_hair_only_visual_acceptance': 'OPEN'}


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    reports = [bake(*case) for case in CASES]
    (EVIDENCE / 'hair-mask-manifest.json').write_text(json.dumps(reports, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(reports, indent=2))
