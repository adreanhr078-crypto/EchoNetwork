import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, renameSync, unlinkSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

import { readConfiguredPath } from '../environment-setup/tool-resolution';
import { validateGlb } from './validate-glb';

type Profile = 'character' | 'environment';
type TextureMode = 'ktx2' | 'webp' | 'none';

type Arguments = {
  input?: string;
  output?: string;
  profile: Profile;
  textureMode: TextureMode;
  force: boolean;
};

function parseArgs(): Arguments {
  const raw = process.argv.slice(2).filter((value, index) => !(value === '--' && index === 0));
  const args: Arguments = { profile: 'character', textureMode: 'ktx2', force: false };
  for (let index = 0; index < raw.length; index += 1) {
    const value = raw[index];
    if (value === '--force') {
      args.force = true;
      continue;
    }
    if (value === '--input' || value === '--output' || value === '--profile' || value === '--texture-mode') {
      const next = raw[index + 1];
      if (!next || next.startsWith('--')) throw new Error(`${value} requires a value.`);
      if (value === '--input') args.input = next;
      if (value === '--output') args.output = next;
      if (value === '--profile') {
        if (next !== 'character' && next !== 'environment') throw new Error('--profile must be character or environment.');
        args.profile = next;
      }
      if (value === '--texture-mode') {
        if (next !== 'ktx2' && next !== 'webp' && next !== 'none') throw new Error('--texture-mode must be ktx2, webp, or none.');
        args.textureMode = next;
      }
      index += 1;
    }
  }
  return args;
}

async function main(): Promise<void> {
  const args = parseArgs();
  if (!args.input || !args.output) {
    throw new Error('Usage: optimize-glb.ts -- --input <source.glb> --output <optimized.glb> [--profile character|environment] [--texture-mode ktx2|webp|none]');
  }

  const input = resolve(args.input);
  const output = resolve(args.output);
  if (!existsSync(input)) throw new Error(`Input GLB not found: ${input}`);
  if (existsSync(output) && !args.force) throw new Error(`Output already exists; pass --force to replace it: ${output}`);

  // The optimizer must accept structurally valid source assets that exceed the
  // runtime budget; reducing those overages is the purpose of this command.
  // Keep Khronos errors blocking, but enforce the complete strict budget only
  // against the generated runtime asset below.
  const before = await validateGlb(input, false, false);
  if (before.status !== 'PASS') throw new Error('Input GLB failed validation; optimization was not attempted.');

  mkdirSync(dirname(output), { recursive: true });
  const temporary = `${output}.partial-${process.pid}-${Date.now()}.glb`;
  const cli = resolve('node_modules/@gltf-transform/cli/bin/cli.js');
  const textureMode = args.textureMode === 'none' ? 'false' : args.textureMode;
  const profileArgs = args.profile === 'environment'
    ? ['--flatten', 'true', '--join', 'true', '--join-meshes', 'true']
    : ['--flatten', 'false', '--join', 'false'];
  const commandArgs = [
    cli,
    'optimize',
    input,
    temporary,
    '--compress',
    'meshopt',
    '--meshopt-level',
    'high',
    '--texture-compress',
    textureMode,
    '--texture-size',
    '2048',
    '--palette',
    'false',
    '--simplify',
    'false',
    '--instance',
    'true',
    '--prune',
    'true',
    '--resample',
    'true',
    '--weld',
    'true',
    ...profileArgs,
  ];

  const toktx = readConfiguredPath('TOKTX_EXE');
  const env = { ...process.env };
  if (toktx) env.PATH = `${dirname(toktx)};${env.PATH ?? ''}`;

  const result = spawnSync(process.execPath, commandArgs, {
    cwd: resolve('.'),
    encoding: 'utf8',
    env,
    timeout: 10 * 60_000,
    windowsHide: true,
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.status !== 0 || !existsSync(temporary)) {
    if (existsSync(temporary)) unlinkSync(temporary);
    throw new Error(`glTF Transform failed with exit code ${result.status ?? 'unknown'}.`);
  }

  // Runtime acceptance blocks Khronos errors and every configured budget.
  // Known portability warnings are preserved in the report for asset review,
  // but do not discard an otherwise valid optimized asset automatically.
  const after = await validateGlb(temporary, false, true);
  if (after.status !== 'PASS') {
    unlinkSync(temporary);
    throw new Error('Optimized GLB failed validation and was not published.');
  }

  if (existsSync(output)) unlinkSync(output);
  renameSync(temporary, output);
  console.log(JSON.stringify({
    status: 'PASS',
    profile: args.profile,
    textureMode: args.textureMode,
    input,
    output,
    beforeBytes: before.bytes,
    afterBytes: after.bytes,
    extensionsRequired: after.extensionsRequired,
  }, null, 2));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exitCode = 1;
});
