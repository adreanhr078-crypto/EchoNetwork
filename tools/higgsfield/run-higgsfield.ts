/**
 * tools/higgsfield/run-higgsfield.ts
 *
 * CLI wrapper for the Higgsfield AI API — mirrors the pattern of run-blender.ts.
 *
 * Run from repo root:
 *   HF_API_KEY_ID=xxx HF_API_KEY_SECRET=yyy npx tsx tools/higgsfield/run-higgsfield.ts -- doctor
 *   npx tsx tools/higgsfield/run-higgsfield.ts -- generate-image --prompt "obsidian chess board" --output ./out.jpg
 *   npx tsx tools/higgsfield/run-higgsfield.ts -- generate-video --prompt "cinematic scene" --output ./out.mp4
 *   npx tsx tools/higgsfield/run-higgsfield.ts -- generate-video --prompt "animate this" --image-url https://... --output ./out.mp4
 *   npx tsx tools/higgsfield/run-higgsfield.ts -- status --request-id <id>
 *   npx tsx tools/higgsfield/run-higgsfield.ts -- cancel --request-id <id>
 */

import { resolve } from 'node:path';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  HiggsfieldClient,
  extractOutputUrls,
  type GenerationStatus,
} from './higgsfield-client.js';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

// ─── CLI parsing ──────────────────────────────────────────────────────────────

type Flags = Record<string, string>;

function parseFlags(args: string[]): Flags {
  const flags: Flags = {};
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

function requireFlag(flags: Flags, key: string): string {
  const value = flags[key];
  if (!value || value === 'true') {
    console.error(`--${key} is required.`);
    process.exit(1);
  }
  return value;
}

function usage(): void {
  console.error(`Usage: run-higgsfield.ts -- <subcommand> [options]

Subcommands:
  doctor                               Verify API credentials are set
  generate-image                       Submit an image generation request
    --prompt <text>                    Generation prompt (required)
    --negative-prompt <text>           Negative prompt (optional)
    --aspect-ratio <ratio>             e.g. "16:9", "1:1" (default: "16:9")
    --output <path>                    Local path to save the result
    --no-wait                          Return immediately without polling
  generate-video                       Submit a video generation request
    --prompt <text>                    Generation prompt (required)
    --image-url <url>                  Reference image for image-to-video (optional)
    --image-file <path>                Local Blender render to use as reference image
    --duration <seconds>               Video duration (default: 4)
    --fps <number>                     Frames per second (default: 24)
    --resolution <WxH>                 e.g. "1280x720" (default: "1280x720")
    --motion-strength <0-1>            Motion intensity (default: 0.7)
    --camera-motion <type>             zoom_in|zoom_out|pan_left|pan_right|orbit|static
    --output <path>                    Local path to save the video
    --no-wait                          Return immediately without polling
  status                               Check status of an existing request
    --request-id <id>                  Request ID returned from generate
  cancel                               Cancel a queued request
    --request-id <id>                  Request ID to cancel
`);
}

// ─── Subcommand handlers ──────────────────────────────────────────────────────

async function runDoctor(): Promise<void> {
  const keyId = process.env['HF_API_KEY_ID'];
  const keySecret = process.env['HF_API_KEY_SECRET'];

  console.log('\n=== Higgsfield API Doctor ===\n');

  if (!keyId) {
    console.log('[FAIL] HF_API_KEY_ID — not set');
  } else {
    console.log(`[PASS] HF_API_KEY_ID — ${keyId.slice(0, 6)}...`);
  }

  if (!keySecret) {
    console.log('[FAIL] HF_API_KEY_SECRET — not set');
  } else {
    console.log(`[PASS] HF_API_KEY_SECRET — ${keySecret.slice(0, 4)}...`);
  }

  if (!keyId || !keySecret) {
    console.log('\nSet credentials in your .env file or shell:\n');
    console.log('  HF_API_KEY_ID=<your-key-id>');
    console.log('  HF_API_KEY_SECRET=<your-key-secret>');
    console.log('\nGet keys at: https://cloud.higgsfield.ai\n');
    process.exit(1);
  }

  // Light connectivity check — fetch status of a known-bad ID, expect 404 not 401
  try {
    const client = new HiggsfieldClient();
    await client.getStatus('probe-00000000-0000-0000-0000-000000000000').catch((err: Error) => {
      if (err.message.includes('404')) {
        console.log('[PASS] API connectivity — reachable (404 on probe request, credentials valid)');
        return;
      }
      if (err.message.includes('401') || err.message.includes('403')) {
        throw new Error('Credentials rejected (401/403). Check HF_API_KEY_ID and HF_API_KEY_SECRET.');
      }
      // Network errors or other issues
      console.warn(`[WARN] API probe returned unexpected error: ${err.message}`);
    });
  } catch (err) {
    console.error(`[FAIL] API connectivity — ${err instanceof Error ? err.message : String(err)}`);
    process.exit(1);
  }

  console.log('\nRESULT: PASS\n');
}

async function runGenerateImage(flags: Flags): Promise<void> {
  const prompt = requireFlag(flags, 'prompt');
  const output = flags['output'] ? resolve(REPO_ROOT, flags['output']) : undefined;
  const wait = flags['no-wait'] !== 'true';

  const client = new HiggsfieldClient();

  console.log(`[higgsfield] Submitting image generation…`);
  console.log(`  Prompt: ${prompt}`);

  const response = await client.generateImage({
    prompt,
    negative_prompt: flags['negative-prompt'],
    aspect_ratio: flags['aspect-ratio'] ?? '16:9',
  });

  console.log(`[higgsfield] Request queued: ${response.request_id}`);
  console.log(`  Status URL: ${response.status_url}`);

  if (!wait) {
    console.log('[higgsfield] --no-wait set; exiting without polling.');
    console.log(JSON.stringify(response, null, 2));
    return;
  }

  console.log('[higgsfield] Waiting for completion…');
  const result = await client.waitForCompletion(response.request_id, {
    onPoll: (status: GenerationStatus) => {
      process.stdout.write(`\r  Status: ${status}     `);
    },
  });

  process.stdout.write('\n');
  console.log(`[higgsfield] Completed! Output URLs:`);
  for (const url of extractOutputUrls(result)) {
    console.log(`  ${url}`);
  }

  if (output) {
    console.log(`[higgsfield] Downloading to ${output}…`);
    await client.downloadOutput(result, output);
    console.log(`[higgsfield] Saved → ${output}`);
  }
}

async function runGenerateVideo(flags: Flags): Promise<void> {
  const prompt = requireFlag(flags, 'prompt');
  const output = flags['output'] ? resolve(REPO_ROOT, flags['output']) : undefined;
  const wait = flags['no-wait'] !== 'true';

  // Resolve local image file → absolute path to pass as reference
  let imageUrl = flags['image-url'];
  if (flags['image-file']) {
    const filePath = resolve(REPO_ROOT, flags['image-file']);
    // For local files we upload them as base64 data URIs
    const { readFileSync } = await import('node:fs');
    const { extname } = await import('node:path');
    const ext = extname(filePath).toLowerCase().slice(1);
    const mime = ext === 'jpg' || ext === 'jpeg' ? 'image/jpeg'
      : ext === 'png' ? 'image/png'
      : 'image/webp';
    const b64 = readFileSync(filePath).toString('base64');
    imageUrl = `data:${mime};base64,${b64}`;
    console.log(`[higgsfield] Using local image: ${filePath}`);
  }

  const client = new HiggsfieldClient();

  console.log(`[higgsfield] Submitting video generation…`);
  console.log(`  Mode: ${imageUrl ? 'image-to-video' : 'text-to-video'}`);
  console.log(`  Prompt: ${prompt}`);

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

  if (!wait) {
    console.log('[higgsfield] --no-wait set; exiting without polling.');
    console.log(JSON.stringify(response, null, 2));
    return;
  }

  console.log('[higgsfield] Waiting for completion (video generation takes 2–5 minutes)…');
  const result = await client.waitForCompletion(response.request_id, {
    timeoutMs: 15 * 60 * 1_000, // 15 min for video
    onPoll: (status: GenerationStatus) => {
      process.stdout.write(`\r  Status: ${status}     `);
    },
  });

  process.stdout.write('\n');
  console.log(`[higgsfield] Completed! Output URLs:`);
  for (const url of extractOutputUrls(result)) {
    console.log(`  ${url}`);
  }

  if (output) {
    console.log(`[higgsfield] Downloading to ${output}…`);
    await client.downloadOutput(result, output);
    console.log(`[higgsfield] Saved → ${output}`);
  }
}

async function runStatus(flags: Flags): Promise<void> {
  const requestId = requireFlag(flags, 'request-id');
  const client = new HiggsfieldClient();
  const result = await client.getStatus(requestId);
  console.log(JSON.stringify(result, null, 2));
}

async function runCancel(flags: Flags): Promise<void> {
  const requestId = requireFlag(flags, 'request-id');
  const client = new HiggsfieldClient();
  await client.cancel(requestId);
  console.log(`[higgsfield] Cancel request sent for ${requestId}`);
}

// ─── Entry point ──────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  const raw = process.argv.slice(2);
  if (raw.length === 0 || raw[0] !== '--') {
    usage();
    process.exit(1);
  }

  const args = raw.slice(1);
  const command = args[0];
  const flags = parseFlags(args.slice(1));

  try {
    switch (command) {
      case 'doctor':
        await runDoctor();
        break;
      case 'generate-image':
        await runGenerateImage(flags);
        break;
      case 'generate-video':
        await runGenerateVideo(flags);
        break;
      case 'status':
        await runStatus(flags);
        break;
      case 'cancel':
        await runCancel(flags);
        break;
      default:
        console.error(`Unknown subcommand: ${command}`);
        usage();
        process.exit(1);
    }
  } catch (err) {
    console.error(`\n[higgsfield] Error: ${err instanceof Error ? err.message : String(err)}`);
    process.exit(1);
  }
}

main();
