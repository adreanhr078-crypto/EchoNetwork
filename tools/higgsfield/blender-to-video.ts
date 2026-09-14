/**
 * tools/higgsfield/blender-to-video.ts
 *
 * End-to-end pipeline:
 *   1. Invoke Blender headlessly to render a PNG poster frame from a .blend scene
 *   2. Optionally export a GLB to verify geometry before generation
 *   3. Submit the poster frame to Higgsfield AI as image-to-video reference
 *   4. Poll until completed
 *   5. Download the resulting video to public/assets/cinematics/
 *
 * Run from repo root:
 *   npx tsx tools/higgsfield/blender-to-video.ts \
 *     --blend path/to/scene.blend \
 *     --prompt "cinematic obsidian chess entrance, signal crimson lighting" \
 *     --output public/assets/cinematics/chess-entrance.mp4
 *
 * Optional flags:
 *   --frame <number>           Which Blender frame to render as reference (default: 1)
 *   --duration <seconds>       Video duration (default: 4)
 *   --fps <number>             Frames per second (default: 24)
 *   --camera-motion <type>     zoom_in|zoom_out|pan_left|pan_right|orbit|static
 *   --motion-strength <0-1>    Motion intensity (default: 0.7)
 *   --no-cleanup               Keep the temporary PNG poster frame after generation
 *   --no-wait                  Submit to Higgsfield without polling for completion
 */

import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, resolve, basename, join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

import { HiggsfieldClient, type GenerationStatus } from './higgsfield-client.js';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

// ─── Helpers ──────────────────────────────────────────────────────────────────

function readConfiguredPath(envKey: string): string | undefined {
  return process.env[envKey]?.trim() || undefined;
}

function detectBlender(): string {
  const configured = readConfiguredPath('BLENDER_EXE');
  if (configured) {
    if (!existsSync(configured)) throw new Error(`BLENDER_EXE does not exist: ${configured}`);
    return configured;
  }
  return process.platform === 'win32' ? 'blender.exe' : 'blender';
}

function spawnCommand(
  exe: string,
  args: string[],
): Promise<{ code: number | null; stdout: string; stderr: string }> {
  return new Promise((settle) => {
    const child = spawn(exe, args, { stdio: ['pipe', 'pipe', 'pipe'], shell: false });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (d: Buffer) => { stdout += d.toString(); });
    child.stderr.on('data', (d: Buffer) => { stderr += d.toString(); });
    child.on('error', (error: Error) => settle({ code: 1, stdout, stderr: `${stderr}${error.message}` }));
    child.on('close', (code) => settle({ code, stdout, stderr }));
  });
}

type ParsedFlags = Record<string, string>;

function parseFlags(args: string[]): ParsedFlags {
  const flags: ParsedFlags = {};
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = args[i + 1];
      flags[key] = next && !next.startsWith('--') ? next : 'true';
      if (next && !next.startsWith('--')) i++;
    }
  }
  return flags;
}

function requireFlag(flags: ParsedFlags, key: string): string {
  const value = flags[key];
  if (!value || value === 'true') {
    console.error(`--${key} is required.`);
    process.exit(1);
  }
  return value;
}

// ─── Blender render step ──────────────────────────────────────────────────────

/**
 * Render a single frame from a Blender scene as a PNG.
 * Uses Blender's built-in rendering pipeline (Cycles or EEVEE per the .blend settings).
 */
async function renderBlenderFrame(
  blendFile: string,
  outputPng: string,
  frame: number,
): Promise<void> {
  const blender = detectBlender();

  // Inline Python script to override the output path and frame, then render
  const script = `
import bpy, sys, os

args = sys.argv[sys.argv.index('--') + 1:]
output_path = args[0]
frame_num = int(args[1])

scene = bpy.context.scene
scene.frame_set(frame_num)
scene.render.filepath = output_path
# Force PNG so Higgsfield gets a lossless reference
scene.render.image_settings.file_format = 'PNG'
# Disable animation — single frame only
bpy.ops.render.render(write_still=True)
`.trim();

  // Write script to temp file
  const scriptPath = join(tmpdir(), `hf_render_${Date.now()}.py`);
  const { writeFileSync } = await import('node:fs');
  writeFileSync(scriptPath, script, 'utf8');

  mkdirSync(dirname(outputPng), { recursive: true });

  console.log(`[blender] Rendering frame ${frame} from ${basename(blendFile)}…`);

  const result = await spawnCommand(blender, [
    blendFile,
    '--background',
    '--python-exit-code', '1',
    '--python', scriptPath,
    '--',
    // Strip extension — Blender appends frame number + extension automatically
    outputPng.replace(/\.png$/i, ''),
    String(frame),
  ]);

  // Cleanup temp script
  rmSync(scriptPath, { force: true });

  if (result.code !== 0) {
    if (result.stderr) console.error(result.stderr);
    throw new Error(`Blender render failed (exit ${result.code}).`);
  }

  // Blender appends frame number: e.g. output0001.png
  // Resolve the actual output path
  const paddedFrame = String(frame).padStart(4, '0');
  const blenderOutput = outputPng.replace(/\.png$/i, '') + paddedFrame + '.png';

  if (!existsSync(blenderOutput) && !existsSync(outputPng)) {
    throw new Error(`Expected Blender output not found at ${blenderOutput} or ${outputPng}`);
  }

  // Rename to the exact expected path if needed
  if (existsSync(blenderOutput) && blenderOutput !== outputPng) {
    const { renameSync } = await import('node:fs');
    renameSync(blenderOutput, outputPng);
  }

  console.log(`[blender] Frame rendered → ${outputPng}`);
}

// ─── Main pipeline ─────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  const raw = process.argv.slice(2);
  if (raw.length === 0 || raw[0] !== '--') {
    console.error(
      'Usage: blender-to-video.ts -- --blend <file.blend> --prompt "<text>" --output <out.mp4>',
    );
    process.exit(1);
  }

  const flags = parseFlags(raw.slice(1));
  const blendPath = resolve(REPO_ROOT, requireFlag(flags, 'blend'));
  const prompt = requireFlag(flags, 'prompt');
  const outputPath = resolve(REPO_ROOT, requireFlag(flags, 'output'));
  const frame = flags['frame'] ? Number(flags['frame']) : 1;
  const cleanup = flags['no-cleanup'] !== 'true';
  const wait = flags['no-wait'] !== 'true';

  if (!existsSync(blendPath)) {
    console.error(`Blend file not found: ${blendPath}`);
    process.exit(1);
  }

  // ── Step 1: Render Blender poster frame ──────────────────────────────────────
  const tempDir = join(tmpdir(), `higgsfield-pipeline-${Date.now()}`);
  const posterPng = join(tempDir, 'poster.png');

  await renderBlenderFrame(blendPath, posterPng, frame);

  // ── Step 2: Submit to Higgsfield AI ──────────────────────────────────────────
  const client = new HiggsfieldClient();

  console.log(`\n[higgsfield] Submitting image-to-video generation…`);
  console.log(`  Prompt: ${prompt}`);
  console.log(`  Reference: ${posterPng}`);

  // Read the poster PNG as base64 data URI
  const { readFileSync } = await import('node:fs');
  const b64 = readFileSync(posterPng).toString('base64');
  const imageUrl = `data:image/png;base64,${b64}`;

  const response = await client.generateVideo({
    prompt,
    image_url: imageUrl,
    duration: flags['duration'] ? Number(flags['duration']) : 4,
    fps: flags['fps'] ? Number(flags['fps']) : 24,
    resolution: flags['resolution'] ?? '1280x720',
    motion_strength: flags['motion-strength'] ? Number(flags['motion-strength']) : 0.7,
    camera_motion: flags['camera-motion'],
  });

  console.log(`[higgsfield] Request queued: ${response.request_id}`);
  console.log(`  Status URL: ${response.status_url}`);
  console.log(`  Cancel URL: ${response.cancel_url}`);

  // Cleanup temp poster if requested
  if (cleanup) {
    rmSync(tempDir, { recursive: true, force: true });
  }

  if (!wait) {
    console.log('\n[pipeline] --no-wait set. Monitor with:');
    console.log(
      `  npx tsx tools/higgsfield/run-higgsfield.ts -- status --request-id ${response.request_id}`,
    );
    console.log('  Then download with:');
    console.log(
      `  npx tsx tools/higgsfield/run-higgsfield.ts -- generate-video --request-id ${response.request_id} --output ${flags['output']}`,
    );
    return;
  }

  // ── Step 3: Poll for completion ───────────────────────────────────────────────
  console.log('\n[higgsfield] Waiting for video generation (may take 2–5 minutes)…');
  const result = await client.waitForCompletion(response.request_id, {
    timeoutMs: 15 * 60 * 1_000,
    onPoll: (status: GenerationStatus) => {
      process.stdout.write(`\r  Status: ${status}                  `);
    },
  });
  process.stdout.write('\n');

  // ── Step 4: Download to output path ──────────────────────────────────────────
  mkdirSync(dirname(outputPath), { recursive: true });
  console.log(`\n[higgsfield] Downloading video → ${outputPath}`);
  await client.downloadOutput(result, outputPath);

  console.log('\n✅ Pipeline complete!');
  console.log(`   Blender scene: ${blendPath}`);
  console.log(`   Video output:  ${outputPath}`);
  console.log(`   Request ID:    ${response.request_id}`);
}

main().catch((err: unknown) => {
  console.error(`\n[blender-to-video] Fatal error: ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
});
