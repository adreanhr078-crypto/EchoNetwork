import { existsSync, createWriteStream } from "node:fs";
import { resolve, join } from "node:path";
import { pipeline } from "node:stream/promises";
import * as dotenv from "dotenv";
import axios from "axios";

// 1. Load credentials
const envLocalPath = resolve(process.cwd(), ".env.local");
if (existsSync(envLocalPath)) {
  dotenv.config({ path: envLocalPath });
}
dotenv.config();

import { config, higgsfield } from "@higgsfield/client/v2";

const credentials = process.env.HF_CREDENTIALS || process.env.HF_KEY;
if (!credentials) {
  console.error("Error: HF_CREDENTIALS or HF_KEY environment variable is not set.");
  process.exit(1);
}

config({
  credentials,
});

const MODEL = "bytedance/seedance-2.5/text-to-video";

const PROMPT = `High-end cinematic anime benchmark style, Genshin Impact and Solo Leveling anime aesthetic, 8k key visual quality. Inside Sector 11 underground Specimen Containment Wing. Massive dark obsidian industrial chamber with rows of towering vertical glass cylindrical stasis tanks filled with glowing murky cyan and amber bio-preservation fluid. Inside the tanks, silhouette outlines of previous failed human experiment subjects float motionless. Echo, a fragile shivering human young male in a plain dark containment suit, crouches stealthily behind thick damp metallic pipes on a grated catwalk. Zero supernatural powers, no shadow katana, human breathing in cold air. He looks up with wide shocked eyes as a cold cyan automated security sensor beam slowly sweeps across the foggy corridor above him. Obsidian void metallic palette (#0B0D12), bio-fluid amber glow (#FFB703), cold neon cyan accents (#00F0FF), subtle signal crimson warning light (#E63946) in distance. Wet reflective metallic floor, volumetric condensation fog, cinematic sweeping anime camera motion, zero readable text.`;

async function downloadFile(url: string, destPath: string): Promise<void> {
  console.log(`Downloading video from ${url} to ${destPath}...`);
  const response = await axios.get(url, { responseType: "stream" });
  await pipeline(response.data, createWriteStream(destPath));
  console.log(`Download completed successfully: ${destPath}`);
}

async function main() {
  console.log("=== 11.11 Higgsfield Cinematics Director — Room 5 Specimen Containment Wing ===");
  console.log(`Target Model: ${MODEL}`);
  console.log("Scene: Specimen Containment Wing — Stasis Tanks & Stealth Traversal");
  console.log(`Resolution: 1080p | Duration: 5s | Aspect Ratio: 16:9`);
  console.log(`Prompt: ${PROMPT}\n`);

  const startTime = Date.now();

  try {
    console.log("Submitting generation request to Higgsfield API...");
    const result = await higgsfield.subscribe(MODEL, {
      input: {
        prompt: PROMPT,
        duration: 5,
        resolution: "1080p",
        aspect_ratio: "16:9",
      },
      withPolling: true,
    });

    console.log("Generation response received:", JSON.stringify(result, null, 2));

    const status = (result as any).status;

    if (status === "completed") {
      const videoUrl =
        (result as any).video?.url ||
        (result as any).videos?.[0]?.url ||
        (result as any).output?.video?.url ||
        (result as any).url ||
        (result as any).output?.url;

      if (!videoUrl) {
        throw new Error("Job completed but video URL was not found in response.");
      }

      console.log(`\nSuccess! Video generated in ${(Date.now() - startTime) / 1000}s`);
      console.log(`Remote Video URL: ${videoUrl}`);

      const outputDir = resolve(process.cwd(), "artifacts/eleven-eleven/cinematics");
      const videoPath = join(outputDir, "room5-specimen-containment.mp4");
      const metadataPath = join(outputDir, "room5-specimen-containment.json");

      await downloadFile(videoUrl, videoPath);

      const metadata = {
        title: "Room 5 Cinematic — Specimen Containment Wing",
        character: "Echo (Fragile Human, Stealth Evasion, EX-011 Discovery)",
        model: MODEL,
        resolution: "1080p",
        duration: 5,
        aspect_ratio: "16:9",
        palette: ["#0B0D12 (Obsidian Void)", "#00F0FF (Cold Cyan Bio-Fluid)", "#FFB703 (Stasis Amber)", "#E63946 (Sensor Warning)"],
        prompt: PROMPT,
        remoteUrl: videoUrl,
        localFilePath: videoPath,
        higgsfieldResponse: result,
        generatedAt: new Date().toISOString(),
      };

      const { writeFileSync } = await import("node:fs");
      writeFileSync(metadataPath, JSON.stringify(metadata, null, 2), "utf8");
      console.log(`Metadata saved to: ${metadataPath}`);
      console.log("\nCinematic generation and delivery for Room 5 COMPLETE.");
    } else {
      console.error(`Generation ended with non-completed status: ${status}`, result);
      process.exit(1);
    }
  } catch (error: any) {
    console.error("Higgsfield generation failed:", error?.message || error);
    if (error?.response?.data) {
      console.error("Error response data:", JSON.stringify(error.response.data, null, 2));
    }
    process.exit(1);
  }
}

main();
