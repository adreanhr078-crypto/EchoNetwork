/**
 * tools/higgsfield/higgsfield-client.ts
 *
 * Typed HTTP client for the Higgsfield AI API.
 *
 * Authentication uses a two-part key:
 *   Authorization: Key {HF_API_KEY_ID}:{HF_API_KEY_SECRET}
 *
 * The API is asynchronous — every generation returns a request_id that must
 * be polled (or awaited via webhook) until it reaches a terminal state.
 *
 * Terminal states: completed | failed | nsfw | canceled
 */

import { createWriteStream, mkdirSync } from 'node:fs';
import { basename, dirname } from 'node:path';
import { pipeline } from 'node:stream/promises';
import { Readable } from 'node:stream';

// ─── Types ────────────────────────────────────────────────────────────────────

export type GenerationStatus =
  | 'queued'
  | 'processing'
  | 'completed'
  | 'failed'
  | 'nsfw'
  | 'canceled';

export interface GenerationResponse {
  status: GenerationStatus;
  request_id: string;
  status_url: string;
  cancel_url: string;
  /** Present when status === 'completed' and request was image generation */
  images?: Array<{ url: string }>;
  /** Present when status === 'completed' and request was video generation */
  videos?: Array<{ url: string }>;
  /** Present when status === 'failed' */
  error?: string;
}

export interface GenerateImageOptions {
  prompt: string;
  /** Negative prompt (optional) */
  negative_prompt?: string;
  /** Aspect ratio e.g. "16:9", "1:1", "9:16" */
  aspect_ratio?: string;
  /** Seed for reproducibility */
  seed?: number;
  /** Additional model-specific parameters */
  [key: string]: unknown;
}

export interface GenerateVideoOptions {
  prompt: string;
  /** Reference image URL or base64 data URI for image-to-video */
  image_url?: string;
  /** Video duration in seconds */
  duration?: number;
  /** Frames per second */
  fps?: number;
  /** Resolution e.g. "1280x720" */
  resolution?: string;
  /** Motion strength 0–1 */
  motion_strength?: number;
  /** Camera motion hint e.g. "zoom_in", "pan_left", "orbit" */
  camera_motion?: string;
  negative_prompt?: string;
  seed?: number;
  [key: string]: unknown;
}

export interface PollingOptions {
  /** Initial delay in milliseconds before first poll (default: 3000) */
  initialDelayMs?: number;
  /** Delay between polls in milliseconds (default: 4000) */
  intervalMs?: number;
  /** Maximum total wait time in milliseconds (default: 10 minutes) */
  timeoutMs?: number;
  /** Called on each poll with current status */
  onPoll?: (status: GenerationStatus, requestId: string) => void;
}

// ─── Client ───────────────────────────────────────────────────────────────────

export class HiggsfieldClient {
  private readonly baseUrl: string;
  private readonly authHeader: string;

  constructor(options?: { keyId?: string; keySecret?: string; baseUrl?: string }) {
    const keyId = options?.keyId ?? process.env['HF_API_KEY_ID'] ?? '';
    const keySecret = options?.keySecret ?? process.env['HF_API_KEY_SECRET'] ?? '';

    if (!keyId || !keySecret) {
      throw new Error(
        'Higgsfield credentials missing. Set HF_API_KEY_ID and HF_API_KEY_SECRET environment variables.',
      );
    }

    this.baseUrl = options?.baseUrl ?? 'https://api.higgsfield.ai';
    this.authHeader = `Key ${keyId}:${keySecret}`;
  }

  // ── Core request helpers ───────────────────────────────────────────────────

  private async post<T>(path: string, body: unknown): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      method: 'POST',
      headers: {
        Authorization: this.authHeader,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const text = await response.text().catch(() => '(no body)');
      throw new Error(`Higgsfield POST ${path} → ${response.status}: ${text}`);
    }

    return response.json() as Promise<T>;
  }

  private async get<T>(urlOrPath: string): Promise<T> {
    const url = urlOrPath.startsWith('http')
      ? urlOrPath
      : `${this.baseUrl}${urlOrPath}`;

    const response = await fetch(url, {
      headers: { Authorization: this.authHeader },
    });

    if (!response.ok) {
      const text = await response.text().catch(() => '(no body)');
      throw new Error(`Higgsfield GET ${url} → ${response.status}: ${text}`);
    }

    return response.json() as Promise<T>;
  }

  // ── Generation endpoints ───────────────────────────────────────────────────

  /**
   * Submit an image generation request.
   * Uses the Soul v2 Standard model (general-purpose image model).
   * Returns immediately with status "queued".
   */
  async generateImage(options: GenerateImageOptions): Promise<GenerationResponse> {
    return this.post<GenerationResponse>('/higgsfield-ai/soul/v2/standard', options);
  }

  /**
   * Submit a video generation request.
   * If options.image_url is provided, performs image-to-video (animate).
   * Otherwise performs text-to-video (diffuse).
   */
  async generateVideo(options: GenerateVideoOptions): Promise<GenerationResponse> {
    if (options.image_url) {
      // Image-to-video: animate a reference frame
      return this.post<GenerationResponse>('/higgsfield-ai/animate/v1/standard', options);
    }
    // Text-to-video: diffuse from prompt
    return this.post<GenerationResponse>('/higgsfield-ai/diffuse/v1/standard', options);
  }

  // ── Status & lifecycle ─────────────────────────────────────────────────────

  /** Poll the status of an existing generation request. */
  async getStatus(requestId: string): Promise<GenerationResponse> {
    return this.get<GenerationResponse>(`/requests/${requestId}/status`);
  }

  /** Cancel a queued request (no-op if already processing). */
  async cancel(requestId: string): Promise<void> {
    const response = await fetch(`${this.baseUrl}/requests/${requestId}/cancel`, {
      method: 'DELETE',
      headers: { Authorization: this.authHeader },
    });
    if (!response.ok && response.status !== 404) {
      const text = await response.text().catch(() => '(no body)');
      throw new Error(`Cancel ${requestId} → ${response.status}: ${text}`);
    }
  }

  // ── Polling helper ─────────────────────────────────────────────────────────

  /**
   * Wait for a generation to reach a terminal state using exponential-capped polling.
   * Throws if the generation fails, is marked NSFW, is canceled, or times out.
   */
  async waitForCompletion(
    requestId: string,
    options: PollingOptions = {},
  ): Promise<GenerationResponse> {
    const {
      initialDelayMs = 3_000,
      intervalMs = 4_000,
      timeoutMs = 10 * 60 * 1_000,
      onPoll,
    } = options;

    const deadline = Date.now() + timeoutMs;

    // Initial delay — generation typically takes a few seconds to even start
    await sleep(initialDelayMs);

    let delay = intervalMs;

    while (Date.now() < deadline) {
      const result = await this.getStatus(requestId);
      onPoll?.(result.status, requestId);

      switch (result.status) {
        case 'completed':
          return result;
        case 'failed':
          throw new Error(`Generation ${requestId} failed: ${result.error ?? 'unknown error'}`);
        case 'nsfw':
          throw new Error(`Generation ${requestId} was blocked (NSFW).`);
        case 'canceled':
          throw new Error(`Generation ${requestId} was canceled.`);
        default:
          // queued or processing — keep waiting
          break;
      }

      await sleep(delay);
      // Exponential backoff capped at 15 seconds
      delay = Math.min(delay * 1.3, 15_000);
    }

    throw new Error(`Generation ${requestId} timed out after ${timeoutMs / 1000}s.`);
  }

  // ── Download helper ────────────────────────────────────────────────────────

  /**
   * Download the first output asset from a completed generation to a local path.
   * Supports both images[] and videos[] response shapes.
   */
  async downloadOutput(result: GenerationResponse, localPath: string): Promise<string> {
    if (result.status !== 'completed') {
      throw new Error(`Cannot download — generation ${result.request_id} is not completed.`);
    }

    const assetUrl =
      result.videos?.[0]?.url ??
      result.images?.[0]?.url;

    if (!assetUrl) {
      throw new Error(`No output URL found in completed generation ${result.request_id}.`);
    }

    mkdirSync(dirname(localPath), { recursive: true });

    const response = await fetch(assetUrl);
    if (!response.ok || !response.body) {
      throw new Error(`Failed to download asset: ${response.status}`);
    }

    const writer = createWriteStream(localPath);
    await pipeline(Readable.fromWeb(response.body as import('stream/web').ReadableStream), writer);

    return localPath;
  }
}

// ─── Utilities ────────────────────────────────────────────────────────────────

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Return a human-readable label for a request's output URLs. */
export function extractOutputUrls(result: GenerationResponse): string[] {
  return [
    ...(result.videos ?? []).map((v) => v.url),
    ...(result.images ?? []).map((i) => i.url),
  ];
}
