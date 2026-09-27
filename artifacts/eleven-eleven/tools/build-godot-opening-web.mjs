import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { copyFileSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const appRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const godotPath = join(appRoot, 'godot');
const staging = join(appRoot, '.tmp', 'godot-web-staging');
const publicBuild = join(appRoot, 'public', 'godot', 'opening');
const godotBin = process.env.GODOT_BIN || 'godot';
const names = [
  'index.html', 'index.js', 'index.pck', 'index.wasm', 'index.png',
  'index.audio.worklet.js', 'index.audio.position.worklet.js',
];

mkdirSync(staging, { recursive: true });
mkdirSync(publicBuild, { recursive: true });
const exportLog = execFileSync(godotBin, [
  '--headless', '--path', godotPath, '--export-release', 'Web', join(staging, 'index.html'),
], { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
if (!exportLog.includes('[ DONE ]') || /ERROR:/.test(exportLog)) {
  throw new Error(`Godot Web export was not clean:\n${exportLog.slice(-4000)}`);
}

for (const name of names) copyFileSync(join(staging, name), join(publicBuild, name));
const pckBytes = statSync(join(publicBuild, 'index.pck')).size;
const wasmBytes = statSync(join(publicBuild, 'index.wasm')).size;
if (pckBytes > 140 * 1024 * 1024) {
  throw new Error(`Opening package exceeds the provisional 140 MiB guard (${pckBytes} bytes).`);
}
const manifest = {
  bridgeVersion: 1,
  sceneContract: 'opening-room-v1',
  // Export success is not a browser playtest. Keep the existing Web room active.
  playable: false,
  pckBytes,
  wasmBytes,
  pckSha256: createHash('sha256').update(readFileSync(join(publicBuild, 'index.pck'))).digest('hex'),
};
writeFileSync(join(publicBuild, 'manifest.json'), JSON.stringify(manifest, null, 2));
process.stdout.write(`Godot opening Web build: ${(pckBytes / 1048576).toFixed(1)} MiB PCK, ${(wasmBytes / 1048576).toFixed(1)} MiB WASM\n`);
