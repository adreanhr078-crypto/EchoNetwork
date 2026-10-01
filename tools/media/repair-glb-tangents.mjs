import fs from 'node:fs';

const input = process.argv[2];
const output = process.argv[3] ?? input;
if (!input) throw new Error('Usage: node repair-glb-tangents.mjs <input.glb> [output.glb]');

const bytes = fs.readFileSync(input);
if (bytes.readUInt32LE(0) !== 0x46546c67) throw new Error('Not a binary glTF file');

let offset = 12;
let jsonChunk;
let binChunk;
let binDataOffset = -1;
while (offset < bytes.length) {
  const length = bytes.readUInt32LE(offset);
  const type = bytes.readUInt32LE(offset + 4);
  const dataOffset = offset + 8;
  if (type === 0x4e4f534a) jsonChunk = bytes.subarray(dataOffset, dataOffset + length);
  if (type === 0x004e4942) {
    binChunk = bytes.subarray(dataOffset, dataOffset + length);
    binDataOffset = dataOffset;
  }
  offset = dataOffset + length;
}
if (!jsonChunk || !binChunk || binDataOffset < 0) throw new Error('GLB is missing JSON or BIN data');

const gltf = JSON.parse(jsonChunk.toString('utf8').replace(/\u0000+$/g, '').trimEnd());
const tangentAccessors = new Set();
for (const mesh of gltf.meshes ?? []) {
  for (const primitive of mesh.primitives ?? []) {
    if (primitive.attributes?.TANGENT !== undefined) tangentAccessors.add(primitive.attributes.TANGENT);
  }
}

let repaired = 0;
for (const accessorIndex of tangentAccessors) {
  const accessor = gltf.accessors[accessorIndex];
  if (accessor.componentType !== 5126 || accessor.type !== 'VEC4' || accessor.sparse) continue;
  const view = gltf.bufferViews[accessor.bufferView];
  const stride = view.byteStride ?? 16;
  const base = binDataOffset + (view.byteOffset ?? 0) + (accessor.byteOffset ?? 0);
  for (let i = 0; i < accessor.count; i += 1) {
    const p = base + i * stride;
    const x = bytes.readFloatLE(p);
    const y = bytes.readFloatLE(p + 4);
    const z = bytes.readFloatLE(p + 8);
    if (!Number.isFinite(x + y + z) || x * x + y * y + z * z < 1e-12) {
      bytes.writeFloatLE(1, p);
      bytes.writeFloatLE(0, p + 4);
      bytes.writeFloatLE(0, p + 8);
      const w = bytes.readFloatLE(p + 12);
      if (!Number.isFinite(w) || Math.abs(w) < 0.5) bytes.writeFloatLE(1, p + 12);
      repaired += 1;
    }
  }
}

fs.writeFileSync(output, bytes);
console.log(JSON.stringify({ input, output, tangentAccessors: tangentAccessors.size, repaired }));
