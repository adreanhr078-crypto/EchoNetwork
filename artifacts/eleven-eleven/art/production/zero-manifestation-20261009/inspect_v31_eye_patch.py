"""Measure the adopted V31 iris from actual vertices and original atlas pixels."""
import hashlib
import json
import statistics
from pathlib import Path
from inspect_head_landmarks import read
from inspect_manifestation_sources import APP, CASE, inspect

SOURCE = APP / 'audits/evidence/quality-execution-20261006/current-target/supplied-v31-20261007/source-reference-v9/echo-v31-measured-reference.glb'
positions, uvs, atlas = read(SOURCE)
selected = []
for vertex, (point, uv) in enumerate(zip(positions, uvs)):
    x, y, z = point
    if not (.005 < x < .030 and .881 < y < .906 and z > .045):
        continue
    pixel = atlas.getpixel((min(atlas.width-1, max(0, int(uv[0]*atlas.width))),
                            min(atlas.height-1, max(0, int(uv[1]*atlas.height)))))
    red, green, blue = pixel
    if blue > red * 1.20 + 8 and green > red * 1.10 + 6:
        selected.append({'vertex': vertex, 'position': list(point), 'uv': list(uv), 'rgb': list(pixel)})
assert len(selected) >= 40
report = {'status': 'SOURCE_IRIS_MEASURED_NATIVE_REVIEW_REQUIRED',
          'source': str(SOURCE), 'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          'source_atlas_size': list(atlas.size), 'anatomical_side': 'left, positive source X',
          'samples': selected,
          'median_position': [statistics.median(row['position'][i] for row in selected) for i in range(3)],
          'minimum_position': [min(row['position'][i] for row in selected) for i in range(3)],
          'maximum_position': [max(row['position'][i] for row in selected) for i in range(3)],
          'uv_minimum': [min(row['uv'][i] for row in selected) for i in range(2)],
          'uv_maximum': [max(row['uv'][i] for row in selected) for i in range(2)]}
(CASE / 'v31-v9-iris-landmarks.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({key: report[key] for key in report if key != 'samples'}))
print('Actual iris vertices:', len(selected))
