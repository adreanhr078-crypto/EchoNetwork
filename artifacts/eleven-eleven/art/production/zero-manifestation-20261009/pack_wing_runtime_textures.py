"""Encode the authored 2K wing maps without touching mesh, rig or UV data.

Blender packs scaled JPEG images as PNG. This explicit export stage retains the
editable packed pixels and keeps the normal map lossless, then applies the same
JPEG codec as the immutable Tripo source to colour and ORM. All non-image
buffer views are compared byte-for-byte before the runtime file is replaced.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import io
import json
import math
from pathlib import Path
import struct
from PIL import Image, ImageChops, ImageStat

CASE = Path(__file__).resolve().parent
APP = CASE.parents[2]
RUNTIME = APP / 'godot/assets/characters/echo_shadow_wing_feathers_v1.glb'
PRESERVED = CASE / 'wing-feathers-v2-2k-lossless.glb'
LIMIT = 6 * 1024 * 1024


def digest(blob: bytes) -> str:
    return hashlib.sha256(blob).hexdigest()


def read_glb(path: Path) -> tuple[dict, bytes]:
    blob = path.read_bytes()
    magic, version, total = struct.unpack_from('<4sII', blob)
    assert magic == b'glTF' and version == 2 and total == len(blob)
    json_length, json_type = struct.unpack_from('<II', blob, 12)
    assert json_type == 0x4E4F534A
    data = json.loads(blob[20:20 + json_length])
    offset = 20 + json_length
    bin_length, bin_type = struct.unpack_from('<II', blob, offset)
    assert bin_type == 0x004E4942 and offset + 8 + bin_length == len(blob)
    assert len(data['buffers']) == 1 and not data.get('extensionsUsed')
    return data, blob[offset + 8:]


def view_bytes(data: dict, binary: bytes, index: int) -> bytes:
    view = data['bufferViews'][index]
    assert view.get('buffer', 0) == 0
    offset = view.get('byteOffset', 0)
    return binary[offset:offset + view['byteLength']]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, default=PRESERVED)
    parser.add_argument('--quality', type=int, default=95)
    args = parser.parse_args()
    assert 90 <= args.quality <= 100
    # The first run saves the exact held export. Subsequent runs use that source,
    # never a previously compressed JPEG: no cumulative recompression.
    if not args.input.exists():
        assert args.input == PRESERVED
        args.input.write_bytes(RUNTIME.read_bytes())
    source, original_bin = read_glb(args.input)
    assert all(image['mimeType'] == 'image/png' for image in source['images'])
    result = copy.deepcopy(source)
    replacements: dict[int, bytes] = {}
    texture_records = []
    for index, image in enumerate(source['images']):
        view = image['bufferView']
        encoded = view_bytes(source, original_bin, view)
        pixels = Image.open(io.BytesIO(encoded))
        pixels.load()
        assert pixels.size == (2048, 2048)
        record = {'name': image['name'], 'size': list(pixels.size),
                  'source_bytes': len(encoded), 'source_sha256': digest(encoded)}
        if image['name'].startswith(('Color_', 'ORM_')):
            # Full 4:4:4 sampling keeps violet fracture edges and per-channel ORM
            # detail; chroma subsampling would smudge neighbouring material data.
            assert pixels.mode == 'RGB', 'Unexpected alpha: preserve it instead.'
            stream = io.BytesIO()
            pixels.save(stream, 'JPEG', quality=args.quality, subsampling=0,
                        optimize=True, progressive=False)
            converted = stream.getvalue()
            decoded = Image.open(io.BytesIO(converted)).convert('RGB')
            difference = ImageChops.difference(pixels, decoded)
            stats = ImageStat.Stat(difference)
            mean_square_error = sum(value * value for value in stats.rms) / 3.0
            record.update({'codec': 'JPEG', 'quality': args.quality,
                           'chroma_subsampling': '4:4:4',
                           'mean_absolute_error_255': stats.mean,
                           'max_absolute_error_255': [high for low, high in difference.getextrema()],
                           'psnr_db': 10 * math.log10(255 * 255 / mean_square_error)})
            # A numerical guard supports, but does not replace, native review.
            assert max(stats.mean) < 2.0 and record['psnr_db'] > 38
            result['images'][index]['mimeType'] = 'image/jpeg'
        else:
            assert image['name'].startswith('NormalGL_')
            converted = encoded
            record.update({'codec': 'PNG', 'byte_identical': True})
        replacements[view] = converted
        record.update({'runtime_bytes': len(converted), 'runtime_sha256': digest(converted)})
        texture_records.append(record)

    packed = bytearray()
    geometry_records = []
    for index, view in enumerate(result['bufferViews']):
        while len(packed) % 4:
            packed.append(0)
        original = view_bytes(source, original_bin, index)
        replacement = replacements.get(index, original)
        view['byteOffset'] = len(packed)
        view['byteLength'] = len(replacement)
        packed.extend(replacement)
        if index not in replacements:
            assert original == replacement
            geometry_records.append({'buffer_view': index, 'bytes': len(original),
                                     'sha256': digest(original), 'byte_identical': True})
    result['buffers'][0]['byteLength'] = len(packed)
    while len(packed) % 4:
        packed.append(0)
    metadata = json.dumps(result, separators=(',', ':'), ensure_ascii=False).encode()
    metadata += b' ' * (-len(metadata) % 4)
    total = 12 + 8 + len(metadata) + 8 + len(packed)
    assert total <= LIMIT, f'Runtime budget exceeded: {total} > {LIMIT}'
    output = (struct.pack('<4sII', b'glTF', 2, total) +
              struct.pack('<II', len(metadata), 0x4E4F534A) + metadata +
              struct.pack('<II', len(packed), 0x004E4942) + bytes(packed))
    temporary = RUNTIME.with_suffix('.glb.texture-pack.tmp')
    temporary.write_bytes(output)
    verified, verified_bin = read_glb(temporary)
    for record in geometry_records:
        assert digest(view_bytes(verified, verified_bin, record['buffer_view'])) == record['sha256']
    for key in ['accessors', 'meshes', 'nodes', 'skins', 'materials', 'textures', 'samplers', 'scenes']:
        assert verified[key] == source[key], key
    temporary.replace(RUNTIME)
    report = {'status': 'TEXTURE_CODEC_PASS_NATIVE_REVIEW_REQUIRED',
              'source': str(args.input), 'source_sha256': digest(args.input.read_bytes()),
              'output': str(RUNTIME), 'output_sha256': digest(output),
              'source_bytes': args.input.stat().st_size, 'runtime_bytes': len(output),
              'runtime_budget_bytes': LIMIT, 'image_records': texture_records,
              'geometry_views': geometry_records,
              'geometry_uv_skin_tangents_byte_identical': True}
    (CASE / 'wing-texture-pack-v3.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({key: report[key] for key in ['status', 'source_bytes', 'runtime_bytes', 'output_sha256']}))


if __name__ == '__main__':
    main()
