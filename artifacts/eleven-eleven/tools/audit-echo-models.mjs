import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import sharp from 'sharp';

// Read-only GLB inventory. Texture resolution and clip presence do not approve
// likeness, animation deformation, or target-device performance.
const files = [
  'godot/assets/characters/echo_opening_uniform_v13.glb',
  'godot/assets/characters/echo_tripo_native.glb',
  'godot/assets/characters/echo_candidate_v3.glb',
];
const results = [];
for (const file of files) {
  const bytes = readFileSync(resolve(file));
  if (bytes.readUInt32LE(0) !== 0x46546c67) throw new Error(`Not GLB: ${file}`);
  const jsonLength = bytes.readUInt32LE(12);
  const gltf = JSON.parse(bytes.subarray(20, 20 + jsonLength).toString('utf8'));
  const binaryStart = 20 + jsonLength + 8;
  const images = [];
  for (const image of gltf.images ?? []) {
    if (image.bufferView === undefined) { images.push({ uri: image.uri }); continue; }
    const view = gltf.bufferViews[image.bufferView];
    const data = bytes.subarray(binaryStart + (view.byteOffset ?? 0), binaryStart + (view.byteOffset ?? 0) + view.byteLength);
    const info = await sharp(data).metadata();
    images.push({ name: image.name, format: info.format, width: info.width, height: info.height, encodedBytes: data.length });
  }
  const triangles = (gltf.meshes ?? []).reduce((sum, mesh) => sum + mesh.primitives.reduce((total, p) => {
    if ((p.mode ?? 4) !== 4) return total;
    return total + gltf.accessors[p.indices ?? p.attributes.POSITION].count / 3;
  }, 0), 0);
  results.push({ file, bytes: bytes.length, triangles, meshes: gltf.meshes?.map(m => m.name),
    joints: gltf.skins?.map(s => s.joints.length), clips: gltf.animations?.map(a => a.name), images });
}
const report = { inspectedAt: new Date().toISOString(), status: 'STRUCTURE_ONLY_VISUAL_REVIEW_REQUIRED', models: results };
writeFileSync('docs/internal/production/ECHO_MODEL_INVENTORY_2026-09-28.json', JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
