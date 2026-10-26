"""Read original GLB joint samples without interpolation, resampling or writes.

The diagnostic accepts dense native clocks and exact STEP evaluation whose
authored key times are a subset of that clock. Other clocks, unsupported accessors or
mixed animated matrix nodes fail rather than inventing missing poses.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import numpy as np
from PIL import Image, ImageDraw

p = argparse.ArgumentParser()
p.add_argument('--source', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--animation-name')
p.add_argument('--endpoints-only', action='store_true')
a = p.parse_args()
source = a.source.resolve()
out = a.output.resolve()
if out == source.parent or '/golden/' in out.as_posix().lower():
    raise ValueError('Use a separate unprotected evidence folder')
out.mkdir(parents=True, exist_ok=True)
raw = source.read_bytes()
digest = hashlib.sha256(raw).hexdigest()
assert raw[:4] == b'glTF' and struct.unpack_from('<I', raw, 4)[0] == 2
offset = 12
binary = None
while offset < len(raw):
    length, kind = struct.unpack_from('<II', raw, offset)
    payload = raw[offset+8:offset+8+length]
    if kind == 0x4e4f534a:
        doc = json.loads(payload)
    elif kind == 0x004e4942:
        binary = payload
    offset += 8+length
assert binary is not None
animations = doc.get('animations', [])
if a.animation_name:
    animations = [item for item in animations if item.get('name') == a.animation_name]
assert len(animations) == 1, 'Select exactly one authored animation'

def accessor(index):
    item = doc['accessors'][index]
    assert item['componentType'] == 5126 and not item.get('sparse')
    width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[item['type']]
    view = doc['bufferViews'][item['bufferView']]
    assert view.get('buffer', 0) == 0
    begin = view.get('byteOffset', 0)+item.get('byteOffset', 0)
    stride = view.get('byteStride', width*4)
    return np.ndarray((item['count'], width), dtype='<f4', buffer=binary,
                      offset=begin, strides=(stride, 4)).copy()

animation = animations[0]
tracks = {}
native_clock = max((accessor(animation['samplers'][c['sampler']]['input'])[:, 0] for c in animation['channels']), key=len)
times = native_clock[[0, -1]] if a.endpoints_only else native_clock
step_tracks = []
for channel in animation['channels']:
    sampler = animation['samplers'][channel['sampler']]
    assert sampler.get('interpolation', 'LINEAR') in ['LINEAR', 'STEP']
    clock = accessor(sampler['input'])[:, 0]
    target = channel['target']
    assert 'matrix' not in doc['nodes'][target['node']]
    values = accessor(sampler['output'])
    if a.endpoints_only:
        assert clock[0] == times[0] and clock[-1] == times[-1], 'Endpoints differ; use native evaluator'
        values = values[[0, -1]]
    elif not np.array_equal(clock, times):
        # The source has172 two-key STEP tracks. Endpoint differences reach
        # 4.18e-7; retain even those differences using exact GLTF STEP semantics.
        # No interpolation or change to a native source key is involved.
        assert sampler.get('interpolation') == 'STEP' and len(clock) == 2
        assert clock[0] == times[0] and clock[-1] == times[-1]
        assert all(value in times for value in clock)
        step_tracks.append({'node': target['node'], 'path': target['path'], 'original_keys': 2,
                            'max_endpoint_difference': float(np.max(np.abs(values[0]-values[-1])))})
        values = values[np.searchsorted(clock, times, side='right')-1]
    assert len(values) == len(times)
    tracks[(target['node'], target['path'])] = values
assert np.isfinite(times).all() and np.all(np.diff(times) > 0)
rate = 1/float(np.median(np.diff(native_clock)))
assert abs(rate-round(rate)) < .001
assert np.max(np.abs(np.diff(native_clock)-1/round(rate))) < .000001
parents = {child: i for i, node in enumerate(doc['nodes']) for child in node.get('children', [])}
joints = doc['skins'][0]['joints']
names = {i: doc['nodes'][i].get('name', str(i)) for i in joints}

def local(index, frame):
    node = doc['nodes'][index]
    if 'matrix' in node:
        return np.array(node['matrix'], dtype=float).reshape(4, 4).T
    get = lambda field, default: tracks[(index, field)][frame] if (index, field) in tracks else node.get(field, default)
    x, y, z, w = get('rotation', [0, 0, 0, 1])
    assert abs(x*x+y*y+z*z+w*w-1) < .001
    m = np.eye(4)
    m[:3, :3] = [[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                 [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                 [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]]
    m[:3, :3] = m[:3, :3] @ np.diag(get('scale', [1, 1, 1]))
    m[:3, 3] = get('translation', [0, 0, 0])
    return m

samples = []
for frame, time in enumerate(times):
    cache = {}
    def world(index):
        if index not in cache:
            cache[index] = (world(parents[index]) if index in parents else np.eye(4)) @ local(index, frame)
        return cache[index]
    points = {names[i]: world(i)[:3, 3].tolist() for i in joints}
    assert all(np.isfinite(v).all() for v in points.values())
    samples.append({'time': float(time), 'points': points})
report = {'status': 'EXACT_NATIVE_SAMPLES__VISUAL_REVIEW_PENDING', 'source': str(source),
          'source_sha256': digest, 'action': animation.get('name'), 'fps': round(rate),
          'sample_count': len(times), 'first_time': float(times[0]), 'last_time': float(times[-1]),
          'duration': float(times[-1]-times[0]), 'basis': 'Original glTF metres, Y up',
          'keys_changed': False, 'interpolation_or_resampling': False, 'frames': samples}
report['scope'] = 'Authored first/last endpoints only' if a.endpoints_only else 'All original dense native clock samples'
report['native_clock_sample_count'] = len(native_clock)
report['exact_native_STEP_tracks'] = step_tracks
(out/'exact-native-source.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')

points = np.array([list(s['points'].values()) for s in samples])
low, high = points.min(axis=(0, 1)), points.max(axis=(0, 1))
indices = sorted(set([0, min(8, len(times)-1), *[round((len(times)-1)*v) for v in [.2, .4, .6, .8, 1]]]))
sheet = Image.new('RGB', (len(indices)*220, 650), '#1b2430')
for row, axis in enumerate([0, 2]):
    for column, frame in enumerate(indices):
        canvas = Image.new('RGB', (220, 325), '#202b38')
        draw = ImageDraw.Draw(canvas)
        scale = min(195/max(high[axis]-low[axis], .1), 270/max(high[1]-low[1], .1))
        center = (low+high)/2
        def project(point):
            return (110+(point[axis]-center[axis])*scale, 170-(point[1]-center[1])*scale)
        for joint in joints:
            parent = parents.get(joint)
            if parent in joints:
                draw.line([project(samples[frame]['points'][names[parent]]), project(samples[frame]['points'][names[joint]])], fill='#72d6ee', width=2)
        draw.text((7, 6), f'{"front" if row == 0 else "side"} native {frame+1}/{len(times)}', fill='white')
        draw.text((7, 22), f't={float(times[frame]):.4f}s | original world', fill='white')
        canvas.save(out/f'{frame:04d}-{"front" if row == 0 else "side"}.png')
        sheet.paste(canvas, (column*220, row*325))
sheet.save(out/'native-contact.jpg')
assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
print(json.dumps({k: report[k] for k in ['source_sha256', 'fps', 'sample_count', 'first_time', 'last_time', 'duration']}))
