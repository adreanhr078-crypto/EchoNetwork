import { NodeIO } from '@gltf-transform/core';
import sharp from 'sharp';

const args = process.argv.slice(2);
const inputIndex = args.indexOf('--input');
const outputIndex = args.indexOf('--output');
const input = inputIndex >= 0 ? args[inputIndex + 1] : undefined;
const output = outputIndex >= 0 ? args[outputIndex + 1] : undefined;
const expandSparse = !args.includes('--keep-sparse');

if (!input || !output) {
  throw new Error('Usage: npx tsx tools/media/make-godot-glb.ts --input source.glb --output target.glb');
}

async function main(): Promise<void> {
  const io = new NodeIO();
  const document = await io.read(input);
  let converted = 0;

  for (const texture of document.getRoot().listTextures()) {
    const image = texture.getImage();
    if (!image) continue;
    const mimeType = texture.getMimeType();
    if (mimeType === 'image/png' || mimeType === 'image/jpeg') {
      const jpeg = await sharp(image)
        .resize({ width: 256, height: 256, fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: 72, chromaSubsampling: '4:4:4' })
        .toBuffer();
      texture.setImage(jpeg).setMimeType('image/jpeg');
      converted += 1;
    }
  }

  // Godot's importer is stricter than glTF Transform about sparse accessors.
  // Expand them to dense buffers while preserving decoded values.
  let expandedSparse = 0;
  if (expandSparse) {
    for (const accessor of document.getRoot().listAccessors()) {
      if (accessor.getSparse()) {
        accessor.setSparse(false);
        expandedSparse += 1;
      }
    }
  }

  await io.write(output, document);
  console.log(`GODOT_GLB_READY textures_converted=${converted} sparse_expanded=${expandedSparse} textures=${document.getRoot().listTextures().length}`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
