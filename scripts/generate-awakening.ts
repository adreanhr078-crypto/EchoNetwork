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

const PROMPT = `High-end cinematic anime benchmark style, Genshin Impact and Solo Leveling anime aesthetic, 8k key visual quality. Inside Sector 11 dark sci-fi containment chamber. A vertical cryogenic stasis capsule surrounded by billowing freezing white vapor and ice crystals. Echo, a fragile terrified young human male with disheveled black hair and pale shivering skin, wearing a plain dark containment suit. Completely human, zero supernatural powers, no shadow aura, vulnerable and trembling with shock. Close-up on his wide terrified dilated eyes suddenly snapping open in pure panic as cryo mist vents out. He weakly slams his trembling hands against the cracked frost glass front, shattering the glass panel. Echo collapses forward, tumbling out and falling hard onto his trembling hands and knees upon the wet damp obsidian metal grated floor, gasping for air. Obsidian dark metallic void palette (#0B0D12), cold laboratory cyan neon lighting (#00F0FF) catching the mist, faint warning signal crimson glow (#E63946) pulsing in the deep misty background. Volumetric fog, dynamic cinematic anime camera move, zero readable text.`;

async function downloadFile(url: string, destPath: string): Promise<void> {
  console.log(`Downloading video from ${url} to ${destPath}...`);
  const response = await axios.get(url, { responseType: "stream" });
  await pipeline(response.data, createWriteStream(destPath));
  console.log(`Download completed successfully: ${destPath}`);
}

async function main() {
  console.log("=== 11.11 Higgsfield Cinematics Director ===");
  console.log(`Target Model: ${MODEL}`);
  console.log("Scene: Opening Awakening Cinematic (Sector 11 Capsule)");
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
      const videoPath = join(outputDir, "opening-awakening-sector11.mp4");
      const metadataPath = join(outputDir, "opening-awakening-sector11.json");

      await downloadFile(videoUrl, videoPath);

      const metadata = {
        title: "Opening Awakening Cinematic — Sector 11 Capsule",
        character: "Echo (Fragile Human, Pre-Contract, No Zero powers)",
        model: MODEL,
        resolution: "1080p",
        duration: 5,
        aspect_ratio: "16:9",
        palette: ["#0B0D12 (Obsidian Void)", "#00F0FF (Cold Cyan Neon)", "#E63946 (Signal Crimson Accent)"],
        prompt: PROMPT,
        remoteUrl: videoUrl,
        localFilePath: videoPath,
        higgsfieldResponse: result,
        generatedAt: new Date().toISOString(),
      };

      const { writeFileSync } = await import("node:fs");
      writeFileSync(metadataPath, JSON.stringify(metadata, null, 2), "utf8");
      console.log(`Metadata saved to: ${metadataPath}`);
      console.log("\nCinematic generation and pipeline delivery COMPLETE.");
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
