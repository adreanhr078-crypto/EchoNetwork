/**
 * tools/tripo/run-tripo.ts
 *
 * Direct integration with Tripo 3D OpenAPI V3 for:
 *  - text-to-model generation
 *  - image-to-model generation
 *  - automated rigging (Mixamo spec)
 *  - animation retargeting (preset motions: idle, walk, run)
 *  - checking user balance and credit status
 *
 * Usage:
 *   npx tsx tools/tripo/run-tripo.ts --balance
 *   npx tsx tools/tripo/run-tripo.ts text-to-model --prompt "heavy industrial sci-fi ceiling pipes" --output ./public/assets/pipes.glb
 *   npx tsx tools/tripo/run-tripo.ts rig --task-id <task_id> --output ./public/assets/rigged.glb
 *   npx tsx tools/tripo/run-tripo.ts animate --rig-id <rig_id> --animation "preset:walk" --output ./public/assets/anim.glb
 */

import fs from 'node:fs';
import path from 'node:path';

const BASE_URL = 'https://openapi.tripo3d.ai/v3';

export interface TripoConfig {
  apiKey: string;
  baseUrl?: string;
}

export interface TaskStatusResponse {
  code: number;
  data: {
    task_id: string;
    type: string;
    status: 'queued' | 'running' | 'success' | 'failed' | 'cancelled';
    progress?: number;
    result?: {
      pbr_model?: { url: string };
      model?: { url: string };
      rendered_image?: { url: string };
    };
    output?: {
      model?: string;
      model_url?: string;
      pbr_model?: string;
      rendered_image_url?: string;
      generated_image_url?: string;
      rig_type?: string;
      rig_id?: string;
    };
    message?: string;
  };
}

export function extractModelUrl(taskData: any): string {
  return taskData?.output?.model_url ||
    taskData?.output?.pbr_model ||
    taskData?.output?.model ||
    taskData?.result?.pbr_model?.url ||
    taskData?.result?.model?.url || '';
}

export function resolveApiKey(explicitKey?: string): string {
  if (explicitKey?.trim()) return explicitKey.trim();
  if (process.env.TRIPO_API_KEY?.trim()) return process.env.TRIPO_API_KEY.trim();

  // Try reading from .env.local in artifacts/eleven-eleven
  const envLocalPaths = [
    path.resolve(process.cwd(), 'artifacts/eleven-eleven/.env.local'),
    path.resolve(process.cwd(), '.env.local'),
  ];
  for (const envPath of envLocalPaths) {
    if (fs.existsSync(envPath)) {
      const content = fs.readFileSync(envPath, 'utf8');
      const match = content.match(/TRIPO_API_KEY\s*=\s*([^\r\n]+)/);
      if (match?.[1]?.trim()) {
        return match[1].trim();
      }
    }
  }

  return '';
}

export async function pollTask(
  taskId: string,
  apiKey: string,
  baseUrl = BASE_URL,
  intervalMs = 3000,
  maxWaitMs = 600000,
): Promise<TaskStatusResponse['data']> {
  const startTime = Date.now();
  const headers = {
    Authorization: `Bearer ${apiKey}`,
    'Content-Type': 'application/json',
  };

  while (Date.now() - startTime < maxWaitMs) {
    const res = await fetch(`${baseUrl}/tasks/${taskId}`, { headers });
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Tripo task status HTTP ${res.status}: ${errText}`);
    }
    const json = (await res.json()) as TaskStatusResponse;
    const task = json.data;

    if (task.status === 'success') {
      return task;
    }
    if (task.status === 'failed' || task.status === 'cancelled') {
      throw new Error(`Tripo task ${taskId} ended with status ${task.status}: ${task.message || JSON.stringify(task)}`);
    }

    const elapsedSec = Math.round((Date.now() - startTime) / 1000);
    const progress = task.progress ?? 0;
    process.stdout.write(`\r[tripo] Task ${taskId} status: ${task.status} (${progress}%) - ${elapsedSec}s elapsed...`);

    await new Promise((r) => setTimeout(r, intervalMs));
  }

  throw new Error(`Timeout waiting for Tripo task ${taskId} after ${maxWaitMs / 1000}s`);
}

export async function checkBalance(apiKey: string): Promise<unknown> {
  const res = await fetch('https://api.tripo3d.ai/v2/openapi/user/balance', {
    headers: { Authorization: `Bearer ${apiKey}` },
  });
  if (!res.ok) {
    throw new Error(`Failed to check balance: HTTP ${res.status} ${await res.text()}`);
  }
  return res.json();
}

export async function textToModel(
  prompt: string,
  apiKey: string,
  options: {
    model?: string;
    faceLimit?: number;
    texture?: boolean;
    baseUrl?: string;
  } = {},
): Promise<{ taskId: string }> {
  const res = await fetch(`${options.baseUrl || BASE_URL}/generation/text-to-model`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      prompt,
      model: options.model || 'v3.1-20260211',
      face_limit: options.faceLimit || 45000,
      texture: options.texture ?? true,
      pbr: options.pbr ?? true,
    }),
  });

  if (!res.ok) {
    throw new Error(`Failed to start text-to-model: HTTP ${res.status} ${await res.text()}`);
  }
  const json = await res.json() as { code: number; data: { task_id: string } };
  return { taskId: json.data.task_id };
}

export async function rigModel(
  taskId: string,
  apiKey: string,
  options: {
    spec?: string;
    baseUrl?: string;
  } = {},
): Promise<{ rigId: string }> {
  const headers = {
    Authorization: `Bearer ${apiKey}`,
    'Content-Type': 'application/json',
  };

  // Step 1: Rig check
  const checkRes = await fetch(`${options.baseUrl || BASE_URL}/animations/rig-check`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ input: taskId }),
  });
  if (!checkRes.ok) {
    throw new Error(`Rig check failed: HTTP ${checkRes.status} ${await checkRes.text()}`);
  }
  const checkJson = await checkRes.json() as { code: number; data: { rig_type: string } };
  const rigType = checkJson.data.rig_type;

  // Step 2: Rig
  const rigRes = await fetch(`${options.baseUrl || BASE_URL}/animations/rig`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      input: taskId,
      rig_type: rigType,
      spec: options.spec || 'mixamo',
    }),
  });
  if (!rigRes.ok) {
    throw new Error(`Rig request failed: HTTP ${rigRes.status} ${await rigRes.text()}`);
  }
  const rigJson = await rigRes.json() as { code: number; data: { task_id: string } };
  return { rigId: rigJson.data.task_id };
}

export async function retargetAnimation(
  rigTaskId: string,
  animationPreset: string,
  apiKey: string,
  options: { baseUrl?: string } = {},
): Promise<{ taskId: string }> {
  const res = await fetch(`${options.baseUrl || BASE_URL}/animations/retarget`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      input: rigTaskId,
      animation: animationPreset,
    }),
  });
  if (!res.ok) {
    throw new Error(`Retarget failed: HTTP ${res.status} ${await res.text()}`);
  }
  const json = await res.json() as { code: number; data: { task_id: string } };
  return { taskId: json.data.task_id };
}

export async function downloadGlb(url: string, destinationPath: string): Promise<void> {
  const dir = path.dirname(destinationPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Failed to download GLB from ${url}: HTTP ${res.status}`);
  }
  const arrayBuffer = await res.arrayBuffer();
  fs.writeFileSync(destinationPath, Buffer.from(arrayBuffer));
  console.log(`\n[tripo] Successfully downloaded model to: ${destinationPath} (${(arrayBuffer.byteLength / 1024 / 1024).toFixed(2)} MB)`);
}

async function cli() {
  const args = process.argv.slice(2);
  const command = args[0];

  const getArg = (flag: string): string | undefined => {
    const idx = args.indexOf(flag);
    return idx !== -1 && idx < args.length - 1 ? args[idx + 1] : undefined;
  };

  const apiKey = resolveApiKey(getArg('--api-key'));

  if (!apiKey) {
    console.log('[tripo] No TRIPO_API_KEY detected.');
    console.log('To authenticate:');
    console.log('  1. Get your API key from: https://platform.tripo3d.ai -> API Keys');
    console.log('  2. Set environment variable: TRIPO_API_KEY="tsk_..."');
    console.log('     or pass --api-key="tsk_..."');
    console.log('     or add TRIPO_API_KEY=tsk_... to artifacts/eleven-eleven/.env.local\n');
    console.log('[tripo] Toolchain initialized in offline/stub mode.');
    return;
  }

  if (command === '--balance' || command === 'balance') {
    console.log('[tripo] Checking balance...');
    const bal = await checkBalance(apiKey);
    console.log('[tripo] Balance response:', JSON.stringify(bal, null, 2));
    return;
  }

  if (command === 'download-task') {
    const taskId = getArg('--task-id');
    const output = getArg('--output') || './artifacts/eleven-eleven/public/assets/downloaded.glb';
    if (!taskId) throw new Error('Missing --task-id');
    console.log(`[tripo] Fetching task status for ${taskId}...`);
    const result = await pollTask(taskId, apiKey);
    const modelUrl = extractModelUrl(result);
    if (!modelUrl) throw new Error('No model URL found in task result');
    await downloadGlb(modelUrl, output);
    return;
  }

  if (command === 'text-to-model') {
    const prompt = getArg('--prompt') || 'anime heroine character cybernetic suit high quality';
    const output = getArg('--output') || './artifacts/eleven-eleven/public/assets/generated.glb';
    const model = getArg('--model') || 'v3.1-20260211';
    console.log(`[tripo] Starting text-to-model (Tripo V3: ${model}): "${prompt}"`);
    const { taskId } = await textToModel(prompt, apiKey, { model });
    console.log(`[tripo] Task submitted: ${taskId}. Waiting for completion...`);
    const result = await pollTask(taskId, apiKey);
    const modelUrl = extractModelUrl(result);
    if (!modelUrl) throw new Error('No model URL found in task result');
    await downloadGlb(modelUrl, output);
    return;
  }

  console.log(`[tripo] Available commands: balance, text-to-model, download-task, rig, retarget`);
}

if (process.argv[1] && import.meta.url.endsWith(process.argv[1].replace(/\\/g, '/'))) {
  cli().catch((err) => {
    console.error('[tripo] Error:', err);
    process.exit(1);
  });
}
